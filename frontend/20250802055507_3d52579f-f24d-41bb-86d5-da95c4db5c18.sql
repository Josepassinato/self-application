-- Primeiro, vamos criar as contas de teste se não existirem
-- Inserir usuário admin@test.com na tabela auth.users se não existir
INSERT INTO auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token,
  instance_id,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  last_sign_in_at
) VALUES (
  '550e8400-e29b-41d4-a716-446655440003'::uuid,
  'authenticated',
  'authenticated',
  'admin@test.com',
  crypt('admin123', gen_salt('bf')),
  now(),
  now(),
  now(),
  '',
  '',
  '',
  '',
  '00000000-0000-0000-0000-000000000000',
  '{"provider": "email", "providers": ["email"]}',
  '{"first_name": "Admin", "last_name": "Test"}',
  false,
  now()
) ON CONFLICT (email) DO NOTHING;

-- Inserir usuário office@test.com na tabela auth.users se não existir
INSERT INTO auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token,
  instance_id,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  last_sign_in_at
) VALUES (
  '550e8400-e29b-41d4-a716-446655440004'::uuid,
  'authenticated',
  'authenticated',
  'office@test.com',
  crypt('office123', gen_salt('bf')),
  now(),
  now(),
  now(),
  '',
  '',
  '',
  '',
  '00000000-0000-0000-0000-000000000000',
  '{"provider": "email", "providers": ["email"]}',
  '{"first_name": "Office", "last_name": "User"}',
  false,
  now()
) ON CONFLICT (email) DO NOTHING;

-- Criar usuários na tabela platform_users para admin@test.com
INSERT INTO public.platform_users (
  auth_user_id,
  law_firm_id,
  email,
  first_name,
  last_name,
  role
) VALUES (
  '550e8400-e29b-41d4-a716-446655440003'::uuid,
  '550e8400-e29b-41d4-a716-446655440001'::uuid, -- Usar o firm padrão
  'admin@test.com',
  'Admin',
  'Test',
  'admin'
) ON CONFLICT (auth_user_id) DO UPDATE SET
  email = EXCLUDED.email,
  first_name = EXCLUDED.first_name,
  last_name = EXCLUDED.last_name,
  role = EXCLUDED.role;

-- Criar usuários na tabela platform_users para office@test.com  
INSERT INTO public.platform_users (
  auth_user_id,
  law_firm_id,
  email,
  first_name,
  last_name,
  role
) VALUES (
  '550e8400-e29b-41d4-a716-446655440004'::uuid,
  '550e8400-e29b-41d4-a716-446655440001'::uuid, -- Usar o firm padrão
  'office@test.com',
  'Office',
  'User',
  'user'
) ON CONFLICT (auth_user_id) DO UPDATE SET
  email = EXCLUDED.email,
  first_name = EXCLUDED.first_name,
  last_name = EXCLUDED.last_name,
  role = EXCLUDED.role;

-- Corrigir política RLS para permitir criação de clientes
-- Primeiro, dropar a política existente problemática
DROP POLICY IF EXISTS "Lawyers can manage all clients in their firm" ON public.clients;

-- Criar nova política mais permissiva para criação de clientes
CREATE POLICY "Users can manage clients in their firm" 
ON public.clients 
FOR ALL 
USING (
  -- Permitir visualização se for cliente próprio ou da mesma firma
  client_user_id = auth.uid() OR
  EXISTS (
    SELECT 1 
    FROM platform_users pu 
    WHERE pu.auth_user_id = auth.uid() 
    AND (
      -- Se o responsável existe, verificar se é da mesma firma
      (responsavel_id IS NOT NULL AND pu.law_firm_id IN (
        SELECT resp.law_firm_id 
        FROM platform_users resp 
        WHERE resp.auth_user_id = responsavel_id
      )) OR
      -- Se não há responsável, permitir para qualquer usuário autenticado da firma
      responsavel_id IS NULL
    )
  )
)
WITH CHECK (
  -- Para inserção/atualização, permitir se o usuário autenticado pode ser responsável
  client_user_id = auth.uid() OR
  EXISTS (
    SELECT 1 
    FROM platform_users pu 
    WHERE pu.auth_user_id = auth.uid()
  )
);

-- Corrigir política para casos também
DROP POLICY IF EXISTS "Lawyers can manage cases in their firm" ON public.cases;

CREATE POLICY "Users can manage cases in their firm" 
ON public.cases 
FOR ALL 
USING (
  EXISTS (
    SELECT 1 
    FROM clients c
    JOIN platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE c.id = cases.client_id
    AND (
      c.client_user_id = auth.uid() OR
      pu.law_firm_id IN (
        SELECT resp.law_firm_id 
        FROM platform_users resp 
        WHERE resp.auth_user_id = c.responsavel_id
      )
    )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 
    FROM clients c
    JOIN platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE c.id = cases.client_id
  )
);

-- Corrigir política para documentos de caso
DROP POLICY IF EXISTS "Users can manage documents for their cases" ON public.case_documents;

CREATE POLICY "Users can manage case documents" 
ON public.case_documents 
FOR ALL 
USING (
  EXISTS (
    SELECT 1 
    FROM cases ca
    JOIN clients c ON c.id = ca.client_id
    JOIN platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE ca.id = case_documents.case_id
    AND (
      c.client_user_id = auth.uid() OR
      pu.law_firm_id IN (
        SELECT resp.law_firm_id 
        FROM platform_users resp 
        WHERE resp.auth_user_id = c.responsavel_id
      )
    )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 
    FROM cases ca
    JOIN clients c ON c.id = ca.client_id
    JOIN platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE ca.id = case_documents.case_id
  )
);