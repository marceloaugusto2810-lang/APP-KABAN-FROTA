-- =====================================================================
-- Kanban de Folgas & Atrelamentos + Auth/Roles
-- Rode este SQL manualmente no SQL Editor do Supabase. Idempotente.
-- =====================================================================

-- 1) Extensões da tabela motoristas (reaproveitando existente) ---------
alter table public.motoristas
  add column if not exists cnh text,
  add column if not exists categoria_cnh text,
  add column if not exists telefone text,
  add column if not exists updated_at timestamptz not null default now();

create or replace function public.tg_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists trg_motoristas_updated_at on public.motoristas;
create trigger trg_motoristas_updated_at
before update on public.motoristas
for each row execute function public.tg_set_updated_at();

-- 2) caminhoes_meta (deriva das placas do Kanban) ----------------------
create table if not exists public.caminhoes_meta (
  placa text primary key,
  modelo text,
  tipo text not null check (tipo in ('graneleiro','basculante')),
  status text not null default 'disponivel'
    check (status in ('disponivel','alocado','manutencao')),
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
drop trigger if exists trg_caminhoes_meta_updated_at on public.caminhoes_meta;
create trigger trg_caminhoes_meta_updated_at
before update on public.caminhoes_meta
for each row execute function public.tg_set_updated_at();

-- 3) Roles (padrão security-definer, sem recursão) ---------------------
do $$ begin
  if not exists (select 1 from pg_type where typname = 'app_role') then
    create type public.app_role as enum ('master','analista');
  end if;
end $$;

create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.app_role not null,
  created_at timestamptz not null default now(),
  unique (user_id, role)
);

create or replace function public.has_role(_user_id uuid, _role public.app_role)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = _user_id and role = _role
  )
$$;

-- 4) folgas_ausencias --------------------------------------------------
create table if not exists public.folgas_ausencias (
  id uuid primary key default gen_random_uuid(),
  motorista_id uuid references public.motoristas(id) on delete cascade,
  placa text references public.caminhoes_meta(placa) on delete cascade,
  tipo text not null check (tipo in ('folga','folga_manutencao')),
  data_inicio date not null default current_date,
  data_fim date,
  motivo text,
  observacao text,
  criado_por uuid references auth.users(id),
  created_at timestamptz not null default now(),
  constraint folga_alvo_unico check (
    (motorista_id is not null and placa is null)
    or (motorista_id is null and placa is not null)
  )
);
create unique index if not exists folgas_um_ativo_por_motorista
  on public.folgas_ausencias(motorista_id)
  where data_fim is null and motorista_id is not null;
create unique index if not exists folgas_um_ativo_por_placa
  on public.folgas_ausencias(placa)
  where data_fim is null and placa is not null;
create index if not exists folgas_tipo_idx on public.folgas_ausencias(tipo);

-- 5) GRANTs ------------------------------------------------------------
grant select, insert, update, delete on public.caminhoes_meta to authenticated;
grant all on public.caminhoes_meta to service_role;

grant select, insert, update on public.folgas_ausencias to authenticated;
-- DELETE apenas via policy (Master)
grant delete on public.folgas_ausencias to authenticated;
grant all on public.folgas_ausencias to service_role;

grant select on public.user_roles to authenticated;
grant all on public.user_roles to service_role;

-- 6) RLS ---------------------------------------------------------------
alter table public.caminhoes_meta enable row level security;
drop policy if exists "caminhoes_meta read auth" on public.caminhoes_meta;
create policy "caminhoes_meta read auth" on public.caminhoes_meta
  for select to authenticated using (true);
drop policy if exists "caminhoes_meta write auth" on public.caminhoes_meta;
create policy "caminhoes_meta write auth" on public.caminhoes_meta
  for insert to authenticated with check (true);
drop policy if exists "caminhoes_meta update auth" on public.caminhoes_meta;
create policy "caminhoes_meta update auth" on public.caminhoes_meta
  for update to authenticated using (true) with check (true);
drop policy if exists "caminhoes_meta delete master" on public.caminhoes_meta;
create policy "caminhoes_meta delete master" on public.caminhoes_meta
  for delete to authenticated using (public.has_role(auth.uid(),'master'));

alter table public.folgas_ausencias enable row level security;
drop policy if exists "folgas read auth" on public.folgas_ausencias;
create policy "folgas read auth" on public.folgas_ausencias
  for select to authenticated using (true);
drop policy if exists "folgas insert auth" on public.folgas_ausencias;
create policy "folgas insert auth" on public.folgas_ausencias
  for insert to authenticated
  with check (criado_por is null or criado_por = auth.uid());
drop policy if exists "folgas update auth" on public.folgas_ausencias;
create policy "folgas update auth" on public.folgas_ausencias
  for update to authenticated using (true) with check (true);
drop policy if exists "folgas delete master" on public.folgas_ausencias;
create policy "folgas delete master" on public.folgas_ausencias
  for delete to authenticated using (public.has_role(auth.uid(),'master'));

alter table public.user_roles enable row level security;
drop policy if exists "user_roles self read" on public.user_roles;
create policy "user_roles self read" on public.user_roles
  for select to authenticated using (user_id = auth.uid() or public.has_role(auth.uid(),'master'));
drop policy if exists "user_roles master write" on public.user_roles;
create policy "user_roles master write" on public.user_roles
  for all to authenticated
  using (public.has_role(auth.uid(),'master'))
  with check (public.has_role(auth.uid(),'master'));

-- 7) Realtime ----------------------------------------------------------
do $$ begin
  perform 1 from pg_publication_tables
   where pubname='supabase_realtime' and schemaname='public' and tablename='caminhoes_meta';
  if not found then execute 'alter publication supabase_realtime add table public.caminhoes_meta'; end if;
  perform 1 from pg_publication_tables
   where pubname='supabase_realtime' and schemaname='public' and tablename='folgas_ausencias';
  if not found then execute 'alter publication supabase_realtime add table public.folgas_ausencias'; end if;
  perform 1 from pg_publication_tables
   where pubname='supabase_realtime' and schemaname='public' and tablename='user_roles';
  if not found then execute 'alter publication supabase_realtime add table public.user_roles'; end if;
end $$;

-- =====================================================================
-- OPCIONAL — promover seu usuário a master (rode DEPOIS de criar login):
--   insert into public.user_roles (user_id, role)
--   values ('SEU_USER_ID_AQUI', 'master');
-- =====================================================================
