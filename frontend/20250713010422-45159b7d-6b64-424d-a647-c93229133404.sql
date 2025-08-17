-- Drop all existing policies on platform_users to start fresh
DROP POLICY IF EXISTS "Users can view their own profile" ON platform_users;
DROP POLICY IF EXISTS "Users can update their own profile" ON platform_users;
DROP POLICY IF EXISTS "Users can view same firm users" ON platform_users;
DROP POLICY IF EXISTS "Admins can manage firm users" ON platform_users;

-- Create a security definer function to get user's law firm
CREATE OR REPLACE FUNCTION public.get_user_law_firm_id(user_id UUID)
RETURNS UUID AS $$
BEGIN
  RETURN (SELECT law_firm_id FROM public.platform_users WHERE auth_user_id = user_id LIMIT 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Create a security definer function to check if user is admin
CREATE OR REPLACE FUNCTION public.is_user_admin(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (SELECT role = 'admin' FROM public.platform_users WHERE auth_user_id = user_id LIMIT 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Create simple, non-recursive policies
CREATE POLICY "Users can view their own record"
ON platform_users FOR SELECT
USING (auth_user_id = auth.uid());

CREATE POLICY "Users can update their own record"
ON platform_users FOR UPDATE
USING (auth_user_id = auth.uid());

-- Allow viewing users from same firm using the security definer function
CREATE POLICY "Users can view same firm users"
ON platform_users FOR SELECT
USING (law_firm_id = public.get_user_law_firm_id(auth.uid()));

-- Allow admins to manage users
CREATE POLICY "Admins can manage users"
ON platform_users FOR ALL
USING (public.is_user_admin(auth.uid()) = true);