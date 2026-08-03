-- =====================================================================
-- Kanban Operacional · Farelo — Schema Supabase
-- Rode este SQL no SQL Editor do seu projeto Supabase (gratuito).
-- =====================================================================

-- Status possíveis (espelham src/lib/kanban-store.ts)
-- patio_esmagadora | transito_esmagadora | patio_rei_selvas
-- transito_rei_selvas | pulmao_km16 | porto_gdias
-- sem_programacao | disponivel | manutencao

create table if not exists public.veiculos (
  id uuid primary key default gen_random_uuid(),
  placa text not null unique,
  motorista text not null,
  status text not null default 'sem_programacao',
  carga_status text not null default 'vazio',     -- 'vazio' | 'carregado'
  entrada_status timestamptz not null default now(), -- início do tempo na etapa atual
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists veiculos_status_idx on public.veiculos(status);

create table if not exists public.historico_movimentacoes (
  id uuid primary key default gen_random_uuid(),
  veiculo_id uuid references public.veiculos(id) on delete cascade,
  placa text not null,
  motorista text not null,
  status_anterior text,
  status_novo text not null,
  carga_status text,
  data_movimentacao timestamptz not null default now()
);

create index if not exists historico_veiculo_idx
  on public.historico_movimentacoes(veiculo_id, data_movimentacao desc);

-- ------- Permissões (Data API / PostgREST) -------
grant select, insert, update, delete on public.veiculos to anon, authenticated;
grant select, insert, update, delete on public.historico_movimentacoes to anon, authenticated;

-- ------- RLS aberta (operação interna) -------
-- Se quiser restringir depois, troque por políticas com auth.uid().
alter table public.veiculos enable row level security;
alter table public.historico_movimentacoes enable row level security;

drop policy if exists "veiculos full access" on public.veiculos;
create policy "veiculos full access" on public.veiculos
  for all using (true) with check (true);

drop policy if exists "historico full access" on public.historico_movimentacoes;
create policy "historico full access" on public.historico_movimentacoes
  for all using (true) with check (true);

-- ------- Realtime -------
alter publication supabase_realtime add table public.veiculos;
alter publication supabase_realtime add table public.historico_movimentacoes;
