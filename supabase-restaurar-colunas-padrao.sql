-- =====================================================================
-- Restaurar colunas padrão do Kanban (NÃO APAGA NADA)
-- Rode no SQL Editor do Supabase. Idempotente.
-- =====================================================================

-- 1) Reativa qualquer coluna que tenha sido marcada como inativa
update public.kanban_status
   set ativo = true
 where ativo = false;

-- 2) Limpa o vínculo operacao_slug em kanban_status para que todas as
--    colunas voltem a ser globais (visíveis no Kanban geral).
update public.kanban_status
   set operacao_slug = null
 where operacao_slug is not null;

-- 3) Reinsere as 6 colunas padrão que sumiram (caso tenham sido deletadas).
--    O ON CONFLICT garante que nada existente é sobrescrito.
insert into public.kanban_status (id, slug, nome, cor, ordem, ativo)
values
  ('patio_esmagadora',     'patio_esmagadora',     'Pátio Esmagadora',                 '#3b82f6', 1, true),
  ('transito_esmagadora',  'transito_esmagadora',  'Em trânsito para Esmagadora',      '#f59e0b', 2, true),
  ('patio_rei_selvas',     'patio_rei_selvas',     'Pátio Posto Rei das Selvas',       '#6366f1', 3, true),
  ('transito_rei_selvas',  'transito_rei_selvas',  'Em trânsito Posto Rei das Selvas', '#f97316', 4, true),
  ('pulmao_km16',          'pulmao_km16',          'Pulmão KM 16',                     '#06b6d4', 5, true),
  ('porto_gdias',          'porto_gdias',          'Porto G Dias',                     '#10b981', 6, true)
on conflict (id) do update
   set ativo = true,
       nome  = excluded.nome,
       slug  = coalesce(public.kanban_status.slug, excluded.slug);
