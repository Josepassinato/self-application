-- SQL para configurar cron job que roda à meia-noite (horário UTC)
-- Habilitar extensões necessárias
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Agendar job de monitoramento noturno (2:00 AM UTC = 11:00 PM EST)
SELECT cron.schedule(
  'uscis-nightly-monitor',
  '0 2 * * *', -- Todo dia às 2:00 AM UTC
  $$
  SELECT
    net.http_post(
        url:='https://apoeceltgnvohsbxfopb.supabase.co/functions/v1/uscis-monitor',
        headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFwb2VjZWx0Z252b2hzYnhmb3BiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzNDA2MDQsImV4cCI6MjA2NzkxNjYwNH0.IzKP2-n-EGVkfZ-wXQdAmtK36nryqZc8RFEY0qZL6qM"}'::jsonb,
        body:=concat('{"trigger": "cron", "time": "', now(), '"}')::jsonb
    ) as request_id;
  $$
);