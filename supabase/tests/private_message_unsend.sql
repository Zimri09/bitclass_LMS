-- Run as postgres against a database with an instructor and enrolled student.
-- All fixtures roll back. Disable triggers only while inserting fixtures so no
-- test message or push notification is ever dispatched to a real user.
begin;
create temporary table unsend_test_context as
select c.id as course_id, c.instructor_id as sender_id, e.user_id as recipient_id,
       gen_random_uuid() as message_id, gen_random_uuid() as notification_id
from public.courses c join public.enrollments e on e.course_id = c.id
where c.instructor_id <> e.user_id limit 1;
do $$ begin
  if not exists (select 1 from unsend_test_context) then
    raise exception 'Test requires a course with an enrolled student';
  end if;
end $$;
grant select on unsend_test_context to authenticated;
set local session_replication_role = replica;
insert into public.private_messages(id, course_id, sender_id, recipient_id, body, created_at)
select message_id, course_id, sender_id, recipient_id, 'Unsend regression fixture',
       now() - interval '1 day' from unsend_test_context;
insert into public.notifications(id, user_id, type, title, body, data, course_id)
select notification_id, recipient_id, 'privateMessage', 'Test', 'Unsend regression fixture',
       jsonb_build_object('message_id', message_id), course_id from unsend_test_context;
set local session_replication_role = origin;

select set_config('request.jwt.claim.sub', sender_id::text, true) from unsend_test_context;
set local role authenticated;
do $$
declare ctx record;
begin
  select * into ctx from unsend_test_context;
  if public.can_modify_private_message(ctx.message_id) then
    raise exception 'Expired message unexpectedly editable';
  end if;
  perform public.hide_private_message(ctx.message_id);
  if not exists (select 1 from public.private_messages where id = ctx.message_id
                 and hidden_for_sender and not is_unsent and read_at is null) then
    raise exception 'Hide for sender changed shared state';
  end if;
  begin
    update public.private_messages set is_unsent = true where id = ctx.message_id;
    raise exception 'Direct mutation unexpectedly allowed';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

select set_config('request.jwt.claim.sub', recipient_id::text, true) from unsend_test_context;
set local role authenticated;
do $$
declare ctx record;
begin
  select * into ctx from unsend_test_context;
  if not exists (select 1 from public.private_messages where id = ctx.message_id
                 and body = 'Unsend regression fixture' and not is_unsent
                 and not (sender_id = auth.uid() and hidden_for_sender)) then
    raise exception 'Recipient lost sender-hidden message';
  end if;
  if not exists (select 1 from public.notifications where id = ctx.notification_id
                 and not is_read and body = 'Unsend regression fixture') then
    raise exception 'Hide for sender changed recipient notification';
  end if;
  begin
    perform public.hide_private_message(ctx.message_id);
    raise exception 'Recipient could hide another sender message';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.unsend_private_message(ctx.message_id);
    raise exception 'Recipient could unsend another sender message';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

select set_config('request.jwt.claim.sub', sender_id::text, true) from unsend_test_context;
set local role authenticated;
select count(*) as unsent_rows from public.unsend_private_message(
  (select message_id from unsend_test_context));
-- Idempotent retry, even after a previous hide-for-you.
select count(*) as retried_rows from public.unsend_private_message(
  (select message_id from unsend_test_context));
reset role;

select set_config('request.jwt.claim.sub', recipient_id::text, true) from unsend_test_context;
set local role authenticated;
do $$
declare ctx record;
begin
  select * into ctx from unsend_test_context;
  if exists (select 1 from public.private_messages where id = ctx.message_id
             and (not is_unsent or body <> 'Message unsent' or read_at is null)) then
    raise exception 'Everyone unsend did not redact content and clear unread';
  end if;
  -- Tombstones remain readable so RLS permits realtime UPDATE delivery.
  if not exists (select 1 from public.private_messages where id = ctx.message_id) then
    raise exception 'Realtime tombstone is not readable';
  end if;
  if not exists (select 1 from public.notifications where id = ctx.notification_id
                 and is_read and body = 'Message unsent') then
    raise exception 'Notification was not redacted';
  end if;
end $$;
reset role;

select set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
set local role authenticated;
do $$ begin
  if exists (select 1 from public.private_messages where id =
             (select message_id from unsend_test_context)) then
    raise exception 'Outsider can read message';
  end if;
  begin
    perform public.unsend_private_message((select message_id from unsend_test_context));
    raise exception 'Outsider can unsend message';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
do $$ begin
  if has_function_privilege('anon', 'public.unsend_private_message(uuid)', 'execute')
     or has_function_privilege('anon', 'public.hide_private_message(uuid)', 'execute') then
    raise exception 'Anonymous users can mutate messages';
  end if;
end $$;
rollback;
select 'All unsend database assertions passed; fixtures rolled back' as result;
