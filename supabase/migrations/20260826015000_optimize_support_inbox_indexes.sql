create index if not exists support_requests_created_at_idx
  on public.support_requests (created_at desc);

create index if not exists support_requests_status_created_idx
  on public.support_requests (status, created_at desc);
