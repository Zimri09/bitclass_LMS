-- BitClass LMS: keep courses.lesson_count synchronized with lessons.
-- Run this once in the Supabase SQL Editor. It backfills existing courses and
-- updates the count automatically for future lesson inserts and deletes.

create or replace function public.sync_course_lesson_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_course_id uuid;
begin
  if tg_op = 'DELETE' then
    affected_course_id := old.course_id;
  else
    affected_course_id := new.course_id;
  end if;

  update public.courses
  set lesson_count = (
        select count(*)
        from public.lessons
        where course_id = affected_course_id
      ),
      updated_at = timezone('utc', now())
  where id = affected_course_id;

  if tg_op = 'UPDATE' and old.course_id is distinct from new.course_id then
    update public.courses
    set lesson_count = (
          select count(*)
          from public.lessons
          where course_id = old.course_id
        ),
        updated_at = timezone('utc', now())
    where id = old.course_id;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists lessons_sync_course_lesson_count on public.lessons;
create trigger lessons_sync_course_lesson_count
after insert or delete or update of course_id on public.lessons
for each row execute function public.sync_course_lesson_count();

update public.courses
set lesson_count = (
      select count(*)
      from public.lessons
      where lessons.course_id = courses.id
    ),
    updated_at = timezone('utc', now());
