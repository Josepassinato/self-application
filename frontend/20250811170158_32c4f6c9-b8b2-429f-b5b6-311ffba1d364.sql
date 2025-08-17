-- Criar tabela de logs de auditoria
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id UUID NOT NULL,
  actor_role TEXT NOT NULL CHECK (actor_role IN ('client', 'paralegal', 'admin', 'ai', 'system')),
  case_id UUID,
  action TEXT NOT NULL CHECK (action IN ('create', 'update', 'delete', 'submit', 'download', 'ai_suggestion', 'view', 'export', 'approve', 'reject')),
  entity_type TEXT NOT NULL CHECK (entity_type IN ('form', 'document', 'message', 'case', 'client', 'template', 'checklist')),
  entity_id UUID,
  metadata JSONB DEFAULT '{}'::jsonb,
  ip_address TEXT,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Índices para performance
CREATE INDEX idx_audit_logs_actor_id ON audit_logs(actor_id);
CREATE INDEX idx_audit_logs_case_id ON audit_logs(case_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_entity_type ON audit_logs(entity_type);

-- Habilitar RLS
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Política para admins visualizarem todos os logs
CREATE POLICY "Admins can view all audit logs" 
ON audit_logs 
FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM platform_users 
    WHERE auth_user_id = auth.uid() 
    AND role IN ('admin', 'saas_admin')
  )
);

-- Política para usuários visualizarem logs relacionados aos seus casos/firma
CREATE POLICY "Users can view audit logs for their firm cases" 
ON audit_logs 
FOR SELECT 
USING (
  case_id IN (
    SELECT c.id 
    FROM cases c
    JOIN clients cl ON cl.id = c.client_id
    WHERE cl.client_user_id = auth.uid() 
    OR EXISTS (
      SELECT 1 FROM platform_users pu 
      WHERE pu.auth_user_id = auth.uid() 
      AND pu.law_firm_id IN (
        SELECT resp.law_firm_id 
        FROM platform_users resp 
        WHERE resp.auth_user_id = cl.responsavel_id
      )
    )
  )
);

-- Política para sistema inserir logs
CREATE POLICY "System can insert audit logs" 
ON audit_logs 
FOR INSERT 
WITH CHECK (true);

