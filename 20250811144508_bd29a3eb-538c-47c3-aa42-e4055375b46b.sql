-- Setup cron jobs for priority calculation and alerts
SELECT cron.schedule(
  'calculate-case-priorities',
  '0 * * * *', -- Every hour
  $$
  SELECT net.http_post(
    url := 'https://apoeceltgnvohsbxfopb.supabase.co/functions/v1/calculate-priorities',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFwb2VjZWx0Z252b2hzYnhmb3BiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzNDA2MDQsImV4cCI6MjA2NzkxNjYwNH0.IzKP2-n-EGVkfZ-wXQdAmtK36nryqZc8RFEY0qZL6qM"}'::jsonb,
    body := '{"timestamp": "' || now() || '"}'::jsonb
  );
  $$
);

SELECT cron.schedule(
  'send-priority-alerts',
  '*/30 * * * *', -- Every 30 minutes
  $$
  SELECT net.http_post(
    url := 'https://apoeceltgnvohsbxfopb.supabase.co/functions/v1/priority-alerts',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFwb2VjZWx0Z252b2hzYnhmb3BiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzNDA2MDQsImV4cCI6MjA2NzkxNjYwNH0.IzKP2-n-EGVkfZ-wXQdAmtK36nryqZc8RFEY0qZL6qM"}'::jsonb,
    body := '{"timestamp": "' || now() || '"}'::jsonb
  );
  $$
);