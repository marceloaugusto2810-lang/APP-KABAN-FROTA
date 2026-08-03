-- ============================================================
-- Status dinâmico "Chega dia DD/MM"
-- Guarda a data prevista de chegada e a finalidade em colunas próprias
-- da tabela `veiculos` — sem criar um status cadastrado por data.
-- ============================================================

ALTER TABLE public.veiculos
  ADD COLUMN IF NOT EXISTS chegada_prevista DATE,
  ADD COLUMN IF NOT EXISTS chegada_finalidade TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'veiculos_chegada_finalidade_check'
  ) THEN
    ALTER TABLE public.veiculos
      ADD CONSTRAINT veiculos_chegada_finalidade_check
      CHECK (chegada_finalidade IS NULL OR chegada_finalidade IN ('carregar', 'descarregar'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS veiculos_chegada_prevista_idx
  ON public.veiculos (chegada_prevista)
  WHERE chegada_prevista IS NOT NULL;

COMMENT ON COLUMN public.veiculos.chegada_prevista IS
  'Data prevista de chegada usada pelo status operacional "Chega dia DD/MM".';
COMMENT ON COLUMN public.veiculos.chegada_finalidade IS
  'Finalidade da chegada prevista: carregar ou descarregar.';
