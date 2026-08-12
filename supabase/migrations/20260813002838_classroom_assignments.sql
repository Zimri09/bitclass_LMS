-- Google Classroom-style assignment materials and student work.

alter type public.submission_status add value if not exists 'done';

alter table public.assignments
  add column if not exists attachments jsonb not null default '[]'::jsonb,
  add column if not exists requires_attachment boolean not null default false;

alter table public.submissions
  add column if not exists attachments jsonb not null default '[]'::jsonb;

create index if not exists assignments_course_published_due_idx
  on public.assignments (course_id, is_published, due_date);
create index if not exists assignments_lesson_idx
  on public.assignments (lesson_id)
  where lesson_id is not null;
create index if not exists submissions_course_user_idx
  on public.submissions (course_id, user_id);
create index if not exists submissions_user_idx
  on public.submissions (user_id);
create index if not exists submissions_graded_by_idx
  on public.submissions (graded_by)
  where graded_by is not null;

alter table public.assignments
  drop constraint if exists assignments_attachments_are_array,
  add constraint assignments_attachments_are_array
    check (jsonb_typeof(attachments) = 'array');

alter table public.submissions
  drop constraint if exists submissions_attachments_are_array,
  add constraint submissions_attachments_are_array
    check (jsonb_typeof(attachments) = 'array');

comment on column public.assignments.attachments is
  'Instructor materials represented as file/link metadata objects.';
comment on column public.assignments.requires_attachment is
  'When true, students must attach at least one item before submitting.';
comment on column public.submissions.attachments is
  'Student work represented as private file/link metadata objects.';

create or replace function public.set_submission_completion_metadata()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  assignment_due_date timestamptz;
  should_stamp boolean := false;
begin
  if new.status::text in ('submitted', 'done') then
    if tg_op = 'INSERT' then
      should_stamp := true;
    elsif old.status::text not in ('submitted', 'done') then
      should_stamp := true;
    end if;
  end if;

  if should_stamp then
    select a.due_date
      into assignment_due_date
      from public.assignments a
      where a.id = new.assignment_id
        and a.course_id = new.course_id;

    new.submitted_at = now();
    new.is_late = assignment_due_date is not null and now() > assignment_due_date;
  elsif new.status::text = 'draft' then
    new.submitted_at = null;
    new.is_late = false;
  end if;

  return new;
end;
$$;

drop trigger if exists submissions_completion_metadata
  on public.submissions;
create trigger submissions_completion_metadata
  before insert or update on public.submissions
  for each row execute function public.set_submission_completion_metadata();

revoke all on function public.set_submission_completion_metadata()
  from public, anon, authenticated;

-- Students can only modify draft rows. Completing an assignment changes the
-- row to submitted/done, and the unsubmit RPC is the only path back to draft.
drop policy if exists "submissions: students create valid work"
  on public.submissions;
drop policy if exists "submissions: students update valid work"
  on public.submissions;

create policy "submissions: students create valid work"
  on public.submissions for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and status::text in ('draft', 'submitted', 'done')
    and score is null
    and feedback is null
    and graded_by is null
    and graded_at is null
    and exists (
      select 1
      from public.assignments a
      where a.id = submissions.assignment_id
        and a.course_id = submissions.course_id
        and a.is_published
        and (select private.is_course_member(a.course_id))
        and (
          (submissions.status::text = 'draft'
            and submissions.submitted_at is null
            and not submissions.is_late)
          or (
            submissions.status::text in ('submitted', 'done')
            and submissions.submitted_at is not null
            and (a.allow_late_submission or a.due_date is null or now() <= a.due_date)
            and submissions.is_late = (a.due_date is not null and now() > a.due_date)
            and (
              submissions.status::text <> 'done'
              or (
                not a.requires_attachment
                and a.language::text = 'plaintext'
                and coalesce(trim(a.starter_code), '') = ''
                and coalesce(trim(a.solution_code), '') = ''
              )
            )
            and (
              not a.requires_attachment
              or jsonb_array_length(submissions.attachments) > 0
            )
          )
        )
    )
  );

create policy "submissions: students update valid work"
  on public.submissions for update to authenticated
  using (
    user_id = (select auth.uid())
    and status::text = 'draft'
  )
  with check (
    user_id = (select auth.uid())
    and status::text in ('draft', 'submitted', 'done')
    and score is null
    and feedback is null
    and graded_by is null
    and graded_at is null
    and exists (
      select 1
      from public.assignments a
      where a.id = submissions.assignment_id
        and a.course_id = submissions.course_id
        and a.is_published
        and (select private.is_course_member(a.course_id))
        and (
          (submissions.status::text = 'draft'
            and submissions.submitted_at is null
            and not submissions.is_late)
          or (
            submissions.status::text in ('submitted', 'done')
            and submissions.submitted_at is not null
            and (a.allow_late_submission or a.due_date is null or now() <= a.due_date)
            and submissions.is_late = (a.due_date is not null and now() > a.due_date)
            and (
              submissions.status::text <> 'done'
              or (
                not a.requires_attachment
                and a.language::text = 'plaintext'
                and coalesce(trim(a.starter_code), '') = ''
                and coalesce(trim(a.solution_code), '') = ''
              )
            )
            and (
              not a.requires_attachment
              or jsonb_array_length(submissions.attachments) > 0
            )
          )
        )
    )
  );

