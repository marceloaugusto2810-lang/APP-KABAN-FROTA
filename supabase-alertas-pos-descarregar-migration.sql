-- =====================================================================
-- Migração — Alertas Pós Descarregar (trava inteligente)
-- Aditiva. Não apaga dados existentes.
-- =====================================================================

alter table public.alertas
  add column if not exists momento_alerta text not null default 'imediato',
  add column if not exists disparado boolean not null default false,
  add column if not exists ciclo_armado boolean not null default false,
  add column if not exists data_disparo timestamptz;

-- Garante valores válidos
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'alertas_momento_chk'
  ) then
    alter table public.alertas
      add constraint alertas_momento_chk
      check (momento_alerta in ('imediato','pos_descarregar'));
  end if;
end$$;

create index if not exists alertas_pos_desc_idx
  on public.alertas(momento_alerta) where momento_alerta = 'pos_descarregar';
