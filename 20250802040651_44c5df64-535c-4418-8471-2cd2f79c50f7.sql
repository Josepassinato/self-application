-- Adicionar configurações DocuSign por escritório na tabela integration_settings
-- Verificar se já existe configuração DocuSign e adicionar se necessário

INSERT INTO public.integration_settings (law_firm_id, provider, config, active)
SELECT 
  lf.id as law_firm_id,
  'docusign' as provider,
  jsonb_build_object(
    'base_url', 'https://demo.docusign.net/restapi',
    'integration_key', '',
    'user_id', '',
    'account_id', '',
    'private_key', ''
  ) as config,
  false as active
FROM public.law_firms lf
WHERE NOT EXISTS (
  SELECT 1 FROM public.integration_settings 
  WHERE law_firm_id = lf.id AND provider = 'docusign'
);

-- Adicionar índice para performance
CREATE INDEX IF NOT EXISTS idx_integration_settings_law_firm_provider 
ON public.integration_settings(law_firm_id, provider);