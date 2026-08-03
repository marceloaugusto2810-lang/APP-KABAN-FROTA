-- =====================================================================
-- Migração — Operações + Alertas Operacionais
-- Rode no SQL Editor do Supabase. Idempotente. Aditiva (não quebra nada).
-- =====================================================================

-- 1) Operações ----------------------------------------------------------
create table if not exists public.operacoes (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  nome text not null,
  cor text not null default '#10b981',
  icone text,
  ordem integer not null default 0,
  ativo boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.operacoes (slug, nome, cor, ordem) values
  ('farelo','Farelo','#10b981',1),
  ('calcario','Calcário','#a3a3a3',2),
  ('gesso','Gesso','#f59e0b',3),
  ('adubo','Adubo','#22c55e',4),
  ('frango_americano','Frango Americano','#ef4444',5),
  ('cavaco','Cavaco','#8b5cf6',6),
  ('outros','Outros','#64748b',99)
on conflict (slug) do nothing;

grant select, insert, update, delete on public.operacoes to anon, authenticated;
alter table public.operacoes enable row level security;
drop policy if exists "operacoes full access" on public.operacoes;
create policy "operacoes full access" on public.operacoes for all using(true) with check(true);
alter publication supabase_realtime add table public.operacoes;

-- 2) Vínculo veículo ↔ operação (default 'farelo' para os atuais) -------
alter table public.veiculos
  add column if not exists operacao_slug text not null default 'farelo';
create index if not exists veiculos_operacao_idx on public.veiculos(operacao_slug);

-- Status pode ser global (null) ou específico de uma operação
alter table public.kanban_status
  add column if not exists operacao_slug text;

-- 3) Alertas ------------------------------------------------------------
create table if not exists public.alertas (
  id uuid primary key default gen_random_uuid(),
  placa text,
  motorista text,
  tipo text not null check (tipo in ('manutencao','folga','restricao','observacao','outro')),
  descricao text not null,
  ativo boolean not null default true,
  criado_por text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (placa is not null or motorista is not null)
);
create index if not exists alertas_placa_ativo_idx on public.alertas(placa) where ativo;
create index if not exists alertas_motorista_ativo_idx on public.alertas(motorista) where ativo;

grant select, insert, update, delete on public.alertas to anon, authenticated;
alter table public.alertas enable row level security;
drop policy if exists "alertas full access" on public.alertas;
create policy "alertas full access" on public.alertas for all using(true) with check(true);
alter publication supabase_realtime add table public.alertas;

-- 4) Histórico de alertas -----------------------------------------------
create table if not exists public.alertas_historico (
  id uuid primary key default gen_random_uuid(),
  alerta_id uuid references public.alertas(id) on delete cascade,
  acao text not null,
  detalhes jsonb,
  created_at timestamptz not null default now()
);
create index if not exists alertas_hist_alerta_idx on public.alertas_historico(alerta_id, created_at desc);

grant select, insert, update, delete on public.alertas_historico to anon, authenticated;
alter table public.alertas_historico enable row level security;
drop policy if exists "alertas_historico full access" on public.alertas_historico;
create policy "alertas_historico full access" on public.alertas_historico for all using(true) with check(true);