create or replace function public.unsubmit_assignment(p_assignment_id uuid)
returns public.submissions
language plpgsql
security definer
set search_path = ''
as $$
declare
  result public.submissions;
begin
  update public.submissions s
  set status = 'draft'::public.submission_status,
      submitted_at = null,
      is_late = false,
      updated_at = timezone('utc'::text, now())
  from public.assignments a
  where s.assignment_id = p_assignment_id
    and s.assignment_id = a.id
    and s.course_id = a.course_id
    and s.user_id = auth.uid()
    and s.status::text in ('submitted', 'done')
    and (a.due_date is null or now() <= a.due_date)
  returning s.* into result;

  if result.id is null then
    raise exception 'This work cannot be unsubmitted after the deadline or grading.';
  end if;

  return result;
end;
$$;

revoke all on function public.unsubmit_assignment(uuid) from public, anon;
grant execute on function public.unsubmit_assignment(uuid) to authenticated;

-- Keep assignment materials and student work in a private bucket. Access is
-- decided from the path: <scope>/<course>/<assignment>/<user>/<file>.
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'assignment_attachments',
  'assignment_attachments',
  false,
  26214400,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/plain', 'text/markdown', 'text/csv', 'text/html', 'text/css',
    'text/x-dart', 'text/x-python', 'text/typescript',
    'application/javascript', 'application/json', 'application/xml',
    'application/yaml',
    'image/png', 'image/jpeg', 'image/gif', 'image/webp', 'image/svg+xml',
    'application/zip', 'application/gzip', 'application/x-tar',
    'application/x-rar-compressed', 'application/x-7z-compressed',
    'application/octet-stream'
  ]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "assignment attachments: authorized read"
  on storage.objects;
drop policy if exists "assignment attachments: material upload"
  on storage.objects;
drop policy if exists "assignment attachments: student upload"
  on storage.objects;
drop policy if exists "assignment attachments: authorized delete"
  on storage.objects;

create policy "assignment attachments: authorized read"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'assignment_attachments'
    and exists (
      select 1
      from public.assignments a
      where a.course_id::text = (storage.foldername(name))[2]
        and a.id::text = (storage.foldername(name))[3]
        and (
          (
            (storage.foldername(name))[1] = 'materials'
            and (
              (select private.can_manage_course(a.course_id))
              or (
                a.is_published
                and (select private.is_course_member(a.course_id))
              )
            )
          )
          or (
            (storage.foldername(name))[1] = 'submissions'
            and (
              (storage.foldername(name))[4] = (select auth.uid()::text)
              or (select private.can_manage_course(a.course_id))
            )
          )
        )
    )
  );

create policy "assignment attachments: material upload"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'assignment_attachments'
    and (storage.foldername(name))[1] = 'materials'
    and (storage.foldername(name))[4] = (select auth.uid()::text)
    and exists (
      select 1
      from public.assignments a
      where a.course_id::text = (storage.foldername(name))[2]
        and a.id::text = (storage.foldername(name))[3]
        and (select private.can_manage_course(a.course_id))
    )
  );

create policy "assignment attachments: student upload"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'assignment_attachments'
    and (storage.foldername(name))[1] = 'submissions'
    and (storage.foldername(name))[4] = (select auth.uid()::text)
    and exists (
      select 1
      from public.assignments a
      where a.course_id::text = (storage.foldername(name))[2]
        and a.id::text = (storage.foldername(name))[3]
        and a.is_published
        and (select private.is_course_member(a.course_id))
        and (a.allow_late_submission or a.due_date is null or now() <= a.due_date)
        and not exists (
          select 1
          from public.submissions s
          where s.assignment_id = a.id
            and s.user_id = auth.uid()
            and s.status::text <> 'draft'
        )
    )
  );

create policy "assignment attachments: authorized delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'assignment_attachments'
    and exists (
      select 1
      from public.assignments a
      where a.course_id::text = (storage.foldername(name))[2]
        and a.id::text = (storage.foldername(name))[3]
        and (
          (
            (storage.foldername(name))[1] = 'materials'
            and (select private.can_manage_course(a.course_id))
          )
          or (
            (storage.foldername(name))[1] = 'submissions'
            and (
              (select private.can_manage_course(a.course_id))
              or (
                (storage.foldername(name))[4] = (select auth.uid()::text)
                and not exists (
                  select 1 from public.submissions s
                  where s.assignment_id = a.id
                    and s.user_id = auth.uid()
                    and s.status::text <> 'draft'
                )
              )
            )
          )
        )
    )
  );
