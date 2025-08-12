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

-- Criar usuários de teste na tabela platform_users caso não existam
-- Para admin@test.com
INSERT INTO public.platform_users (
  auth_user_id,
  law_firm_id,
  email,
  first_name,
  last_name,
  role
) 
SELECT 
  (SELECT id FROM auth.users WHERE email = 'admin@test.com' LIMIT 1),
  '550e8400-e29b-41d4-a716-446655440001'::uuid,
  'admin@test.com',
  'Admin',
  'Test',
  'admin'
WHERE EXISTS (SELECT 1 FROM auth.users WHERE email = 'admin@test.com')
AND NOT EXISTS (
  SELECT 1 FROM public.platform_users pu 
  JOIN auth.users au ON au.id = pu.auth_user_id 
  WHERE au.email = 'admin@test.com'
);

-- Para office@test.com  
INSERT INTO public.platform_users (
  auth_user_id,
  law_firm_id,
  email,
  first_name,
  last_name,
  role
) 
SELECT 
  (SELECT id FROM auth.users WHERE email = 'office@test.com' LIMIT 1),
  '550e8400-e29b-41d4-a716-446655440001'::uuid,
  'office@test.com',
  'Office',
  'User',
  'user'
WHERE EXISTS (SELECT 1 FROM auth.users WHERE email = 'office@test.com')
AND NOT EXISTS (
  SELECT 1 FROM public.platform_users pu 
  JOIN auth.users au ON au.id = pu.auth_user_id 
  WHERE au.email = 'office@test.com'
);