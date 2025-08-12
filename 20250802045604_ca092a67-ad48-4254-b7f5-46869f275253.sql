-- Sistema de papéis customizáveis e permissões granulares

-- Tabela de módulos do sistema
CREATE TABLE IF NOT EXISTS public.system_modules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  display_name text NOT NULL,
  description text,
  icon text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Tabela de papéis customizáveis por tenant
CREATE TABLE IF NOT EXISTS public.custom_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id uuid NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  name text NOT NULL,
  display_name text NOT NULL,
  description text,
  is_system_role boolean DEFAULT false,
  created_by uuid REFERENCES auth.users(id),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(law_firm_id, name)
);

-- Tabela de permissões granulares
CREATE TABLE IF NOT EXISTS public.permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  module_id uuid NOT NULL REFERENCES public.system_modules(id) ON DELETE CASCADE,
  action text NOT NULL, -- 'read', 'write', 'delete', 'admin'
  description text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(module_id, action)
);

-- Tabela de relacionamento entre papéis e permissões
CREATE TABLE IF NOT EXISTS public.role_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id uuid NOT NULL REFERENCES public.custom_roles(id) ON DELETE CASCADE,
  permission_id uuid NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
  granted_by uuid REFERENCES auth.users(id),
  granted_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE(role_id, permission_id)
);

-- Atualizar tabela platform_users para usar custom_roles
ALTER TABLE public.platform_users 
ADD COLUMN IF NOT EXISTS custom_role_id uuid REFERENCES public.custom_roles(id);

-- Habilitar RLS
ALTER TABLE public.system_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

-- Políticas para system_modules (visível para todos)
CREATE POLICY "Anyone can view system modules" ON public.system_modules
FOR SELECT USING (true);

-- Políticas para custom_roles
CREATE POLICY "Users can view roles from their firm" ON public.custom_roles
FOR SELECT USING (
  law_firm_id IN (
    SELECT platform_users.law_firm_id
    FROM platform_users
    WHERE platform_users.auth_user_id = auth.uid()
  )
);

CREATE POLICY "Admins can manage roles in their firm" ON public.custom_roles
FOR ALL USING (
  law_firm_id IN (
    SELECT platform_users.law_firm_id
    FROM platform_users
    WHERE platform_users.auth_user_id = auth.uid()
    AND platform_users.role = 'admin'
  )
);

-- Políticas para permissions (visível para todos autenticados)
CREATE POLICY "Authenticated users can view permissions" ON public.permissions
FOR SELECT TO authenticated USING (true);

-- Políticas para role_permissions
CREATE POLICY "Users can view role permissions from their firm" ON public.role_permissions
FOR SELECT USING (
  role_id IN (
    SELECT cr.id
    FROM custom_roles cr
    JOIN platform_users pu ON pu.law_firm_id = cr.law_firm_id
    WHERE pu.auth_user_id = auth.uid()
  )
);

CREATE POLICY "Admins can manage role permissions in their firm" ON public.role_permissions
FOR ALL USING (
  role_id IN (
    SELECT cr.id
    FROM custom_roles cr
    JOIN platform_users pu ON pu.law_firm_id = cr.law_firm_id
    WHERE pu.auth_user_id = auth.uid()
    AND pu.role = 'admin'
  )
);

-- Inserir módulos do sistema
INSERT INTO public.system_modules (name, display_name, description, icon) VALUES
('dashboard', 'Dashboard', 'Painel principal com métricas e visão geral', 'layout-dashboard'),
('clients', 'Clientes', 'Gerenciamento de clientes e leads', 'users'),
('cases', 'Casos', 'Gestão de casos de imigração', 'briefcase'),
('documents', 'Documentos', 'Upload e gerenciamento de documentos', 'file-text'),
('templates', 'Templates', 'Templates de documentos e emails', 'file-template'),
('analytics', 'Analytics', 'Relatórios e análises de performance', 'bar-chart'),
('settings', 'Configurações', 'Configurações do sistema e escritório', 'settings'),
('billing', 'Faturamento', 'Gestão de faturas e pagamentos', 'credit-card'),
('ai_tools', 'Ferramentas IA', 'Assistentes de IA e análise de documentos', 'brain')
ON CONFLICT (name) DO NOTHING;

