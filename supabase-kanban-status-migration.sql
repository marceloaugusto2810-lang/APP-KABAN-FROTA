-- =====================================================================
-- Migração — Colunas/Status dinâmicos do Kanban
-- Rode no SQL Editor do Supabase. Idempotente.
-- =====================================================================

create table if not exists public.kanban_status (
  id uuid primary key default gen_random_uuid(),
  slug text unique,
  nome text not null,
  cor text not null default '#64748b',
  ordem integer not null default 0,
  ativo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists kanban_status_nome_ativo_uniq
  on public.kanban_status (lower(nome)) where ativo;

grant select, insert, update, delete on public.kanban_status to anon, authenticated;
alter table public.kanban_status enable row level security;
drop policy if exists "kanban_status full access" on public.kanban_status;
create policy "kanban_status full access" on public.kanban_status
  for all using (true) with check (true);

alter publication supabase_realtime add table public.kanban_status;

-- Seed com os status atuais (idempotente via slug)
insert into public.kanban_status (slug, nome, cor, ordem) values
  ('patio_esmagadora',     'Pátio Esmagadora',                 '#3b82f6', 1),
  ('transito_esmagadora',  'Em trânsito para Esmagadora',      '#f59e0b', 2),
  ('patio_rei_selvas',     'Pátio Posto Rei das Selvas',       '#6366f1', 3),
  ('transito_rei_selvas',  'Em trânsito Posto Rei das Selvas', '#f97316', 4),
  ('pulmao_km16',          'Pulmão KM 16',                     '#06b6d4', 5),
  ('porto_gdias',          'Porto G Dias',                     '#10b981', 6),
  ('sem_programacao',      'Sem Programação',                  '#94a3b8', 7),
  ('disponivel',           'Disponível',                       '#22c55e', 8),
  ('manutencao',           'Manutenção',                       '#ef4444', 9)
on conflict (slug) do nothing;

-- Vínculo opcional na tabela veiculos (mantém coluna status texto)
alter table public.veiculos
  add column if not exists status_id uuid references public.kanban_status(id);

update public.veiculos v
   set status_id = k.id
  from public.kanban_status k
 where v.status_id is null and v.status = k.slug;

create index if not exists veiculos_status_id_idx on public.veiculos(status_id);
