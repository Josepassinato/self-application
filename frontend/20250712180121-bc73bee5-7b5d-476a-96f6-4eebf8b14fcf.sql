-- Create law firms table to store firm information
CREATE TABLE public.law_firms (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  subdomain TEXT UNIQUE, -- For multi-tenant access (e.g., firma1.app.com)
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create database connections table to store API credentials for each firm
CREATE TABLE public.database_connections (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  provider TEXT NOT NULL CHECK (provider IN ('supabase', 'postgresql', 'mysql', 'custom_api')),
  connection_config JSONB NOT NULL, -- Store encrypted connection details
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  
  UNIQUE(law_firm_id, provider) -- One connection per provider per firm
);

-- Create users table for platform authentication (different from client data)
CREATE TABLE public.platform_users (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  auth_user_id UUID NOT NULL UNIQUE, -- References auth.users
  law_firm_id UUID NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  first_name TEXT,
  last_name TEXT,
  role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user', 'viewer')),
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE public.law_firms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.database_connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_users ENABLE ROW LEVEL SECURITY;

-- RLS Policies for law_firms
CREATE POLICY "Users can view their own firm" 
ON public.law_firms 
FOR SELECT 
USING (
  id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

CREATE POLICY "Firm admins can update their firm" 
ON public.law_firms 
FOR UPDATE 
USING (
  id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid() AND role = 'admin'
  )
);

-- RLS Policies for database_connections
CREATE POLICY "Users can view their firm's connections" 
ON public.database_connections 
FOR SELECT 
USING (
  law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

CREATE POLICY "Admins can manage their firm's connections" 
ON public.database_connections 
FOR ALL 
USING (
  law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid() AND role = 'admin'
  )
);

-- RLS Policies for platform_users
CREATE POLICY "Users can view users from their firm" 
ON public.platform_users 
FOR SELECT 
USING (
  law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

CREATE POLICY "Users can update their own profile" 
ON public.platform_users 
FOR UPDATE 
USING (auth_user_id = auth.uid());

CREATE POLICY "Admins can manage users in their firm" 
ON public.platform_users 
FOR ALL 
USING (
  law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid() AND role = 'admin'
  )
);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add triggers for updated_at
CREATE TRIGGER update_law_firms_updated_at
  BEFORE UPDATE ON public.law_firms
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_database_connections_updated_at
  BEFORE UPDATE ON public.database_connections
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_platform_users_updated_at
  BEFORE UPDATE ON public.platform_users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Function to handle new user signup
CREATE OR REPLACE FUNCTION public.handle_new_platform_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.platform_users (
    auth_user_id,
    law_firm_id,
    email,
    first_name,
    last_name
  ) VALUES (
    NEW.id,
    -- For now, we'll need to handle firm assignment through the app
    -- This trigger just creates the user record
    '00000000-0000-0000-0000-000000000000'::uuid, -- Placeholder, will be updated by app
    NEW.email,
    NEW.raw_user_meta_data ->> 'first_name',
    NEW.raw_user_meta_data ->> 'last_name'
  );
  RETURN NEW;
END;
$$;

-- Create trigger for new users (commented out for now, will handle in app)
-- CREATE TRIGGER on_auth_user_created
--   AFTER INSERT ON auth.users
--   FOR EACH ROW EXECUTE FUNCTION public.handle_new_platform_user();