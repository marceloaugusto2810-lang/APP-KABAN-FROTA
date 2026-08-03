-- Histórico da condição de carga: registrar o usuário responsável
-- e garantir que todos os perfis do app consigam salvar a alteração.

-- 1) Coluna do usuário responsável (data/hora já existe em data_movimentacao)
ALTER TABLE public.historico_movimentacoes
  ADD COLUMN IF NOT EXISTS usuario TEXT;

-- 2) Restringir a carga aos dois valores válidos
ALTER TABLE public.veiculos
  DROP CONSTRAINT IF EXISTS veiculos_carga_status_check;
UPDATE public.veiculos
  SET carga_status = 'vazio'
  WHERE carga_status IS NULL OR carga_status NOT IN ('vazio', 'carregado');
ALTER TABLE public.veiculos
  ALTER COLUMN carga_status SET DEFAULT 'vazio',
  ADD CONSTRAINT veiculos_carga_status_check
    CHECK (carga_status IN ('vazio', 'carregado'));

-- 3) Permissões da Data API (app sem login: papel anon + authenticated)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.veiculos TO anon, authenticated;
GRANT SELECT, INSERT ON public.historico_movimentacoes TO anon, authenticated;
GRANT ALL ON public.veiculos TO service_role;
GRANT ALL ON public.historico_movimentacoes TO service_role;

-- 4) Políticas RLS abertas (mesmo modelo já adotado no projeto sem autenticação)
ALTER TABLE public.veiculos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.historico_movimentacoes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "veiculos_update_all" ON public.veiculos;
CREATE POLICY "veiculos_update_all" ON public.veiculos
  FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "veiculos_select_all" ON public.veiculos;
CREATE POLICY "veiculos_select_all" ON public.veiculos
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "historico_insert_all" ON public.historico_movimentacoes;
CREATE POLICY "historico_insert_all" ON public.historico_movimentacoes
  FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP POLICY IF EXISTS "historico_select_all" ON public.historico_movimentacoes;
CREATE POLICY "historico_select_all" ON public.historico_movimentacoes
  FOR SELECT TO anon, authenticated USING (true);
