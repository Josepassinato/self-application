-- Fix critical security functions by setting search_path
-- Update functions that don't have search_path set

-- Fix get_user_law_firm_id function
CREATE OR REPLACE FUNCTION get_user_law_firm_id(user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN (
    SELECT law_firm_id 
    FROM platform_users 
    WHERE auth_user_id = user_id
  );
END;
$$;

-- Fix is_user_admin function  
CREATE OR REPLACE FUNCTION is_user_admin(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM platform_users 
    WHERE auth_user_id = user_id AND role = 'admin'
  );
END;
$$;

-- Fix update_updated_at_column function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;