-- Create job processing system for AI agents
CREATE TABLE public.ai_jobs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  job_type TEXT NOT NULL,
  input_data JSONB NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  result JSONB,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create index for efficient querying
CREATE INDEX idx_ai_jobs_user_id_status ON public.ai_jobs(user_id, status);
CREATE INDEX idx_ai_jobs_created_at ON public.ai_jobs(created_at DESC);

-- Enable RLS
ALTER TABLE public.ai_jobs ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can view their own jobs" 
ON public.ai_jobs 
FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own jobs" 
ON public.ai_jobs 
FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "System can update jobs" 
ON public.ai_jobs 
FOR UPDATE 
USING (true);

-- Create function to update timestamps
CREATE OR REPLACE FUNCTION public.update_ai_jobs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic timestamp updates
CREATE TRIGGER update_ai_jobs_updated_at
BEFORE UPDATE ON public.ai_jobs
FOR EACH ROW
EXECUTE FUNCTION public.update_ai_jobs_updated_at();

-- Add realtime support
ALTER TABLE public.ai_jobs REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.ai_jobs;