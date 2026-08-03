-- =====================================================================
-- Migração aditiva — Tabela detalhada "Próxima Programação"
-- Idempotente. Não apaga dados existentes. Apenas garante colunas e
-- índices necessários para a visualização em tabela detalhada.
-- Rode no SQL Editor do Supabase.
-- =====================================================================

-- 1) Garantir colunas usadas pela tabela detalhada em public.veiculos.
--    Todas já foram criadas na migração anterior; ALTER aditivo seguro.
alter table public.veiculos
  add column if not exists proxima_programacao text,
  add column if not exists proxima_programacao_observacao text,
  add column if not exists proxima_programacao_data timestamptz,
  add column if not exists proxima_programacao_criada_por text,
  add column if not exists proxima_programacao_criada_em timestamptz,
  add column if not exists proxima_programacao_atualizada_por text,
  add column if not exists proxima_programacao_atualizada_em timestamptz;

-- 2) Índices que aceleram os filtros "com" e "sem" próxima programação,
--    considerando strings vazias como "sem programação".
create index if not exists veiculos_com_prox_prog_filled_idx
  on public.veiculos(placa)
  where proxima_programacao is not null
    and length(btrim(proxima_programacao)) > 0;

create index if not exists veiculos_sem_prox_prog_empty_idx
  on public.veiculos(placa)
  where proxima_programacao is null
    or length(btrim(proxima_programacao)) = 0;

-- 3) Índices auxiliares para ordenação por status, operação e tempo.
create index if not exists veiculos_status_idx
  on public.veiculos(status);

create index if not exists veiculos_operacao_idx
  on public.veiculos(operacao_slug);

create index if not exists veiculos_entrada_status_idx
  on public.veiculos(entrada_status);

-- 4) View opcional somente leitura para auditoria/relatórios externos.
create or replace view public.veiculos_prox_prog_view as
  select
    v.id,
    v.placa,
    v.motorista,
    v.status,
    v.operacao_slug,
    v.tipo_implemento,
    v.carga_status,
    v.entrada_status,
    v.updated_at,
    v.proxima_programacao,
    v.proxima_programacao_observacao,
    v.proxima_programacao_data,
    v.proxima_programacao_criada_por,
    v.proxima_programacao_criada_em,
    v.proxima_programacao_atualizada_por,
    v.proxima_programacao_atualizada_em,
    case
      when v.proxima_programacao is not null
       and length(btrim(v.proxima_programacao)) > 0
      then true
      else false
    end as possui_prox_prog
  from public.veiculos v;

grant select on public.veiculos_prox_prog_view to anon, authenticated;
grant all on public.veiculos_prox_prog_view to service_role;

-- =====================================================================
-- Fim da migração
-- =====================================================================
