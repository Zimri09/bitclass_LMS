-- Private course materials are addressed by bucket + storage_path and receive
-- short-lived signed URLs only when an authorized user opens them.

alter table public.files
  alter column public_url drop not null;

comment on column public.files.public_url is
  'Required for web-link resources and legacy public files; null for private Storage objects.';

alter table public.files
  drop constraint if exists files_resource_location_check;

alter table public.files
  add constraint files_resource_location_check
  check (
    (
      resource_kind = 'url'
      and nullif(btrim(public_url), '') is not null
    )
    or
    (
      resource_kind = 'file'
      and (
        nullif(btrim(storage_path), '') is not null
        or nullif(btrim(public_url), '') is not null
      )
    )
  );
