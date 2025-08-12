-- Ajustar views para security_invoker
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.views 
    WHERE table_schema = 'public' AND table_name = 'security_dashboard'
  ) THEN
    EXECUTE 'ALTER VIEW IF EXISTS public.security_dashboard SET (security_invoker = true)';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.views 
    WHERE table_schema = 'public' AND table_name = 'document_analysis_audit_report'
  ) THEN
    EXECUTE 'ALTER VIEW IF EXISTS public.document_analysis_audit_report SET (security_invoker = true)';
  END IF;
END $$;

-- Atualizar cron diário com URL/ANON reais
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
