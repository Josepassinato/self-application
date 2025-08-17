-- Create platform_user for existing auth users who don't have one
INSERT INTO public.platform_users (
  auth_user_id,
  law_firm_id,
  email,
  first_name,
  last_name,
  role
)
SELECT 
  au.id,
  '550e8400-e29b-41d4-a716-446655440001'::uuid,
  au.email,
  COALESCE(au.raw_user_meta_data ->> 'first_name', 'Usuário'),
  COALESCE(au.raw_user_meta_data ->> 'last_name', ''),
  'admin'
FROM auth.users au
LEFT JOIN public.platform_users pu ON pu.auth_user_id = au.id
WHERE pu.auth_user_id IS NULL
ON CONFLICT (auth_user_id) DO NOTHING;