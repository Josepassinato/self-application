-- Corrigir funções sem search_path configurado para segurança
-- Usar CREATE OR REPLACE para evitar problemas com dependências

-- 1. Corrigir update_conversation_last_message
CREATE OR REPLACE FUNCTION public.update_conversation_last_message()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  UPDATE public.chat_conversations 
  SET last_message_at = NEW.created_at
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$function$;

-- 2. Corrigir apply_checklist_template
CREATE OR REPLACE FUNCTION public.apply_checklist_template()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  -- Aplicar template de checklist baseado no tipo de visto
  INSERT INTO public.case_checklists (case_id, template_id, checklist_data)
  SELECT 
    NEW.id,
    ct.id,
    ct.checklist_items
  FROM public.checklist_templates ct
  WHERE ct.is_active = true
    AND NEW.tipo_visto = ANY(ct.visa_types)
    AND ct.law_firm_id IN (
      SELECT pu.law_firm_id 
      FROM public.platform_users pu 
      JOIN public.clients c ON c.responsavel_id = pu.auth_user_id
      WHERE c.id = NEW.client_id
    )
  LIMIT 1;
  
  RETURN NEW;
END;
$function$;

-- 3. Corrigir update_updated_at_column
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

-- 4. Corrigir update_checklist_completion
CREATE OR REPLACE FUNCTION public.update_checklist_completion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  total_items INTEGER;
  completed_items INTEGER;
  completion_pct INTEGER;
BEGIN
  -- Contar total de itens no checklist
  SELECT jsonb_array_length(NEW.checklist_data) INTO total_items;
  
  -- Contar itens completados
  SELECT COUNT(*)::INTEGER INTO completed_items
  FROM jsonb_array_elements(NEW.checklist_data) AS item
  WHERE (item->>'completed')::boolean = true;
  
  -- Calcular porcentagem
  IF total_items > 0 THEN
    completion_pct := ROUND((completed_items::DECIMAL / total_items::DECIMAL) * 100);
  ELSE
    completion_pct := 0;
  END IF;
  
  NEW.completion_percentage := completion_pct;
  
  RETURN NEW;
END;
$function$;