-- Run as postgres after the recipient-hiding migration. Fixtures roll back.
begin;
create temporary table hide_test_context as
select c.id as course_id, c.instructor_id as sender_id, e.user_id as recipient_id,
       gen_random_uuid() as message_id
from public.courses c join public.enrollments e on e.course_id = c.id
where c.instructor_id <> e.user_id limit 1;
do $$ begin
  if not exists (select 1 from hide_test_context) then
    raise exception 'Test requires a course with an enrolled student';
  end if;
end $$;
grant select on hide_test_context to authenticated;
set local session_replication_role = replica;
insert into public.private_messages(id, course_id, sender_id, recipient_id, body, sender_reaction)
select message_id, course_id, sender_id, recipient_id, 'Hide fixture', 'heart' from hide_test_context;
set local session_replication_role = origin;

select set_config('request.jwt.claim.sub', sender_id::text, true) from hide_test_context;
set local role authenticated;
do $$ begin
  begin
    perform public.hide_received_private_message(message_id) from hide_test_context;
    raise exception 'Sender hid a message for its recipient';
  exception when insufficient_privilege then null; end;
  begin
    update public.private_messages set hidden_for_recipient = true
    where id = (select message_id from hide_test_context);
    raise exception 'Direct recipient visibility update allowed';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

select set_config('request.jwt.claim.sub', recipient_id::text, true) from hide_test_context;
set local role authenticated;
select public.hide_received_private_message(message_id) from hide_test_context;
select public.hide_received_private_message(message_id) from hide_test_context;
do $$ begin
  if not exists (select 1 from public.private_messages m join hide_test_context t on m.id = t.message_id
                 where hidden_for_recipient and not hidden_for_sender and not is_unsent
                 and body = 'Hide fixture' and sender_reaction = 'heart' and read_at is null) then
    raise exception 'Hiding modified shared content or failed to persist';
  end if;
end $$;
reset role;

select set_config('request.jwt.claim.sub', sender_id::text, true) from hide_test_context;
set local role authenticated;
do $$ begin
  if not exists (select 1 from public.private_messages m join hide_test_context t on m.id = t.message_id
                 where not hidden_for_sender and not is_unsent and body = 'Hide fixture') then
    raise exception 'Sender lost message visibility';
  end if;
end $$;
select public.unsend_private_message(message_id) from hide_test_context;
reset role;

select set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
set local role authenticated;
do $$ begin
  begin
    perform public.hide_received_private_message(message_id) from hide_test_context;
    raise exception 'Outsider hid a message';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
  if has_function_privilege('anon', 'public.hide_received_private_message(uuid)', 'execute') then
    raise exception 'Anonymous users can hide messages';
  end if;
end $$;
rollback;
