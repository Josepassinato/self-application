-- Enable realtime for case management tables
ALTER TABLE public.cases REPLICA IDENTITY FULL;
ALTER TABLE public.case_activities REPLICA IDENTITY FULL;
ALTER TABLE public.case_documents REPLICA IDENTITY FULL;

-- Add cases to realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.cases;
ALTER PUBLICATION supabase_realtime ADD TABLE public.case_activities;
ALTER PUBLICATION supabase_realtime ADD TABLE public.case_documents;

-- Add missing indexes for better performance
CREATE INDEX IF NOT EXISTS idx_cases_status ON public.cases(status);
CREATE INDEX IF NOT EXISTS idx_cases_client_id ON public.cases(client_id);
CREATE INDEX IF NOT EXISTS idx_cases_responsavel_id ON public.cases(responsavel_id);
CREATE INDEX IF NOT EXISTS idx_case_activities_case_id ON public.case_activities(case_id);
CREATE INDEX IF NOT EXISTS idx_case_documents_case_id ON public.case_documents(case_id);

-- Add case priority enum for better data consistency
DO $$ BEGIN
    CREATE TYPE case_priority AS ENUM ('baixa', 'normal', 'alta', 'urgente');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Add case status enum
DO $$ BEGIN
    CREATE TYPE case_status AS ENUM ('inicial', 'em_andamento', 'aguardando_cliente', 'aguardando_documentos', 'em_revisao', 'concluido', 'cancelado');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;