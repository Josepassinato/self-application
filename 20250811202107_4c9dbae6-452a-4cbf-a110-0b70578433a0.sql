-- Criar tabela para API keys
CREATE TABLE IF NOT EXISTS public.api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  key_hash TEXT UNIQUE NOT NULL,
  scopes JSONB NOT NULL DEFAULT '["read", "write"]'::jsonb,
  rate_limit_per_minute INTEGER NOT NULL DEFAULT 60,
  last_used_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  name TEXT NOT NULL,
  description TEXT
);

-- Criar tabela para rate limiting
CREATE TABLE IF NOT EXISTS public.api_rate_limits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  api_key_id UUID NOT NULL,
  window_start TIMESTAMP WITH TIME ZONE NOT NULL,
  request_count INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(api_key_id, window_start)
);

-- Habilitar RLS
ALTER TABLE public.api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_rate_limits ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para api_keys
CREATE POLICY "Admins can manage API keys for their firm"
ON public.api_keys
FOR ALL
USING (
  law_firm_id IN (
    SELECT pu.law_firm_id
    FROM platform_users pu
    WHERE pu.auth_user_id = auth.uid()
      AND pu.role IN ('admin', 'saas_admin')
  )
);

-- Políticas RLS para api_rate_limits
CREATE POLICY "System can manage rate limits"
ON public.api_rate_limits
FOR ALL
USING (true);

-- Função para verificar rate limit
CREATE OR REPLACE FUNCTION public.check_api_rate_limit(
  p_api_key_id UUID,
  p_rate_limit INTEGER
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  current_window TIMESTAMP WITH TIME ZONE;
  current_count INTEGER;
BEGIN
  -- Calculate current minute window
  current_window := date_trunc('minute', NOW());
  
  -- Get current request count for this window
  SELECT request_count INTO current_count
  FROM api_rate_limits
  WHERE api_key_id = p_api_key_id
    AND window_start = current_window;
  
  -- If no record exists, create it
  IF current_count IS NULL THEN
    INSERT INTO api_rate_limits (api_key_id, window_start, request_count)
    VALUES (p_api_key_id, current_window, 1)
    ON CONFLICT (api_key_id, window_start) 
    DO UPDATE SET request_count = api_rate_limits.request_count + 1;
    RETURN TRUE;
  END IF;
  
  -- Check if under limit
  IF current_count < p_rate_limit THEN
    -- Increment counter
    UPDATE api_rate_limits 
    SET request_count = request_count + 1
    WHERE api_key_id = p_api_key_id
      AND window_start = current_window;
    RETURN TRUE;
  END IF;
  
  RETURN FALSE;
END;
$$;

-- Função para validar API key
CREATE OR REPLACE FUNCTION public.validate_api_key(
  p_api_key TEXT,
  p_required_scope TEXT DEFAULT 'read'
) RETURNS TABLE (
  api_key_id UUID,
  law_firm_id UUID,
  rate_limit INTEGER,
  is_valid BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
DECLARE
  key_record RECORD;
BEGIN
  -- Hash the provided key and find matching record
  SELECT ak.id, ak.law_firm_id, ak.rate_limit_per_minute, ak.scopes, ak.is_active, ak.expires_at
  INTO key_record
  FROM api_keys ak
  WHERE ak.key_hash = encode(digest(p_api_key, 'sha256'), 'hex')
    AND ak.is_active = true
    AND (ak.expires_at IS NULL OR ak.expires_at > NOW());
  
  -- Check if key exists and has required scope
  IF key_record.id IS NOT NULL AND (
    key_record.scopes ? p_required_scope OR 
    key_record.scopes ? 'admin'
  ) THEN
    -- Update last used timestamp
    UPDATE api_keys 
    SET last_used_at = NOW()
    WHERE id = key_record.id;
    
    RETURN QUERY SELECT 
      key_record.id,
      key_record.law_firm_id,
      key_record.rate_limit_per_minute,
      TRUE;
  ELSE
    RETURN QUERY SELECT 
      NULL::UUID,
      NULL::UUID,
      0,
      FALSE;
  END IF;
END;
$$;

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_api_keys_key_hash ON public.api_keys(key_hash);
CREATE INDEX IF NOT EXISTS idx_api_keys_law_firm ON public.api_keys(law_firm_id);
CREATE INDEX IF NOT EXISTS idx_api_rate_limits_key_window ON public.api_rate_limits(api_key_id, window_start);

-- Limpar rate limits antigos (função de limpeza)
CREATE OR REPLACE FUNCTION public.cleanup_old_rate_limits()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public'
AS $$
BEGIN
  DELETE FROM api_rate_limits 
  WHERE created_at < NOW() - INTERVAL '1 hour';
END;
$$;