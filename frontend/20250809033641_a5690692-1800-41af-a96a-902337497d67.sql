-- Reexecutar upsert dos formulários com escape de regex corrigido
WITH upserts AS (
  INSERT INTO public.immigration_forms (form_code, form_name, form_category, form_description, version, fields_schema, validation_rules, is_active)
  VALUES
    (
      'I-130', 'Petition for Alien Relative', 'USCIS', 'Petição para parente imediato/família', 1,
      '{
        "fields": [
          {"key":"Part1_LastName","label":"Family Name (Last Name)","type":"text","maxLength":40,"required":true},
          {"key":"Part1_FirstName","label":"Given Name (First Name)","type":"text","maxLength":40,"required":true},
          {"key":"Part1_MiddleName","label":"Middle Name","type":"text","maxLength":40},
          {"key":"Part1_DOB","label":"Date of Birth","type":"date","format":"MM/DD/YYYY","required":true},
          {"key":"Part1_A_Number","label":"A-Number","type":"text","mask":"A#########"}
        ],
        "repeatGroups": [
          {"group":"Children","min":0,"max":5,
            "fields":[
              {"key":"Child_LastName","type":"text","maxLength":40},
              {"key":"Child_FirstName","type":"text","maxLength":40},
              {"key":"Child_DOB","type":"date","format":"MM/DD/YYYY"}
            ]
          }
        ]
      }'::jsonb,
      '{
        "validators": {
          "Part1_LastName":{"required":true,"maxLength":40},
          "Part1_FirstName":{"required":true,"maxLength":40},
          "Part1_DOB":{"required":true,"pattern":"^\\d{2}/\\d{2}/\\d{4}$"}
        },
        "field_mappings": {
          "Part1_LastName":"applicant.last_name",
          "Part1_FirstName":"applicant.first_name",
          "Part1_MiddleName":"applicant.middle_name",
          "Part1_DOB":"applicant.date_of_birth",
          "Part1_A_Number":"applicant.a_number"
        },
        "dependents_mappings": [
          {"role":"child","repeatGroup":"Children",
            "fields":{
              "Child_LastName":"item.last_name",
              "Child_FirstName":"item.first_name",
              "Child_DOB":"item.date_of_birth"
            }
          }
        ]
      }'::jsonb,
      true
    ),
    (
      'I-485', 'Application to Register Permanent Residence or Adjust Status', 'USCIS', 'Ajuste de status para residente permanente', 1,
      '{"fields":[
        {"key":"Part1_LastName","type":"text","maxLength":40,"required":true},
        {"key":"Part1_FirstName","type":"text","maxLength":40,"required":true},
        {"key":"Part1_DOB","type":"date","format":"MM/DD/YYYY","required":true},
        {"key":"Part1_SSN","type":"text","mask":"###-##-####"}
      ]}'::jsonb,
      '{"validators":{
        "Part1_LastName":{"required":true,"maxLength":40},
        "Part1_FirstName":{"required":true,"maxLength":40},
        "Part1_DOB":{"required":true,"pattern":"^\\d{2}/\\d{2}/\\d{4}$"},
        "Part1_SSN":{"pattern":"^\\d{3}-\\d{2}-\\d{4}$"}
      },"field_mappings":{
        "Part1_LastName":"applicant.last_name",
        "Part1_FirstName":"applicant.first_name",
        "Part1_DOB":"applicant.date_of_birth",
        "Part1_SSN":"applicant.ssn"
      }}'::jsonb,
      true
    ),
    (
      'I-765', 'Application for Employment Authorization', 'USCIS', 'Autorização de trabalho (EAD)', 1,
      '{"fields":[
        {"key":"Name_Last","type":"text","maxLength":40,"required":true},
        {"key":"Name_First","type":"text","maxLength":40,"required":true},
        {"key":"DOB","type":"date","format":"MM/DD/YYYY","required":true}
      ]}'::jsonb,
      '{"validators":{
        "Name_Last":{"required":true,"maxLength":40},
        "Name_First":{"required":true,"maxLength":40},
        "DOB":{"required":true,"pattern":"^\\d{2}/\\d{2}/\\d{4}$"}
      },"field_mappings":{
        "Name_Last":"applicant.last_name",
        "Name_First":"applicant.first_name",
        "DOB":"applicant.date_of_birth"
      }}'::jsonb,
      true
    ),
    (
      'I-864', 'Affidavit of Support Under Section 213A of the INA', 'USCIS', 'Termo de suporte financeiro', 1,
      '{"fields":[
        {"key":"Sponsor_Last","type":"text","maxLength":40,"required":true},
        {"key":"Sponsor_First","type":"text","maxLength":40,"required":true},
        {"key":"Sponsor_SSN","type":"text","mask":"###-##-####"}
      ]}'::jsonb,
      '{"validators":{
        "Sponsor_Last":{"required":true,"maxLength":40},
        "Sponsor_First":{"required":true,"maxLength":40},
        "Sponsor_SSN":{"pattern":"^\\\\d{3}-\\\\d{2}-\\\\d{4}$"}
      },"field_mappings":{
        "Sponsor_Last":"sponsor.last_name",
        "Sponsor_First":"sponsor.first_name",
        "Sponsor_SSN":"sponsor.ssn"
      }}'::jsonb,
      true
    ),
    (
      'N-400', 'Application for Naturalization', 'USCIS', 'Naturalização', 1,
      '{"fields":[
        {"key":"LastName","type":"text","maxLength":40,"required":true},
        {"key":"FirstName","type":"text","maxLength":40,"required":true},
        {"key":"DOB","type":"date","format":"MM/DD/YYYY","required":true}
      ]}'::jsonb,
      '{"validators":{
        "LastName":{"required":true,"maxLength":40},
        "FirstName":{"required":true,"maxLength":40},
        "DOB":{"required":true,"pattern":"^\\d{2}/\\d{2}/\\d{4}$"}
      },"field_mappings":{
        "LastName":"applicant.last_name",
        "FirstName":"applicant.first_name",
        "DOB":"applicant.date_of_birth"
      }}'::jsonb,
      true
    )
  ON CONFLICT (form_code, version) DO UPDATE SET
    form_name = EXCLUDED.form_name,
    form_category = EXCLUDED.form_category,
    form_description = EXCLUDED.form_description,
    fields_schema = EXCLUDED.fields_schema,
    validation_rules = EXCLUDED.validation_rules,
    is_active = true,
    updated_at = now()
  RETURNING 1
)
SELECT count(*) FROM upserts;