-- Create activity log table for case assignments (if not exists)
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

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view activity log for their firm cases" ON public.case_activity_log;
DROP POLICY IF EXISTS "Users can create activity log for their firm cases" ON public.case_activity_log;

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

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS update_priority_ranks_trigger ON public.case_priority;

CREATE TRIGGER update_priority_ranks_trigger
  AFTER INSERT OR UPDATE OR DELETE ON public.case_priority
  FOR EACH STATEMENT
  EXECUTE FUNCTION public.trigger_update_priority_ranks();