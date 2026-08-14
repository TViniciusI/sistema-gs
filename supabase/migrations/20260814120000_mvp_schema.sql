-- MVP GS Soluções Técnicas
-- Tenant-ready (organization_id), RLS em todas as tabelas públicas.

create extension if not exists "pgcrypto";

create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to postgres, service_role, authenticated;

-- ---------------------------------------------------------------------------
-- Enumerations via check constraints (easier to evolve than PG enums)
-- ---------------------------------------------------------------------------

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  legal_name text,
  trade_name text,
  address text,
  phone text,
  website text,
  timezone text not null default 'America/Belem',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  organization_id uuid not null references public.organizations (id),
  email text not null,
  full_name text not null,
  role text not null default 'technician'
    check (role in ('admin', 'office', 'lead_tech', 'technician', 'viewer')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index profiles_org_idx on public.profiles (organization_id);
create unique index profiles_org_email_idx on public.profiles (organization_id, email);

create table public.employees (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  user_id uuid unique references public.profiles (id) on delete set null,
  full_name text not null,
  job_title text,
  phone text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index employees_org_idx on public.employees (organization_id);

create table public.technicians (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  employee_id uuid not null unique references public.employees (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index technicians_org_idx on public.technicians (organization_id);

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  code integer not null,
  alias text,
  legal_name text not null,
  cnpj text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, code)
);

create index clients_org_idx on public.clients (organization_id);
create index clients_org_name_idx on public.clients (organization_id, legal_name);

create table public.client_contacts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  client_id uuid not null references public.clients (id) on delete cascade,
  kind text not null default 'requester'
    check (kind in ('requester', 'site_manager', 'other')),
  full_name text not null,
  job_title text,
  phone text,
  email text,
  created_at timestamptz not null default now()
);

create index client_contacts_client_idx on public.client_contacts (client_id);
create index client_contacts_org_idx on public.client_contacts (organization_id);

create table public.locations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  client_id uuid not null references public.clients (id) on delete restrict,
  alias text not null,
  address text,
  city text,
  state text,
  latitude double precision,
  longitude double precision,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index locations_org_idx on public.locations (organization_id);
create index locations_client_idx on public.locations (client_id);

create table public.work_order_sequences (
  organization_id uuid not null references public.organizations (id),
  year integer not null,
  last_number integer not null default 0,
  primary key (organization_id, year)
);

create table public.work_orders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  year integer not null,
  number integer not null,
  purchase_order text,
  client_id uuid not null references public.clients (id),
  location_id uuid references public.locations (id),
  service_type text not null default 'calibracao'
    check (service_type in ('calibracao', 'manutencao', 'comissionamento', 'startup', 'outro')),
  system_type text
    check (system_type is null or system_type in ('carregamento', 'descarregamento', 'telemetria', 'aditivacao', 'outro')),
  status text not null default 'draft'
    check (status in (
      'draft', 'scheduled', 'assigned', 'accepted', 'traveling', 'on_site',
      'in_progress', 'awaiting_signature', 'completed', 'reviewed', 'billed', 'cancelled'
    )),
  scheduled_date date,
  notes text,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, year, number)
);

create index work_orders_org_date_idx on public.work_orders (organization_id, scheduled_date desc);
create index work_orders_org_status_idx on public.work_orders (organization_id, status);
create index work_orders_client_idx on public.work_orders (client_id);
create index work_orders_location_idx on public.work_orders (location_id);

create table public.work_order_technicians (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  work_order_id uuid not null references public.work_orders (id) on delete cascade,
  technician_id uuid not null references public.technicians (id),
  function text not null default 'suporte_tecnico'
    check (function in ('responsavel_tecnico', 'suporte_tecnico')),
  is_owner boolean not null default false,
  created_at timestamptz not null default now(),
  unique (work_order_id, technician_id)
);

create index wot_org_idx on public.work_order_technicians (organization_id);
create index wot_wo_idx on public.work_order_technicians (work_order_id);
create index wot_tech_idx on public.work_order_technicians (technician_id);

create table public.work_order_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  work_order_id uuid not null references public.work_orders (id) on delete cascade,
  actor_id uuid references public.profiles (id),
  event_type text not null,
  payload jsonb not null default '{}'::jsonb,
  latitude double precision,
  longitude double precision,
  occurred_at timestamptz not null default now()
);

create index woe_wo_idx on public.work_order_events (work_order_id, occurred_at);
create index woe_org_idx on public.work_order_events (organization_id);

create table public.time_entries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  work_order_id uuid not null references public.work_orders (id) on delete cascade,
  technician_id uuid not null references public.technicians (id),
  service_date date not null,
  clock_in timestamptz,
  lunch_start timestamptz,
  lunch_end timestamptz,
  clock_out timestamptz,
  status text not null default 'em_andamento',
  description text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (work_order_id, technician_id, service_date)
);

