-- Advisory client observations, never automatic cheating verdicts.
create table public.quiz_security_events (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.quiz_attempts(id) on delete cascade,
  event_type text not null check (event_type in (
    'content_copy_attempt', 'print_attempt', 'tab_hidden', 'window_blur',
    'leave_attempt', 'quiz_left', 'app_inactive', 'app_background',
    'capture_active', 'screenshot_taken', 'protection_unavailable',
    'protection_android_secure_window', 'protection_ios_capture_detection',
    'protection_browser_deterrents'
  )),
  platform text not null check (platform in ('web','android','iOS','macOS','windows','linux','fuchsia')),
  created_at timestamptz not null default now()
);
create index quiz_security_events_attempt_time on public.quiz_security_events(attempt_id, created_at);
alter table public.quiz_security_events enable row level security;
revoke all on public.quiz_security_events from anon, authenticated;
grant insert (attempt_id, event_type, platform) on public.quiz_security_events to authenticated;
grant select on public.quiz_security_events to authenticated;
create policy "students append own quiz observations"
  on public.quiz_security_events for insert to authenticated
  with check (exists (
    select 1 from public.quiz_attempts a
    where a.id = attempt_id and a.user_id = (select auth.uid())
      and a.status = 'inProgress'
  ));
create policy "course managers review quiz observations"
  on public.quiz_security_events for select to authenticated
  using (exists (
    select 1 from public.quiz_attempts a join public.quizzes q on q.id = a.quiz_id
    where a.id = attempt_id and (select private.can_manage_course(q.course_id))
  ));
