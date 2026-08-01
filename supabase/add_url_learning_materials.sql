begin;

alter table public.files
  add column if not exists resource_kind text not null default 'file';

alter table public.files
  alter column bucket drop not null,
  alter column storage_path drop not null;

alter table public.files
  drop constraint if exists files_resource_kind_check;

alter table public.files
  add constraint files_resource_kind_check
  check (resource_kind in ('file', 'url'));

create unique index if not exists files_unique_url_resource_idx
on public.files (
  course_id,
  coalesce(lesson_id, '00000000-0000-0000-0000-000000000000'::uuid),
  public_url
)
where resource_kind = 'url';

commit;
