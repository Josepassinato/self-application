-- Completar o sistema de gerenciamento de usuários com tabelas que estavam faltando

-- Tabela de convites de usuários
CREATE TABLE IF NOT EXISTS public.user_invitations (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  role_id UUID, -- Será referência para custom_roles quando criada
  invitation_token UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  custom_message TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'cancelled', 'expired')),
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  accepted_at TIMESTAMP WITH TIME ZONE,
  accepted_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Tabela de módulos do sistema para permissões
CREATE TABLE IF NOT EXISTS public.system_modules (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  description TEXT,
  icon TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Tabela de permissões
CREATE TABLE IF NOT EXISTS public.permissions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  module_id UUID NOT NULL REFERENCES public.system_modules(id) ON DELETE CASCADE,
  action TEXT NOT NULL, -- read, write, delete, admin
  description TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(module_id, action)
);

-- Tabela de funções customizadas
CREATE TABLE IF NOT EXISTS public.custom_roles (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  color TEXT DEFAULT '#6366f1',
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(law_firm_id, name)
);

-- Tabela de relacionamento entre funções e permissões
CREATE TABLE IF NOT EXISTS public.role_permissions (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  role_id UUID NOT NULL REFERENCES public.custom_roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(role_id, permission_id)
);

-- Adicionar campo custom_role_id na tabela platform_users
ALTER TABLE public.platform_users 
ADD COLUMN IF NOT EXISTS custom_role_id UUID REFERENCES public.custom_roles(id);

-- Adicionar campos de auditoria
ALTER TABLE public.platform_users 
ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended'));

-- Atualizar referência na tabela user_invitations
ALTER TABLE public.user_invitations 
ADD CONSTRAINT fk_user_invitations_role_id 
FOREIGN KEY (role_id) REFERENCES public.custom_roles(id);

-- Inserir módulos básicos do sistema
INSERT INTO public.system_modules (name, display_name, description, icon, sort_order) VALUES
('cases', 'Gestão de Casos', 'Visualizar, criar e gerenciar casos jurídicos', 'briefcase', 1),
('clients', 'Gestão de Clientes', 'Visualizar, criar e gerenciar clientes', 'users', 2),
('documents', 'Gestão de Documentos', 'Visualizar, fazer upload e gerenciar documentos', 'file-text', 3),
('templates', 'Templates', 'Gerenciar templates de documentos e checklists', 'layout-template', 4),
('billing', 'Faturamento', 'Visualizar e gerenciar faturas e pagamentos', 'credit-card', 5),
('analytics', 'Relatórios e Analytics', 'Visualizar relatórios e métricas', 'bar-chart', 6),
('user_management', 'Gestão de Usuários', 'Gerenciar usuários, funções e permissões', 'user-cog', 7),
('settings', 'Configurações', 'Configurações gerais do sistema', 'settings', 8)
ON CONFLICT (name) DO NOTHING;

-- Inserir permissões básicas para cada módulo
INSERT INTO public.permissions (module_id, action, description) 
SELECT 
  sm.id,
  action,
  sm.display_name || ' - ' || 
  CASE 
    WHEN action = 'read' THEN 'Visualizar'
    WHEN action = 'write' THEN 'Criar e Editar'
    WHEN action = 'delete' THEN 'Excluir'
    WHEN action = 'admin' THEN 'Administração Completa'
  END
FROM public.system_modules sm
CROSS JOIN (VALUES ('read'), ('write'), ('delete'), ('admin')) AS actions(action)
WHERE sm.is_active = true
ON CONFLICT (module_id, action) DO NOTHING;

-- Triggers para atualizar updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_custom_roles_updated_at
  BEFORE UPDATE ON public.custom_roles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_user_invitations_updated_at
  BEFORE UPDATE ON public.user_invitations
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- RLS Policies
ALTER TABLE public.user_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_modules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.custom_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;

-- Políticas para user_invitations
CREATE POLICY "Users can view invitations from their law firm" 
ON public.user_invitations FOR SELECT 
USING (law_firm_id = (SELECT law_firm_id FROM public.platform_users WHERE auth_user_id = auth.uid()));

CREATE POLICY "Users can create invitations for their law firm" 
ON public.user_invitations FOR INSERT 
WITH CHECK (law_firm_id = (SELECT law_firm_id FROM public.platform_users WHERE auth_user_id = auth.uid()));

CREATE POLICY "Users can update invitations from their law firm" 
ON public.user_invitations FOR UPDATE 
USING (law_firm_id = (SELECT law_firm_id FROM public.platform_users WHERE auth_user_id = auth.uid()));

-- Políticas para system_modules (todos podem ver)
CREATE POLICY "All authenticated users can view system modules" 
ON public.system_modules FOR SELECT 
USING (auth.role() = 'authenticated' AND is_active = true);

-- Políticas para permissions (todos podem ver)
CREATE POLICY "All authenticated users can view permissions" 
ON public.permissions FOR SELECT 
USING (auth.role() = 'authenticated' AND is_active = true);

-- Políticas para custom_roles
CREATE POLICY "Users can view roles from their law firm" 
ON public.custom_roles FOR SELECT 
USING (law_firm_id = (SELECT law_firm_id FROM public.platform_users WHERE auth_user_id = auth.uid()));

CREATE POLICY "Users can create roles for their law firm" 
ON public.custom_roles FOR INSERT 
WITH CHECK (law_firm_id = (SELECT law_firm_id FROM public.platform_users WHERE auth_user_id = auth.uid()));

CREATE POLICY "Users can update roles from their law firm" 
ON public.custom_roles FOR UPDATE 
USING (law_firm_id = (SELECT law_firm_id FROM public.platform_users WHERE auth_user_id = auth.uid()));

-- Políticas para role_permissions
CREATE POLICY "Users can manage role permissions for their law firm roles" 
ON public.role_permissions FOR ALL 
USING (
  role_id IN (
    SELECT cr.id FROM public.custom_roles cr 
    WHERE cr.law_firm_id = (SELECT law_firm_id FROM public.platform_users WHERE auth_user_id = auth.uid())
  )
);