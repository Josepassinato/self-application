-- Enable realtime for cases and documents tables
ALTER TABLE public.cases REPLICA IDENTITY FULL;
ALTER TABLE public.case_documents REPLICA IDENTITY FULL;
ALTER TABLE public.case_activities REPLICA IDENTITY FULL;
ALTER TABLE public.clients REPLICA IDENTITY FULL;

-- Add tables to realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.cases;
ALTER PUBLICATION supabase_realtime ADD TABLE public.case_documents;
ALTER PUBLICATION supabase_realtime ADD TABLE public.case_activities;
ALTER PUBLICATION supabase_realtime ADD TABLE public.clients;