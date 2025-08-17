-- Enable required extensions (idempotent)
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- Unschedule existing job if it already exists to avoid duplicates
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'daily-db-backup') THEN
    PERFORM cron.unschedule((SELECT jobid FROM cron.job WHERE jobname = 'daily-db-backup' LIMIT 1));
  END IF;
END$$;

-- Schedule the daily backup at 03:00 UTC
select cron.schedule(
  'daily-db-backup',
  '0 3 * * *',
  $$
  select
    net.http_post(
      url := 'https://PROJECT-REF.supabase.co/functions/v1/db-backup',
      headers := '{"Content-Type": "application/json", "Authorization": "Bearer ANON_KEY"}'::jsonb,
      body := jsonb_build_object('time', now(), 'source', 'pg_cron', 'schedule', 'daily-03:00-UTC')
    ) as request_id;
  $$
);
