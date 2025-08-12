-- Criar tabelas para Package Builder
CREATE TABLE IF NOT EXISTS public.package_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL,
  version TEXT NOT NULL,
  cover_letter_md TEXT NOT NULL,
  toc_md TEXT NOT NULL,
  checklist_json JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(code, version)
);

CREATE TABLE IF NOT EXISTS public.package_evidence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id UUID NOT NULL,
  exhibit_id TEXT NOT NULL,
  label TEXT NOT NULL,
  source_uri TEXT NOT NULL,
  page_count INTEGER,
  required BOOLEAN DEFAULT true,
  status TEXT DEFAULT 'included' CHECK (status IN ('included', 'missing', 'optional', 'excluded')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Habilitar RLS
ALTER TABLE public.package_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_evidence ENABLE ROW LEVEL SECURITY;

-- Políticas RLS  
CREATE POLICY "Anyone can view package templates" ON public.package_templates
FOR SELECT USING (true);

CREATE POLICY "System can manage package evidence" ON public.package_evidence
FOR ALL USING (true);

-- Inserir template padrão
INSERT INTO public.package_templates (code, version, cover_letter_md, toc_md, checklist_json) VALUES
('family-aos', 'v1', 
'# Cover Letter

**{{case.petitioner.first_name}} {{case.petitioner.last_name}}** (Petitioner)
**{{case.beneficiary.first_name}} {{case.beneficiary.last_name}}** (Beneficiary)

**Case:** {{case.id}}
{{#if case.receipt}}**Receipt Number:** {{case.receipt}}{{/if}}

## Forms Included

{{#each forms}}
- **{{code}}** ({{pages}} pages)
{{/each}}

## Supporting Evidence

{{#each evidence}}
{{#if required}}
- **{{exhibit_id}}:** {{label}} ({{pages}} pages)
{{/if}}
{{/each}}

**Total Pages:** {{stats.total_pages}}

Respectfully submitted,', 

'# Table of Contents

## Forms
{{#each forms}}
{{@index}}. **{{code}}** - {{description}} (Pages {{page_start}}-{{page_end}})
{{/each}}

## Supporting Evidence
{{#each evidence}}
{{#if included}}
**{{exhibit_id}}:** {{label}} (Pages {{page_start}}-{{page_end}})
{{/if}}
{{/each}}',

'{
  "i130_spouse": {
    "required": [
      {"type": "marriage_certificate", "label": "Marriage Certificate", "priority": 1},
      {"type": "petitioner_id", "label": "Petitioner Photo ID", "priority": 2},
      {"type": "beneficiary_id", "label": "Beneficiary Photo ID", "priority": 3}
    ],
    "recommended": [
      {"type": "joint_documents", "label": "Joint Financial Documents", "priority": 4},
      {"type": "photos", "label": "Relationship Photos", "priority": 5}
    ]
  },
  "i485_aos": {
    "required": [
      {"type": "medical_exam", "label": "Medical Examination (I-693)", "priority": 1},
      {"type": "birth_certificate", "label": "Birth Certificate", "priority": 2}
    ]
  }
}'
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_package_evidence_package_id ON public.package_evidence(package_id);
CREATE INDEX IF NOT EXISTS idx_package_templates_code ON public.package_templates(code);