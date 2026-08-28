create or replace function private.is_valid_activity_grading_criteria(
  criteria jsonb
)
returns boolean
language plpgsql
immutable
strict
set search_path = ''
as $function$
declare
  criterion jsonb;
  criterion_ids text[] := '{}';
  percentage_value numeric;
  total_percentage numeric := 0;
begin
  if pg_catalog.jsonb_typeof(criteria) <> 'array'
    or pg_catalog.jsonb_array_length(criteria) = 0
    or pg_catalog.jsonb_array_length(criteria) > 50
  then
    return false;
  end if;

  for criterion in
    select value
    from pg_catalog.jsonb_array_elements(criteria)
  loop
    if pg_catalog.jsonb_typeof(criterion) <> 'object'
      or pg_catalog.jsonb_typeof(criterion -> 'id') <> 'string'
      or pg_catalog.length(pg_catalog.btrim(criterion ->> 'id')) = 0
      or pg_catalog.length(criterion ->> 'id') > 64
      or pg_catalog.jsonb_typeof(criterion -> 'name') <> 'string'
      or pg_catalog.length(pg_catalog.btrim(criterion ->> 'name')) = 0
      or pg_catalog.length(criterion ->> 'name') > 120
      or pg_catalog.jsonb_typeof(criterion -> 'percentage') <> 'number'
    then
      return false;
    end if;

    if (criterion ->> 'id') = any(criterion_ids) then
      return false;
    end if;
    criterion_ids := pg_catalog.array_append(
      criterion_ids,
      criterion ->> 'id'
    );

    percentage_value := (criterion ->> 'percentage')::numeric;
    if percentage_value <= 0
      or percentage_value > 100
      or pg_catalog.scale(percentage_value) > 2
    then
      return false;
    end if;

    total_percentage := total_percentage + percentage_value;
  end loop;

  return total_percentage = 100;
exception
  when others then
    return false;
end;
$function$;

revoke all on function private.is_valid_activity_grading_criteria(jsonb)
from public;
grant execute on function private.is_valid_activity_grading_criteria(jsonb)
to authenticated, service_role;

alter table public.assignments
add column if not exists grading_criteria jsonb not null default '[]'::jsonb;

do $migration$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.assignments'::regclass
      and conname = 'assignments_grading_criteria_valid'
  ) then
    alter table public.assignments
    add constraint assignments_grading_criteria_valid
    check (
      grading_criteria = '[]'::jsonb
      or private.is_valid_activity_grading_criteria(grading_criteria)
    );
  end if;
end;
$migration$;

comment on column public.assignments.grading_criteria is
  'Activity grading criteria stored as names and percentage weights. Equivalent points are derived from max_points.';
