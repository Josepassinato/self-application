-- Seed data para desenvolvimento - Law Firm
INSERT INTO public.law_firms (
  id,
  name, 
  email,
  status,
  data_retention_days,
  auto_cleanup_enabled
) VALUES (
  '550e8400-e29b-41d4-a716-446655440001'::uuid,
  'VisaFlow Law Firm',
  'admin@visaflow.com',
  'active',
  90,
  true
);

-- Seed data para desenvolvimento - Platform User (Admin)
INSERT INTO public.platform_users (
  id,
  auth_user_id,
  law_firm_id,
  email,
  first_name,
  last_name,
  role,
  is_active
) VALUES (
  '550e8400-e29b-41d4-a716-446655440002'::uuid,
  '550e8400-e29b-41d4-a716-446655440003'::uuid, -- Placeholder auth user id
  '550e8400-e29b-41d4-a716-446655440001'::uuid,
  'admin@visaflow.com',
  'Admin',
  'User',
  'admin',
  true
);

-- Seed data para desenvolvimento - Clientes de exemplo
INSERT INTO public.clients (
  id,
  nome,
  email,
  telefone,
  nacionalidade,
  status,
  origem,
  data_primeiro_contato,
  responsavel_id
) VALUES 
(
  '550e8400-e29b-41d4-a716-446655440010'::uuid,
  'João Silva',
  'joao.silva@email.com',
  '+55 11 99999-9999',
  'Brasileiro',
  'ativo',
  'website',
  now(),
  '550e8400-e29b-41d4-a716-446655440003'::uuid
),
(
  '550e8400-e29b-41d4-a716-446655440011'::uuid,
  'Maria Santos',
  'maria.santos@email.com',
  '+55 11 88888-8888',
  'Brasileira',
  'lead',
  'referência',
  now() - interval '5 days',
  '550e8400-e29b-41d4-a716-446655440003'::uuid
),
(
  '550e8400-e29b-41d4-a716-446655440012'::uuid,
  'Carlos Rodriguez',
  'carlos.rodriguez@email.com',
  '+34 600 123 456',
  'Espanhol',
  'concluido',
  'indicação',
  now() - interval '30 days',
  '550e8400-e29b-41d4-a716-446655440003'::uuid
);

-- Seed data para desenvolvimento - Casos de exemplo
INSERT INTO public.cases (
  id,
  client_id,
  titulo,
  descricao,
  tipo_visto,
  status,
  prioridade,
  data_inicio,
  data_estimada_conclusao,
  valor_estimado,
  responsavel_id
) VALUES 
(
  '550e8400-e29b-41d4-a716-446655440020'::uuid,
  '550e8400-e29b-41d4-a716-446655440010'::uuid,
  'Visto de Trabalho - João Silva',
  'Processo de visto de trabalho para desenvolvedor em Portugal',
  'D7',
  'em_andamento',
  'alta',
  now() - interval '10 days',
  now() + interval '60 days',
  5000.00,
  '550e8400-e29b-41d4-a716-446655440003'::uuid
),
(
  '550e8400-e29b-41d4-a716-446655440021'::uuid,
  '550e8400-e29b-41d4-a716-446655440011'::uuid,
  'Visto de Estudante - Maria Santos',
  'Processo de visto de estudante para mestrado em Lisboa',
  'D4',
  'inicial',
  'normal',
  now() - interval '3 days',
  now() + interval '90 days',
  3500.00,
  '550e8400-e29b-41d4-a716-446655440003'::uuid
),
(
  '550e8400-e29b-41d4-a716-446655440022'::uuid,
  '550e8400-e29b-41d4-a716-446655440012'::uuid,
  'Residência Permanente - Carlos Rodriguez',
  'Processo finalizado de residência permanente',
  'ARI',
  'concluido',
  'baixa',
  now() - interval '120 days',
  now() - interval '30 days',
  15000.00,
  '550e8400-e29b-41d4-a716-446655440003'::uuid
);

-- Seed data para desenvolvimento - Atividades de casos
INSERT INTO public.case_activities (
  id,
  case_id,
  titulo,
  descricao,
  tipo,
  created_by
) VALUES 
(
  '550e8400-e29b-41d4-a716-446655440030'::uuid,
  '550e8400-e29b-41d4-a716-446655440020'::uuid,
  'Documentação inicial coletada',
  'Passaporte, certidões e comprovantes financeiros recebidos',
  'documento',
  '550e8400-e29b-41d4-a716-446655440003'::uuid
),
(
  '550e8400-e29b-41d4-a716-446655440031'::uuid,
  '550e8400-e29b-41d4-a716-446655440020'::uuid,
  'Agendamento no consulado',
  'Entrevista agendada para próxima semana',
  'agendamento',
  '550e8400-e29b-41d4-a716-446655440003'::uuid
);

-- Seed data para desenvolvimento - Submissions do intake
INSERT INTO public.intake_submissions (
  id,
  nome,
  email,
  nacionalidade,
  tipo_usuario,
  idioma,
  telefone,
  tipo_visto,
  empresa,
  cargo,
  objetivo
) VALUES 
(
  '550e8400-e29b-41d4-a716-446655440040'::uuid,
  'Ana Costa',
  'ana.costa@email.com',
  'Portuguesa',
  'profissional',
  'pt',
  '+351 910 123 456',
  'D7',
  'Tech Solutions',
  'Desenvolvedora',
  'Trabalhar em startup portuguesa'
);

-- Seed data para desenvolvimento - Data retention settings
INSERT INTO public.data_retention_settings (
  id,
  law_firm_id,
  data_type,
  retention_days,
  auto_cleanup,
  notify_before_cleanup,
  notification_days
) VALUES 
(
  '550e8400-e29b-41d4-a716-446655440050'::uuid,
  '550e8400-e29b-41d4-a716-446655440001'::uuid,
  'clients',
  365,
  true,
  true,
  7
),
(
  '550e8400-e29b-41d4-a716-446655440051'::uuid,
  '550e8400-e29b-41d4-a716-446655440001'::uuid,
  'case_documents',
  1095,
  true,
  true,
  14
),
(
  '550e8400-e29b-41d4-a716-446655440052'::uuid,
  '550e8400-e29b-41d4-a716-446655440001'::uuid,
  'case_activities',
  730,
  true,
  true,
  7
);