-- Função para registrar logs de auditoria
CREATE OR REPLACE FUNCTION log_audit_action(
  p_actor_id UUID,
  p_actor_role TEXT,
  p_action TEXT,
  p_entity_type TEXT,
  p_case_id UUID DEFAULT NULL,
  p_entity_id UUID DEFAULT NULL,
  p_metadata JSONB DEFAULT NULL,
  p_ip_address TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  log_id UUID;
BEGIN
  INSERT INTO public.audit_logs (
    actor_id,
    actor_role,
    case_id,
    action,
    entity_type,
    entity_id,
    metadata,
    ip_address,
    user_agent
  ) VALUES (
    p_actor_id,
    p_actor_role,
    p_case_id,
    p_action,
    p_entity_type,
    p_entity_id,
    COALESCE(p_metadata, '{}'::jsonb),
    p_ip_address,
    p_user_agent
  ) RETURNING id INTO log_id;
  
  RETURN log_id;
END;
$$;

-- Tabela para configurações de compliance
CREATE TABLE IF NOT EXISTS compliance_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  retention_days INTEGER DEFAULT 1825, -- 5 anos
  alert_unusual_downloads BOOLEAN DEFAULT true,
  alert_after_hours_access BOOLEAN DEFAULT true,
  alert_suspicious_ips BOOLEAN DEFAULT true,
  max_downloads_per_hour INTEGER DEFAULT 50,
  business_hours_start TIME DEFAULT '08:00:00',
  business_hours_end TIME DEFAULT '18:00:00',
  trusted_ip_ranges TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Índices para compliance_settings
CREATE INDEX idx_compliance_settings_law_firm_id ON compliance_settings(law_firm_id);

-- RLS para compliance_settings
ALTER TABLE compliance_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage compliance settings for their firm" 
ON compliance_settings 
FOR ALL 
USING (
  law_firm_id IN (
    SELECT law_firm_id 
    FROM platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

-- Trigger para atualizar updated_at
CREATE OR REPLACE FUNCTION update_compliance_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_compliance_settings_updated_at
  BEFORE UPDATE ON compliance_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_compliance_settings_updated_at();

-- Tabela para alertas de compliance
CREATE TABLE IF NOT EXISTS compliance_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  alert_type TEXT NOT NULL CHECK (alert_type IN ('unusual_downloads', 'after_hours_access', 'suspicious_ip', 'bulk_export', 'failed_login_attempts')),
  severity TEXT NOT NULL DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  description TEXT NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  resolved BOOLEAN DEFAULT false,
  resolved_by UUID,
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Índices para compliance_alerts
CREATE INDEX idx_compliance_alerts_law_firm_id ON compliance_alerts(law_firm_id);
CREATE INDEX idx_compliance_alerts_created_at ON compliance_alerts(created_at);
CREATE INDEX idx_compliance_alerts_resolved ON compliance_alerts(resolved);

-- RLS para compliance_alerts
ALTER TABLE compliance_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view compliance alerts for their firm" 
ON compliance_alerts 
FOR SELECT 
USING (
  law_firm_id IN (
    SELECT law_firm_id 
    FROM platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

CREATE POLICY "Admins can manage compliance alerts for their firm" 
ON compliance_alerts 
FOR ALL 
USING (
  law_firm_id IN (
    SELECT law_firm_id 
    FROM platform_users 
    WHERE auth_user_id = auth.uid() 
    AND role IN ('admin', 'saas_admin')
  )
);

-- Função para detectar e criar alertas de compliance
CREATE OR REPLACE FUNCTION check_compliance_alerts()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  firm_record RECORD;
  download_count INTEGER;
  after_hours_count INTEGER;
BEGIN
  -- Verificar para cada firma
  FOR firm_record IN 
    SELECT DISTINCT cs.law_firm_id, cs.max_downloads_per_hour, cs.business_hours_start, cs.business_hours_end, cs.trusted_ip_ranges
    FROM public.compliance_settings cs
    WHERE cs.alert_unusual_downloads = true 
    OR cs.alert_after_hours_access = true 
    OR cs.alert_suspicious_ips = true
  LOOP
    -- Verificar downloads incomuns (última hora)
    SELECT COUNT(*) INTO download_count
    FROM public.audit_logs al
    JOIN public.cases c ON c.id = al.case_id
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = cl.responsavel_id
    WHERE pu.law_firm_id = firm_record.law_firm_id
    AND al.action = 'download'
    AND al.created_at > now() - INTERVAL '1 hour';
    
    IF download_count > firm_record.max_downloads_per_hour THEN
      INSERT INTO public.compliance_alerts (law_firm_id, alert_type, severity, description, metadata)
      VALUES (
        firm_record.law_firm_id,
        'unusual_downloads',
        'high',
        format('Detectados %s downloads na última hora (limite: %s)', download_count, firm_record.max_downloads_per_hour),
        jsonb_build_object('download_count', download_count, 'time_window', '1 hour')
      );
    END IF;
    
    -- Verificar acessos fora do expediente (último dia)
    SELECT COUNT(*) INTO after_hours_count
    FROM public.audit_logs al
    JOIN public.cases c ON c.id = al.case_id
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = cl.responsavel_id
    WHERE pu.law_firm_id = firm_record.law_firm_id
    AND al.created_at > now() - INTERVAL '1 day'
    AND (
      EXTRACT(hour FROM al.created_at) < EXTRACT(hour FROM firm_record.business_hours_start)
      OR EXTRACT(hour FROM al.created_at) > EXTRACT(hour FROM firm_record.business_hours_end)
      OR EXTRACT(dow FROM al.created_at) IN (0, 6) -- Weekend
    );
    
    IF after_hours_count > 10 THEN -- Threshold arbitrário
      INSERT INTO public.compliance_alerts (law_firm_id, alert_type, severity, description, metadata)
      VALUES (
        firm_record.law_firm_id,
        'after_hours_access',
        'medium',
        format('Detectados %s acessos fora do expediente nas últimas 24 horas', after_hours_count),
        jsonb_build_object('access_count', after_hours_count, 'time_window', '24 hours')
      );
    END IF;
  END LOOP;
END;
$$;