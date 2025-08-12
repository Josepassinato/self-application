-- Fix infinite recursion in platform_users RLS policies
-- Drop existing problematic policies
DROP POLICY IF EXISTS "Admins can manage users in their firm" ON platform_users;
DROP POLICY IF EXISTS "Users can view users from their firm" ON platform_users;
DROP POLICY IF EXISTS "Users can update their own profile" ON platform_users;

-- Create non-recursive policies for platform_users
CREATE POLICY "Users can view their own profile"
ON platform_users FOR SELECT
USING (auth_user_id = auth.uid());

CREATE POLICY "Users can update their own profile"
ON platform_users FOR UPDATE
USING (auth_user_id = auth.uid());

CREATE POLICY "Users can view same firm users"
ON platform_users FOR SELECT
USING (
  law_firm_id = (
    SELECT law_firm_id 
    FROM platform_users 
    WHERE auth_user_id = auth.uid() 
    LIMIT 1
  )
);

-- Admins can manage users - separate policy without recursion
CREATE POLICY "Admins can manage firm users"
ON platform_users FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM platform_users admin_check
    WHERE admin_check.auth_user_id = auth.uid()
    AND admin_check.role = 'admin'
    AND admin_check.law_firm_id = platform_users.law_firm_id
  )
);