create index time_entries_wo_idx on public.time_entries (work_order_id);
create index time_entries_org_idx on public.time_entries (organization_id);

create table public.service_reports (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  work_order_id uuid not null references public.work_orders (id) on delete cascade,
  service_date date not null,
  description text,
  extra_info text,
  pdf_path text,
  signed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (work_order_id, service_date)
);

create index service_reports_org_idx on public.service_reports (organization_id);

create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  owner_type text not null,
  owner_id uuid not null,
  kind text not null default 'photo'
    check (kind in ('photo', 'pdf', 'document', 'signature', 'other')),
  storage_path text not null,
  mime_type text,
  sha256 text,
  taken_at timestamptz,
  latitude double precision,
  longitude double precision,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

create index attachments_owner_idx on public.attachments (owner_type, owner_id);
create index attachments_org_idx on public.attachments (organization_id);

create table public.signatures (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  work_order_id uuid not null references public.work_orders (id) on delete cascade,
  signer_name text not null,
  signer_role text,
  attachment_id uuid references public.attachments (id),
  captured_at timestamptz not null default now(),
  latitude double precision,
  longitude double precision
);

create index signatures_wo_idx on public.signatures (work_order_id);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  actor_id uuid references public.profiles (id),
  entity text not null,
  entity_id uuid,
  action text not null,
  before jsonb,
  after jsonb,
  created_at timestamptz not null default now()
);

create index audit_logs_org_idx on public.audit_logs (organization_id, created_at desc);
create index audit_logs_entity_idx on public.audit_logs (entity, entity_id);

create table public.sync_mutations (
  client_mutation_id uuid primary key,
  organization_id uuid not null references public.organizations (id),
  user_id uuid not null references public.profiles (id),
  result jsonb,
  applied_at timestamptz not null default now()
);

create index sync_mutations_org_idx on public.sync_mutations (organization_id);

create table public.holidays (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id),
  holiday_date date not null,
  name text not null,
  unique (organization_id, holiday_date)
);

-- ---------------------------------------------------------------------------
-- Helpers (private schema — security definer stays off public)
-- ---------------------------------------------------------------------------

create or replace function private.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function private.current_org_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select organization_id
  from public.profiles
  where id = auth.uid()
$$;

create or replace function private.current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.profiles
  where id = auth.uid() and is_active
$$;

revoke all on function private.current_org_id() from public, anon;
revoke all on function private.current_role() from public, anon;
grant execute on function private.current_org_id() to authenticated, service_role;
grant execute on function private.current_role() to authenticated, service_role;

create or replace function private.enforce_org_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  org uuid;
begin
  org := private.current_org_id();
  if tg_op = 'INSERT' then
    if org is not null then
      new.organization_id := org;
    end if;
  elsif tg_op = 'UPDATE' then
    new.organization_id := old.organization_id;
  end if;
  return new;
end;
$$;

