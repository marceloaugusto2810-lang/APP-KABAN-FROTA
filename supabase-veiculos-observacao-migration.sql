-- =====================================================================
-- Kanban Operacional · Migração aditiva — coluna `observacao` em veiculos
-- Execute no SQL Editor do Supabase. Idempotente — pode rodar várias vezes.
-- =====================================================================

-- 1) Coluna observacao (texto livre, opcional)
ALTER TABLE public.veiculos
  ADD COLUMN IF NOT EXISTS observacao text;

-- 2) Garante GRANTs (a tabela já é exposta na Data API; nada a alterar
--    além de manter consistência caso este arquivo seja a primeira ação).
GRANT SELECT, INSERT, UPDATE, DELETE ON public.veiculos TO anon, authenticated;

-- 3) Comentário
COMMENT ON COLUMN public.veiculos.observacao IS
  'Observação operacional livre, editável pela Lista Agrupada e Tabela.';
