-- Versionamento para immigration_forms
ALTER TABLE public.immigration_forms
  ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;

-- Unicidade por código+versão
CREATE UNIQUE INDEX IF NOT EXISTS idx_immigration_forms_code_version
  ON public.immigration_forms (form_code, version);

-- Apenas uma versão ativa por form_code
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = 'idx_immigration_forms_one_active_per_code'
  ) THEN
    EXECUTE 'CREATE UNIQUE INDEX idx_immigration_forms_one_active_per_code ON public.immigration_forms (form_code) WHERE is_active';
  END IF;
END $$;

-- Trigger para manter updated_at
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'immigration_forms_set_updated_at'
  ) THEN
    CREATE TRIGGER immigration_forms_set_updated_at
    BEFORE UPDATE ON public.immigration_forms
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
END $$;