-- Create case priority table
CREATE TABLE IF NOT EXISTS public.case_priority (
  case_id UUID PRIMARY KEY REFERENCES public.cases(id) ON DELETE CASCADE,
  score NUMERIC NOT NULL CHECK (score >= 0 AND score <= 100),
  rank INTEGER,
  reasons JSONB NOT NULL DEFAULT '[]'::jsonb,
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.case_priority ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view case priorities for their firm" 
ON public.case_priority 
FOR SELECT 
USING (
  case_id IN (
    SELECT c.id 
    FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE pu.law_firm_id IN (
      SELECT resp.law_firm_id 
      FROM public.platform_users resp 
      WHERE resp.auth_user_id = cl.responsavel_id
    )
  )
);

CREATE POLICY "System can manage case priorities" 
ON public.case_priority 
FOR ALL 
USING (true)
WITH CHECK (true);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_case_priority_score ON public.case_priority(score DESC);
CREATE INDEX IF NOT EXISTS idx_case_priority_rank ON public.case_priority(rank);
CREATE INDEX IF NOT EXISTS idx_case_priority_last_updated ON public.case_priority(last_updated);

-- Create function to update rank based on score
CREATE OR REPLACE FUNCTION public.update_case_priority_ranks()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  WITH ranked_cases AS (
    SELECT 
      case_id,
      ROW_NUMBER() OVER (ORDER BY score DESC, last_updated DESC) as new_rank
    FROM public.case_priority
  )
  UPDATE public.case_priority cp
  SET rank = rc.new_rank
  FROM ranked_cases rc
  WHERE cp.case_id = rc.case_id;
END;
$$;

-- Create trigger to auto-update ranks when scores change
CREATE OR REPLACE FUNCTION public.trigger_update_priority_ranks()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  -- Update ranks for all cases when any score changes
  PERFORM public.update_case_priority_ranks();
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER update_priority_ranks_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.case_priority
  FOR EACH STATEMENT
  EXECUTE FUNCTION public.trigger_update_priority_ranks();

-- Create activity log table for case assignments
CREATE TABLE IF NOT EXISTS public.case_activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  activity_type TEXT NOT NULL,
  description TEXT NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS for activity log
ALTER TABLE public.case_activity_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view activity log for their firm cases" 
ON public.case_activity_log 
FOR SELECT 
USING (
  case_id IN (
    SELECT c.id 
    FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE pu.law_firm_id IN (
      SELECT resp.law_firm_id 
      FROM public.platform_users resp 
      WHERE resp.auth_user_id = cl.responsavel_id
    )
  )
);

CREATE POLICY "Users can create activity log for their firm cases" 
ON public.case_activity_log 
FOR INSERT 
WITH CHECK (
  case_id IN (
    SELECT c.id 
    FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE pu.law_firm_id IN (
      SELECT resp.law_firm_id 
      FROM public.platform_users resp 
      WHERE resp.auth_user_id = cl.responsavel_id
    )
  )
);

-- Add indexes for activity log
CREATE INDEX IF NOT EXISTS idx_case_activity_log_case_id ON public.case_activity_log(case_id);
CREATE INDEX IF NOT EXISTS idx_case_activity_log_created_at ON public.case_activity_log(created_at DESC);