-- Setup cron jobs for analytics
SELECT cron.schedule(
  'calculate-daily-analytics',
  '0 1 * * *', -- Daily at 1 AM
  $$
  SELECT net.http_post(
    url := 'https://apoeceltgnvohsbxfopb.supabase.co/functions/v1/calculate-analytics',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFwb2VjZWx0Z252b2hzYnhmb3BiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzNDA2MDQsImV4cCI6MjA2NzkxNjYwNH0.IzKP2-n-EGVkfZ-wXQdAmtK36nryqZc8RFEY0qZL6qM"}'::jsonb,
    body := '{"timestamp": "' || now() || '"}'::jsonb
  );
  $$
);

SELECT cron.schedule(
  'send-analytics-alerts',
  '0 8 * * 1', -- Weekly on Monday at 8 AM
  $$
  SELECT net.http_post(
    url := 'https://apoeceltgnvohsbxfopb.supabase.co/functions/v1/analytics-alerts',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFwb2VjZWx0Z252b2hzYnhmb3BiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzNDA2MDQsImV4cCI6MjA2NzkxNjYwNH0.IzKP2-n-EGVkfZ-wXQdAmtK36nryqZc8RFEY0qZL6qM"}'::jsonb,
    body := '{"timestamp": "' || now() || '"}'::jsonb
  );
  $$
);