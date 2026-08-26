drop policy if exists "support requests: users view own"
  on public.support_requests;
drop policy if exists "support requests: users view own or admins"
  on public.support_requests;
create policy "support requests: users view own or admins"
  on public.support_requests for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select private.is_admin())
  );

drop policy if exists "support requests: admins update status"
  on public.support_requests;
create policy "support requests: admins update status"
  on public.support_requests for update to authenticated
  using ((select private.is_admin()))
  with check ((select private.is_admin()));

revoke all on table public.support_requests from authenticated;
grant select, insert on table public.support_requests to authenticated;
grant update (status) on table public.support_requests to authenticated;