-- Inserir permissões para cada módulo
INSERT INTO public.permissions (module_id, action, description)
SELECT 
  sm.id,
  action,
  sm.display_name || ' - ' || 
  CASE action
    WHEN 'read' THEN 'Visualizar'
    WHEN 'write' THEN 'Criar e editar'
    WHEN 'delete' THEN 'Excluir'
    WHEN 'admin' THEN 'Administração completa'
  END
FROM public.system_modules sm
CROSS JOIN (VALUES ('read'), ('write'), ('delete'), ('admin')) AS actions(action)
ON CONFLICT (module_id, action) DO NOTHING;

-- Criar papéis padrão para cada escritório existente
INSERT INTO public.custom_roles (law_firm_id, name, display_name, description, is_system_role)
SELECT 
  lf.id,
  role_name,
  role_display,
  role_desc,
  true
FROM public.law_firms lf
CROSS JOIN (VALUES 
  ('admin', 'Administrador', 'Acesso completo a todos os módulos'),
  ('lawyer', 'Advogado', 'Acesso a casos, clientes e documentos'),
  ('assistant', 'Assistente', 'Acesso limitado para suporte'),
  ('viewer', 'Visualizador', 'Apenas visualização de dados')
) AS roles(role_name, role_display, role_desc)
ON CONFLICT (law_firm_id, name) DO NOTHING;

-- Conceder todas as permissões para o papel admin
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT cr.id, p.id
FROM public.custom_roles cr
CROSS JOIN public.permissions p
WHERE cr.name = 'admin'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Conceder permissões específicas para advogados
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT cr.id, p.id
FROM public.custom_roles cr
JOIN public.permissions p ON p.action IN ('read', 'write')
JOIN public.system_modules sm ON sm.id = p.module_id
WHERE cr.name = 'lawyer'
AND sm.name IN ('dashboard', 'clients', 'cases', 'documents', 'templates', 'ai_tools')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Conceder permissões de leitura para assistentes
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT cr.id, p.id
FROM public.custom_roles cr
JOIN public.permissions p ON p.action = 'read'
JOIN public.system_modules sm ON sm.id = p.module_id
WHERE cr.name = 'assistant'
AND sm.name IN ('dashboard', 'clients', 'cases', 'documents')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Conceder apenas leitura para visualizadores
INSERT INTO public.role_permissions (role_id, permission_id)
SELECT cr.id, p.id
FROM public.custom_roles cr
JOIN public.permissions p ON p.action = 'read'
JOIN public.system_modules sm ON sm.id = p.module_id
WHERE cr.name = 'viewer'
AND sm.name IN ('dashboard', 'clients', 'cases')
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Atualizar usuários admin existentes para usar o novo sistema de papéis
UPDATE public.platform_users 
SET custom_role_id = (
  SELECT cr.id 
  FROM custom_roles cr 
  WHERE cr.law_firm_id = platform_users.law_firm_id 
  AND cr.name = 'admin'
)
WHERE role = 'admin';

-- Atualizar usuários não-admin para usar papel de advogado
UPDATE public.platform_users 
SET custom_role_id = (
  SELECT cr.id 
  FROM custom_roles cr 
  WHERE cr.law_firm_id = platform_users.law_firm_id 
  AND cr.name = 'lawyer'
)
WHERE role != 'admin' AND custom_role_id IS NULL;

-- Triggers para updated_at
CREATE TRIGGER update_custom_roles_updated_at
  BEFORE UPDATE ON public.custom_roles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Função para verificar permissões do usuário
CREATE OR REPLACE FUNCTION public.user_has_permission(module_name text, required_action text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.platform_users pu
    JOIN public.custom_roles cr ON cr.id = pu.custom_role_id
    JOIN public.role_permissions rp ON rp.role_id = cr.id
    JOIN public.permissions p ON p.id = rp.permission_id
    JOIN public.system_modules sm ON sm.id = p.module_id
    WHERE pu.auth_user_id = auth.uid()
    AND sm.name = module_name
    AND (p.action = required_action OR p.action = 'admin')
  );
END;
$$;