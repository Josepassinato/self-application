-- 1) Corrigir views com privilégios de definer (usar invoker)
DO $$
BEGIN
  -- security_dashboard
  IF EXISTS (
    SELECT 1 FROM information_schema.views 
    WHERE table_schema = 'public' AND table_name = 'security_dashboard'
  ) THEN
    EXECUTE 'ALTER VIEW public.security_dashboard SET (security_invoker = true)';
  END IF;

  -- document_analysis_audit_report
  IF EXISTS (
    SELECT 1 FROM information_schema.views 
    WHERE table_schema = 'public' AND table_name = 'document_analysis_audit_report'
  ) THEN
    EXECUTE 'ALTER VIEW public.document_analysis_audit_report SET (security_invoker = true)';
  END IF;
END $$;

-- 2) Mover extensões instaladas no schema public para o schema extensions
DO $$
DECLARE
  ext RECORD;
BEGIN
  FOR ext IN
    SELECT extname FROM pg_extension e 
    JOIN pg_namespace n ON n.oid = e.extnamespace 
    WHERE n.nspname = 'public'
  LOOP
    EXECUTE format('ALTER EXTENSION %I SET SCHEMA extensions', ext.extname);
  END LOOP;
END $$;

-- 3) Atualizar o cron job com URL/ANON reais
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'daily-db-backup') THEN
    PERFORM cron.unschedule((SELECT jobid FROM cron.job WHERE jobname = 'daily-db-backup' LIMIT 1));
  END IF;
END $$;

select cron.schedule(
  'daily-db-backup',
  '0 3 * * *',
  $$
  select
    net.http_post(
      url := 'https://apoeceltgnvohsbxfopb.supabase.co/functions/v1/db-backup',
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFwb2VjZWx0Z252b2hzYnhmb3BiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzNDA2MDQsImV4cCI6MjA2NzkxNjYwNH0.IzKP2-n-EGVkfZ-wXQdAmtK36nryqZc8RFEY0qZL6qM"}'::jsonb,
      body := jsonb_build_object('time', now(), 'source', 'pg_cron', 'schedule', 'daily-03:00-UTC')
    ) as request_id;
  $$
);
