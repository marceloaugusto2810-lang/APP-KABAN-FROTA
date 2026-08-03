-- =====================================================================
-- Módulo Motoristas x Frota — Migração
-- Rode este SQL no SQL Editor do Supabase. Idempotente. Aditiva.
-- =====================================================================

-- 1) Motoristas ---------------------------------------------------------
create table if not exists public.motoristas (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  ativo boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists motoristas_ativo_idx on public.motoristas(ativo);

grant select, insert, update, delete on public.motoristas to anon, authenticated;
alter table public.motoristas enable row level security;
drop policy if exists "motoristas full access" on public.motoristas;
create policy "motoristas full access" on public.motoristas
  for all using (true) with check (true);

-- 2) Vínculo motorista ↔ caminhão (placa) ------------------------------
create table if not exists public.vinculo_motorista_caminhao (
  id uuid primary key default gen_random_uuid(),
  placa text not null,
  motorista_id uuid not null references public.motoristas(id) on delete cascade,
  tipo text not null check (tipo in ('FIXO','TEMPORARIO')),
  data_inicio date not null default current_date,
  data_fim date,
  motivo_fim text,
  ativo boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists vinculo_placa_idx on public.vinculo_motorista_caminhao(placa) where ativo;
create index if not exists vinculo_motorista_idx on public.vinculo_motorista_caminhao(motorista_id) where ativo;
-- Somente 1 vínculo FIXO ativo por placa
create unique index if not exists idx_um_fixo_ativo
  on public.vinculo_motorista_caminhao(placa)
  where tipo = 'FIXO' and ativo = true;
-- Somente 1 vínculo TEMPORARIO ativo por placa (evita dois substitutos)
create unique index if not exists idx_um_temporario_ativo
  on public.vinculo_motorista_caminhao(placa)
  where tipo = 'TEMPORARIO' and ativo = true;

grant select, insert, update, delete on public.vinculo_motorista_caminhao to anon, authenticated;
alter table public.vinculo_motorista_caminhao enable row level security;
drop policy if exists "vinculo_motorista_caminhao full access" on public.vinculo_motorista_caminhao;
create policy "vinculo_motorista_caminhao full access" on public.vinculo_motorista_caminhao
  for all using (true) with check (true);

-- 3) Status diário do motorista ----------------------------------------
create table if not exists public.motorista_status_diario (
  id uuid primary key default gen_random_uuid(),
  motorista_id uuid not null references public.motoristas(id) on delete cascade,
  data date not null default current_date,
  status text not null check (status in ('TRABALHANDO','FOLGA','FERIAS','AFASTADO','DISPONIVEL_SEM_CAMINHAO')),
  placa_atual text,
  observacao text,
  data_prevista_retorno date,
  created_at timestamptz not null default now(),
  unique (motorista_id, data)
);
create index if not exists msd_data_idx on public.motorista_status_diario(data desc);
create index if not exists msd_status_idx on public.motorista_status_diario(status, data desc);

grant select, insert, update, delete on public.motorista_status_diario to anon, authenticated;
alter table public.motorista_status_diario enable row level security;
drop policy if exists "motorista_status_diario full access" on public.motorista_status_diario;
create policy "motorista_status_diario full access" on public.motorista_status_diario
  for all using (true) with check (true);

-- 4) Realtime -----------------------------------------------------------
do $$ begin
  perform 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='motoristas';
  if not found then execute 'alter publication supabase_realtime add table public.motoristas'; end if;
  perform 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='vinculo_motorista_caminhao';
  if not found then execute 'alter publication supabase_realtime add table public.vinculo_motorista_caminhao'; end if;
  perform 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='motorista_status_diario';
  if not found then execute 'alter publication supabase_realtime add table public.motorista_status_diario'; end if;
end $$;