create or replace function private.next_work_order_number(p_org uuid, p_year integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  insert into public.work_order_sequences (organization_id, year, last_number)
  values (p_org, p_year, 1)
  on conflict (organization_id, year)
  do update set last_number = public.work_order_sequences.last_number + 1
  returning last_number into n;
  return n;
end;
$$;

create or replace function private.allocate_work_order_number(p_year integer)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  org uuid;
begin
  org := private.current_org_id();
  if org is null then
    raise exception 'not authenticated';
  end if;
  return private.next_work_order_number(org, p_year);
end;
$$;

create or replace function public.allocate_work_order_number(p_year integer)
returns integer
language sql
security invoker
set search_path = public
as $$
  select private.allocate_work_order_number(p_year);
$$;

revoke all on function private.next_work_order_number(uuid, integer) from public, anon, authenticated;
revoke all on function private.allocate_work_order_number(integer) from public, anon;
grant execute on function private.allocate_work_order_number(integer) to authenticated;
grant execute on function public.allocate_work_order_number(integer) to authenticated;

create or replace function private.protect_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' then
    new.organization_id := old.organization_id;
    if new.role is distinct from old.role
       and coalesce(private.current_role(), '') <> 'admin'
       and auth.uid() is not null then
      new.role := old.role;
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  org_id uuid;
  member_count integer;
  assigned_role text;
begin
  select id into org_id from public.organizations where slug = 'gs-solucoes' limit 1;
  if org_id is null then
    return new;
  end if;

  select count(*) into member_count from public.profiles where organization_id = org_id;

  if member_count = 0 then
    assigned_role := 'admin';
  else
    assigned_role := coalesce(new.raw_app_meta_data->>'role', 'technician');
  end if;

  insert into public.profiles (id, organization_id, email, full_name, role)
  values (
    new.id,
    org_id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    assigned_role
  );

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- updated_at + org enforcement
do $$
declare
  t text;
begin
  foreach t in array array[
    'organizations', 'profiles', 'employees', 'clients', 'locations',
    'work_orders', 'time_entries'
  ]
  loop
    execute format(
      'drop trigger if exists set_updated_at on public.%I;
       create trigger set_updated_at before update on public.%I
       for each row execute function private.set_updated_at();',
      t, t
    );
  end loop;

  foreach t in array array[
    'profiles', 'employees', 'technicians', 'clients', 'client_contacts',
    'locations', 'work_orders', 'work_order_technicians', 'work_order_events',
    'time_entries', 'service_reports', 'attachments', 'signatures',
    'audit_logs', 'sync_mutations', 'holidays'
  ]
  loop
    execute format(
      'drop trigger if exists enforce_org_id on public.%I;
       create trigger enforce_org_id before insert or update on public.%I
       for each row execute function private.enforce_org_id();',
      t, t
    );
  end loop;
end;
$$;

drop trigger if exists protect_profile on public.profiles;
create trigger protect_profile
  before update on public.profiles
  for each row execute function private.protect_profile();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.employees enable row level security;
alter table public.technicians enable row level security;
alter table public.clients enable row level security;
alter table public.client_contacts enable row level security;
alter table public.locations enable row level security;
alter table public.work_order_sequences enable row level security;
alter table public.work_orders enable row level security;
alter table public.work_order_technicians enable row level security;
alter table public.work_order_events enable row level security;
alter table public.time_entries enable row level security;
alter table public.service_reports enable row level security;
alter table public.attachments enable row level security;
alter table public.signatures enable row level security;
alter table public.audit_logs enable row level security;
alter table public.sync_mutations enable row level security;
alter table public.holidays enable row level security;

-- sequences: only via definer function
create policy "no direct sequence access"
  on public.work_order_sequences
  for all
  using (false);

create policy "org members read org"
  on public.organizations for select
  to authenticated
  using (id = private.current_org_id());

create policy "admins update org"
  on public.organizations for update
  to authenticated
  using (id = private.current_org_id() and private.current_role() = 'admin')
  with check (id = private.current_org_id());

create policy "org members read profiles"
  on public.profiles for select
  to authenticated
  using (organization_id = private.current_org_id());

create policy "users update own profile"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "admins manage profiles"
  on public.profiles for all
  to authenticated
  using (organization_id = private.current_org_id() and private.current_role() = 'admin')
  with check (organization_id = private.current_org_id() and private.current_role() = 'admin');

-- Generic org isolation for remaining tables
do $$
declare
  t text;
begin
  foreach t in array array[
    'employees', 'technicians', 'clients', 'client_contacts', 'locations',
    'work_orders', 'work_order_technicians', 'work_order_events',
    'time_entries', 'service_reports', 'attachments', 'signatures', 'holidays'
  ]
  loop
    execute format(
      'create policy %I on public.%I for select to authenticated
         using (organization_id = private.current_org_id());
       create policy %I on public.%I for insert to authenticated
         with check (organization_id = private.current_org_id());
       create policy %I on public.%I for update to authenticated
         using (organization_id = private.current_org_id())
         with check (organization_id = private.current_org_id());
       create policy %I on public.%I for delete to authenticated
         using (organization_id = private.current_org_id()
           and private.current_role() in (''admin'', ''office'', ''lead_tech''));',
      t || '_select', t,
      t || '_insert', t,
      t || '_update', t,
      t || '_delete', t
    );
  end loop;
end;
$$;

create policy "audit_logs_select"
  on public.audit_logs for select
  to authenticated
  using (organization_id = private.current_org_id() and private.current_role() in ('admin', 'office', 'lead_tech'));

create policy "audit_logs_insert"
  on public.audit_logs for insert
  to authenticated
  with check (organization_id = private.current_org_id());

create policy "sync_mutations_own"
  on public.sync_mutations for select
  to authenticated
  using (user_id = auth.uid());

create policy "sync_mutations_insert"
  on public.sync_mutations for insert
  to authenticated
  with check (user_id = auth.uid() and organization_id = private.current_org_id());

revoke all on all tables in schema public from anon;
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('attachments', 'attachments', false)
on conflict (id) do nothing;

create policy "attachments_select"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = private.current_org_id()::text
  );

create policy "attachments_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = private.current_org_id()::text
  );

create policy "attachments_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = private.current_org_id()::text
  )
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = private.current_org_id()::text
  );

-- ---------------------------------------------------------------------------
-- Seed: empresa GS
-- ---------------------------------------------------------------------------

insert into public.organizations (
  id, name, slug, legal_name, trade_name, address, phone, website
) values (
  '8f3c2a10-9b4e-4d6a-a1c2-000000000001',
  'GS Soluções Técnicas',
  'gs-solucoes',
  'GS SOLUÇÕES LTDA',
  'GS SOLUÇÕES',
  'AV. GEN. DEODORO, 1893, CREMAÇÃO, BELÉM/PA',
  '(21) 9.9578-8574',
  'https://gssolucoestec.com.br'
) on conflict (id) do nothing;
