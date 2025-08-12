-- Create import tables and policies, plus storage bucket for temporary imports
-- 1) import_jobs table
CREATE TABLE IF NOT EXISTS public.import_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  law_firm_id UUID NOT NULL,
  source TEXT NOT NULL DEFAULT 'docketwise',
  status TEXT NOT NULL DEFAULT 'uploaded',
  file_path TEXT NOT NULL,
  file_type TEXT NOT NULL,
  total_count INTEGER DEFAULT 0,
  success_count INTEGER DEFAULT 0,
  error_count INTEGER DEFAULT 0,
  dry_run BOOLEAN NOT NULL DEFAULT true,
  settings JSONB NOT NULL DEFAULT '{}'::jsonb,
  report_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);

-- 2) import_logs table
CREATE TABLE IF NOT EXISTS public.import_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES public.import_jobs(id) ON DELETE CASCADE,
  row_number INTEGER,
  entity TEXT NOT NULL,
  external_id TEXT,
  status TEXT NOT NULL,
  message TEXT,
  data JSONB,
  error_code TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3) import_mappings table
CREATE TABLE IF NOT EXISTS public.import_mappings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES public.import_jobs(id) ON DELETE CASCADE,
  entity TEXT NOT NULL,
  source_column TEXT NOT NULL,
  target_field TEXT NOT NULL,
  transform TEXT,
  sample_value TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_import_jobs_user ON public.import_jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_import_jobs_firm ON public.import_jobs(law_firm_id);
CREATE INDEX IF NOT EXISTS idx_import_logs_job ON public.import_logs(job_id);
CREATE INDEX IF NOT EXISTS idx_import_mappings_job ON public.import_mappings(job_id);

-- Trigger to keep updated_at fresh
CREATE OR REPLACE FUNCTION public.update_import_jobs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_import_jobs_updated_at ON public.import_jobs;
CREATE TRIGGER trg_update_import_jobs_updated_at
BEFORE UPDATE ON public.import_jobs
FOR EACH ROW EXECUTE FUNCTION public.update_import_jobs_updated_at();

-- Enable RLS
ALTER TABLE public.import_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.import_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.import_mappings ENABLE ROW LEVEL SECURITY;

-- Policies for import_jobs
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='import_jobs' AND policyname='Users can insert own import jobs' 
  ) THEN
    CREATE POLICY "Users can insert own import jobs"
    ON public.import_jobs FOR INSERT
    WITH CHECK (user_id = auth.uid());
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='import_jobs' AND policyname='Users can view own import jobs' 
  ) THEN
    CREATE POLICY "Users can view own import jobs"
    ON public.import_jobs FOR SELECT
    USING (user_id = auth.uid());
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='import_jobs' AND policyname='Users can update own import jobs' 
  ) THEN
    CREATE POLICY "Users can update own import jobs"
    ON public.import_jobs FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());
  END IF;
END $$;

-- Policies for import_logs (system inserts, users read their own job logs)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='import_logs' AND policyname='System can insert import logs' 
  ) THEN
    CREATE POLICY "System can insert import logs"
    ON public.import_logs FOR INSERT
    WITH CHECK (true);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='import_logs' AND policyname='Users can view logs of their jobs' 
  ) THEN
    CREATE POLICY "Users can view logs of their jobs"
    ON public.import_logs FOR SELECT
    USING (job_id IN (SELECT id FROM public.import_jobs WHERE user_id = auth.uid()));
  END IF;
END $$;

-- Policies for import_mappings (users manage their own mappings)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='import_mappings' AND policyname='Users can manage mappings for their jobs' 
  ) THEN
    CREATE POLICY "Users can manage mappings for their jobs"
    ON public.import_mappings FOR ALL
    USING (job_id IN (SELECT id FROM public.import_jobs WHERE user_id = auth.uid()))
    WITH CHECK (job_id IN (SELECT id FROM public.import_jobs WHERE user_id = auth.uid()));
  END IF;
END $$;

-- Create storage bucket for temporary imports
INSERT INTO storage.buckets (id, name, public)
VALUES ('imports-temp', 'imports-temp', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for imports-temp
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='Users can upload to imports-temp in own folder' 
  ) THEN
    CREATE POLICY "Users can upload to imports-temp in own folder"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
      bucket_id = 'imports-temp' AND
      auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='Users can read their imports-temp files' 
  ) THEN
    CREATE POLICY "Users can read their imports-temp files"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (
      bucket_id = 'imports-temp' AND
      auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='Users can delete their imports-temp files' 
  ) THEN
    CREATE POLICY "Users can delete their imports-temp files"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
      bucket_id = 'imports-temp' AND
      auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;
END $$;