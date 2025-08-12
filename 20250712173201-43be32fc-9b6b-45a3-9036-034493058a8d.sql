-- Create tables for AI agent interactions and document analysis

-- Table for AI agent chat interactions
CREATE TABLE public.ai_agent_interactions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  agent_id TEXT NOT NULL,
  user_message TEXT NOT NULL,
  agent_response TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Table for document analysis results
CREATE TABLE public.document_analyses (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  document_type TEXT NOT NULL,
  analysis_type TEXT NOT NULL DEFAULT 'general',
  analysis_result JSONB NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  case_id UUID REFERENCES public.cases(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Table for visa recommendations
CREATE TABLE public.visa_recommendations (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_profile JSONB NOT NULL,
  recommendation JSONB NOT NULL,
  additional_context TEXT,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  case_id UUID REFERENCES public.cases(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Table for API configurations and usage tracking
CREATE TABLE public.api_usage_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  api_name TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  request_data JSONB,
  response_data JSONB,
  status_code INTEGER,
  execution_time_ms INTEGER,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.ai_agent_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.document_analyses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visa_recommendations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_usage_logs ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for AI agent interactions
CREATE POLICY "Users can view their own AI interactions" 
ON public.ai_agent_interactions 
FOR SELECT 
USING (user_id = auth.uid());

CREATE POLICY "Users can create AI interactions" 
ON public.ai_agent_interactions 
FOR INSERT 
WITH CHECK (user_id = auth.uid());

-- Create RLS policies for document analyses
CREATE POLICY "Users can view their own document analyses" 
ON public.document_analyses 
FOR SELECT 
USING (user_id = auth.uid());

CREATE POLICY "Users can create document analyses" 
ON public.document_analyses 
FOR INSERT 
WITH CHECK (user_id = auth.uid());

-- Create RLS policies for visa recommendations
CREATE POLICY "Users can view their own visa recommendations" 
ON public.visa_recommendations 
FOR SELECT 
USING (user_id = auth.uid());

CREATE POLICY "Users can create visa recommendations" 
ON public.visa_recommendations 
FOR INSERT 
WITH CHECK (user_id = auth.uid());

-- Create RLS policies for API usage logs (admin access)
CREATE POLICY "Allow all operations on api_usage_logs" 
ON public.api_usage_logs 
FOR ALL 
USING (true) 
WITH CHECK (true);

-- Create indexes for better performance
CREATE INDEX idx_ai_agent_interactions_user_id ON public.ai_agent_interactions(user_id);
CREATE INDEX idx_ai_agent_interactions_agent_id ON public.ai_agent_interactions(agent_id);
CREATE INDEX idx_ai_agent_interactions_created_at ON public.ai_agent_interactions(created_at);

CREATE INDEX idx_document_analyses_user_id ON public.document_analyses(user_id);
CREATE INDEX idx_document_analyses_case_id ON public.document_analyses(case_id);
CREATE INDEX idx_document_analyses_document_type ON public.document_analyses(document_type);

CREATE INDEX idx_visa_recommendations_user_id ON public.visa_recommendations(user_id);
CREATE INDEX idx_visa_recommendations_case_id ON public.visa_recommendations(case_id);

CREATE INDEX idx_api_usage_logs_api_name ON public.api_usage_logs(api_name);
CREATE INDEX idx_api_usage_logs_created_at ON public.api_usage_logs(created_at);