-- Run as postgres after the reaction migration. All fixtures roll back.
begin;
create temporary table reaction_test_context as
select c.id as course_id, c.instructor_id as sender_id, e.user_id as recipient_id,
       gen_random_uuid() as message_id
from public.courses c join public.enrollments e on e.course_id = c.id
where c.instructor_id <> e.user_id limit 1;
do $$ begin
  if not exists (select 1 from reaction_test_context) then
    raise exception 'Test requires a course with an enrolled student';
  end if;
end $$;
grant select on reaction_test_context to authenticated;
set local session_replication_role = replica;
insert into public.private_messages(id, course_id, sender_id, recipient_id, body)
select message_id, course_id, sender_id, recipient_id, 'Reaction fixture'
from reaction_test_context;
set local session_replication_role = origin;

select set_config('request.jwt.claim.sub', sender_id::text, true) from reaction_test_context;
set local role authenticated;
select public.set_private_message_reaction(message_id, 'haha') from reaction_test_context;
reset role;
select set_config('request.jwt.claim.sub', recipient_id::text, true) from reaction_test_context;
set local role authenticated;
select public.set_private_message_reaction(message_id, 'heart') from reaction_test_context;
do $$ begin
  if not exists (select 1 from public.private_messages m join reaction_test_context t on m.id = t.message_id
                 where sender_reaction = 'haha' and recipient_reaction = 'heart' and body = 'Reaction fixture') then
    raise exception 'Both participants must retain independent reactions';
  end if;
end $$;
select public.set_private_message_reaction(message_id, 'sad') from reaction_test_context;
select public.set_private_message_reaction(message_id, null) from reaction_test_context;
do $$ declare target uuid; begin
  select message_id into target from reaction_test_context;
  if not exists (select 1 from public.private_messages where id = target
                 and sender_reaction = 'haha' and recipient_reaction is null) then
    raise exception 'Removing a reaction changed the other participant reaction';
  end if;
  begin
    perform public.set_private_message_reaction(target, 'invalid');
    raise exception 'Invalid reaction accepted';
  exception when invalid_parameter_value then null; end;
  begin
    update public.private_messages set sender_reaction = 'angry' where id = target;
    raise exception 'Direct reaction mutation allowed';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);
set local role authenticated;
do $$ begin
  begin
    perform public.set_private_message_reaction(message_id, 'heart') from reaction_test_context;
    raise exception 'Outsider reaction accepted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
update public.private_messages set is_unsent = true where id in (select message_id from reaction_test_context);
select set_config('request.jwt.claim.sub', sender_id::text, true) from reaction_test_context;
set local role authenticated;
do $$ begin
  begin
    perform public.set_private_message_reaction(message_id, 'heart') from reaction_test_context;
    raise exception 'Reaction on unsent message accepted';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
