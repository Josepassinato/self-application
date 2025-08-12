-- Create client invitations table for secure client portal access
CREATE TABLE IF NOT EXISTS public.client_invitations (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  invitation_token UUID NOT NULL DEFAULT gen_random_uuid(),
  invited_by UUID REFERENCES public.platform_users(auth_user_id),
  invited_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (now() + interval '7 days'),
  accepted_at TIMESTAMP WITH TIME ZONE,
  auth_user_id UUID REFERENCES auth.users(id),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired', 'revoked')),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(client_id, email)
);

-- Add client_user_id to link clients with authenticated users
ALTER TABLE public.clients 
ADD COLUMN IF NOT EXISTS client_user_id UUID REFERENCES auth.users(id);

-- Update RLS policies for clients table
DROP POLICY IF EXISTS "Allow all operations on clients" ON public.clients;

CREATE POLICY "Lawyers can manage all clients in their firm" 
ON public.clients 
FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM public.platform_users pu
    WHERE pu.auth_user_id = auth.uid()
    AND pu.law_firm_id IN (
      SELECT responsavel.law_firm_id FROM public.platform_users responsavel
      WHERE responsavel.auth_user_id = clients.responsavel_id
    )
  )
);

CREATE POLICY "Clients can view their own data" 
ON public.clients 
FOR SELECT 
USING (client_user_id = auth.uid());

-- Update RLS policies for cases
DROP POLICY IF EXISTS "Allow all operations on cases" ON public.cases;

CREATE POLICY "Lawyers can manage cases in their firm" 
ON public.cases 
FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM public.platform_users pu
    JOIN public.clients c ON c.id = cases.client_id
    WHERE pu.auth_user_id = auth.uid()
    AND pu.law_firm_id IN (
      SELECT responsavel.law_firm_id FROM public.platform_users responsavel
      WHERE responsavel.auth_user_id = c.responsavel_id
    )
  )
);

CREATE POLICY "Clients can view their own cases" 
ON public.cases 
FOR SELECT 
USING (
  client_id IN (
    SELECT id FROM public.clients WHERE client_user_id = auth.uid()
  )
);

-- Update RLS policies for case_documents
DROP POLICY IF EXISTS "Allow all operations on case_documents" ON public.case_documents;

CREATE POLICY "Lawyers can manage documents in their firm" 
ON public.case_documents 
FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE c.id = case_documents.case_id
    AND pu.law_firm_id IN (
      SELECT responsavel.law_firm_id FROM public.platform_users responsavel
      WHERE responsavel.auth_user_id = cl.responsavel_id
    )
  )
);

CREATE POLICY "Clients can view documents from their cases" 
ON public.case_documents 
FOR SELECT 
USING (
  case_id IN (
    SELECT c.id FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    WHERE cl.client_user_id = auth.uid()
  )
);

CREATE POLICY "Clients can update signature status on their documents" 
ON public.case_documents 
FOR UPDATE 
USING (
  case_id IN (
    SELECT c.id FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    WHERE cl.client_user_id = auth.uid()
  )
) 
WITH CHECK (
  case_id IN (
    SELECT c.id FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    WHERE cl.client_user_id = auth.uid()
  )
);

-- Update RLS policies for case_activities
DROP POLICY IF EXISTS "Allow all operations on case_activities" ON public.case_activities;

CREATE POLICY "Lawyers can manage activities in their firm" 
ON public.case_activities 
FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE c.id = case_activities.case_id
    AND pu.law_firm_id IN (
      SELECT responsavel.law_firm_id FROM public.platform_users responsavel
      WHERE responsavel.auth_user_id = cl.responsavel_id
    )
  )
);

CREATE POLICY "Clients can view activities from their cases" 
ON public.case_activities 
FOR SELECT 
USING (
  case_id IN (
    SELECT c.id FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    WHERE cl.client_user_id = auth.uid()
  )
);

-- Enable RLS on client_invitations
ALTER TABLE public.client_invitations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lawyers can manage invitations for their firm clients" 
ON public.client_invitations 
FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM public.clients c
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE c.id = client_invitations.client_id
    AND pu.law_firm_id IN (
      SELECT responsavel.law_firm_id FROM public.platform_users responsavel
      WHERE responsavel.auth_user_id = c.responsavel_id
    )
  )
);

-- Create function to handle client invitation acceptance
CREATE OR REPLACE FUNCTION public.accept_client_invitation(invitation_token UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  invitation_record RECORD;
  result JSON;
BEGIN
  -- Get invitation details
  SELECT * INTO invitation_record
  FROM public.client_invitations
  WHERE invitation_token = accept_client_invitation.invitation_token
  AND status = 'pending'
  AND expires_at > now();
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Invalid or expired invitation');
  END IF;
  
  -- Update client with auth user id
  UPDATE public.clients
  SET client_user_id = auth.uid()
  WHERE id = invitation_record.client_id;
  
  -- Mark invitation as accepted
  UPDATE public.client_invitations
  SET 
    status = 'accepted',
    accepted_at = now(),
    auth_user_id = auth.uid()
  WHERE id = invitation_record.id;
  
  RETURN json_build_object(
    'success', true, 
    'client_id', invitation_record.client_id,
    'message', 'Invitation accepted successfully'
  );
END;
$$;