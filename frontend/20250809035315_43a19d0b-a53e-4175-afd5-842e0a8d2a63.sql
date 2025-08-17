-- Ensure unique version per form and single active version per form_code
BEGIN;

-- 1) Indexes and constraints
CREATE UNIQUE INDEX IF NOT EXISTS idx_immigration_forms_code_version
  ON public.immigration_forms(form_code, version);

CREATE UNIQUE INDEX IF NOT EXISTS idx_immigration_forms_one_active_per_form
  ON public.immigration_forms(form_code)
  WHERE is_active = true;

-- Helper: Upsert a form version 1 as active, disabling any current active
-- We do this per form_code to avoid partial unique index violations

-- I-130 --------------------------------------------------------------------
UPDATE public.immigration_forms SET is_active = false WHERE form_code = 'I-130';
INSERT INTO public.immigration_forms (
  form_code, form_name, form_category, form_description,
  version, is_active, fields_schema, validation_rules
) VALUES (
  'I-130', 'Petition for Alien Relative', 'family', 'Family-based immigrant petition',
  1, true,
  '{
    "sections": [
      {
        "id": "petitioner_info",
        "title": "Petitioner Information",
        "fields": [
          {"id":"petitioner_last_name","label":"Last Name","type":"text","required":true,"maxLength":40},
          {"id":"petitioner_first_name","label":"First Name","type":"text","required":true,"maxLength":40},
          {"id":"petitioner_dob","label":"Date of Birth","type":"date","required":true},
          {"id":"petitioner_ssn","label":"SSN","type":"text","required":false,"mask":"XXX-XX-XXXX","maxLength":11}
        ]
      },
      {
        "id": "beneficiary_info",
        "title": "Beneficiary Information",
        "fields": [
          {"id":"beneficiary_last_name","label":"Last Name","type":"text","required":true,"maxLength":40},
          {"id":"beneficiary_first_name","label":"First Name","type":"text","required":true,"maxLength":40},
          {"id":"beneficiary_dob","label":"Date of Birth","type":"date","required":true}
        ]
      }
    ]
  }'::jsonb,
  '{
    "charLimits": {"petitioner_last_name":40,"petitioner_first_name":40,"beneficiary_last_name":40,"beneficiary_first_name":40},
    "masks": {"petitioner_ssn":"^[0-9]{3}-[0-9]{2}-[0-9]{4}$"},
    "dateFormat": "YYYY-MM-DD",
    "mapping": {
      "petitioner_last_name":"case.petitioner.last_name",
      "petitioner_first_name":"case.petitioner.first_name",
      "petitioner_dob":"case.petitioner.date_of_birth",
      "petitioner_ssn":"case.petitioner.ssn",
      "beneficiary_last_name":"case.beneficiary.last_name",
      "beneficiary_first_name":"case.beneficiary.first_name",
      "beneficiary_dob":"case.beneficiary.date_of_birth"
    }
  }'::jsonb
)
ON CONFLICT (form_code, version) DO UPDATE SET
  form_name = EXCLUDED.form_name,
  form_category = EXCLUDED.form_category,
  form_description = EXCLUDED.form_description,
  is_active = EXCLUDED.is_active,
  fields_schema = EXCLUDED.fields_schema,
  validation_rules = EXCLUDED.validation_rules,
  updated_at = now();

-- I-485 --------------------------------------------------------------------
UPDATE public.immigration_forms SET is_active = false WHERE form_code = 'I-485';
INSERT INTO public.immigration_forms (
  form_code, form_name, form_category, form_description,
  version, is_active, fields_schema, validation_rules
) VALUES (
  'I-485', 'Application to Register Permanent Residence or Adjust Status', 'adjustment', 'Adjustment of Status application',
  1, true,
  '{
    "sections": [
      {"id":"applicant_info","title":"Applicant","fields":[
        {"id":"applicant_last_name","label":"Last Name","type":"text","required":true,"maxLength":40},
        {"id":"applicant_first_name","label":"First Name","type":"text","required":true,"maxLength":40},
        {"id":"applicant_dob","label":"Date of Birth","type":"date","required":true},
        {"id":"a_number","label":"A-Number","type":"text","required":false,"mask":"A#########","maxLength":10}
      ]},
      {"id":"address","title":"Current Address","fields":[
        {"id":"street","label":"Street","type":"text","required":true,"maxLength":80},
        {"id":"city","label":"City","type":"text","required":true,"maxLength":40},
        {"id":"state","label":"State","type":"select","required":true,"options":["AL","AK","AZ","CA","NY","TX"]},
        {"id":"zip","label":"ZIP","type":"text","required":true,"mask":"#####","maxLength":5}
      ]}
    ]
  }'::jsonb,
  '{
    "charLimits": {"applicant_last_name":40,"applicant_first_name":40,"street":80,"city":40,"zip":5},
    "masks": {"a_number":"^A[0-9]{9}$","zip":"^[0-9]{5}$"},
    "dateFormat": "YYYY-MM-DD",
    "mapping": {
      "applicant_last_name":"applicant.last_name",
      "applicant_first_name":"applicant.first_name",
      "applicant_dob":"applicant.date_of_birth",
      "a_number":"applicant.a_number",
      "street":"applicant.address.street",
      "city":"applicant.address.city",
      "state":"applicant.address.state",
      "zip":"applicant.address.postal_code"
    }
  }'::jsonb
)
ON CONFLICT (form_code, version) DO UPDATE SET
  form_name = EXCLUDED.form_name,
  form_category = EXCLUDED.form_category,
  form_description = EXCLUDED.form_description,
  is_active = EXCLUDED.is_active,
  fields_schema = EXCLUDED.fields_schema,
  validation_rules = EXCLUDED.validation_rules,
  updated_at = now();

-- I-765 --------------------------------------------------------------------
UPDATE public.immigration_forms SET is_active = false WHERE form_code = 'I-765';
INSERT INTO public.immigration_forms (
  form_code, form_name, form_category, form_description,
  version, is_active, fields_schema, validation_rules
) VALUES (
  'I-765', 'Application for Employment Authorization', 'work', 'Employment authorization document (EAD)',
  1, true,
  '{"sections":[{"id":"base","title":"Applicant","fields":[
    {"id":"last_name","label":"Last Name","type":"text","required":true,"maxLength":40},
    {"id":"first_name","label":"First Name","type":"text","required":true,"maxLength":40},
    {"id":"category","label":"Eligibility Category","type":"text","required":true,"maxLength":5}
  ]}]}'::jsonb,
  '{"charLimits":{"last_name":40,"first_name":40,"category":5},"mapping":{
    "last_name":"applicant.last_name","first_name":"applicant.first_name","category":"case.i765.category"
  }}'::jsonb
)
ON CONFLICT (form_code, version) DO UPDATE SET
  form_name = EXCLUDED.form_name,
  form_category = EXCLUDED.form_category,
  form_description = EXCLUDED.form_description,
  is_active = EXCLUDED.is_active,
  fields_schema = EXCLUDED.fields_schema,
  validation_rules = EXCLUDED.validation_rules,
  updated_at = now();

-- I-864 --------------------------------------------------------------------
UPDATE public.immigration_forms SET is_active = false WHERE form_code = 'I-864';
INSERT INTO public.immigration_forms (
  form_code, form_name, form_category, form_description,
  version, is_active, fields_schema, validation_rules
) VALUES (
  'I-864', 'Affidavit of Support', 'family', 'Financial sponsorship affidavit',
  1, true,
  '{"sections":[{"id":"sponsor","title":"Sponsor","fields":[
    {"id":"sponsor_last_name","label":"Last Name","type":"text","required":true,"maxLength":40},
    {"id":"sponsor_first_name","label":"First Name","type":"text","required":true,"maxLength":40},
    {"id":"household_size","label":"Household Size","type":"number","required":true}
  ]}]}'::jsonb,
  '{"charLimits":{"sponsor_last_name":40,"sponsor_first_name":40},"mapping":{
    "sponsor_last_name":"case.petitioner.last_name","sponsor_first_name":"case.petitioner.first_name","household_size":"case.household.size"
  }}'::jsonb
)
ON CONFLICT (form_code, version) DO UPDATE SET
  form_name = EXCLUDED.form_name,
  form_category = EXCLUDED.form_category,
  form_description = EXCLUDED.form_description,
  is_active = EXCLUDED.is_active,
  fields_schema = EXCLUDED.fields_schema,
  validation_rules = EXCLUDED.validation_rules,
  updated_at = now();

-- N-400 --------------------------------------------------------------------
UPDATE public.immigration_forms SET is_active = false WHERE form_code = 'N-400';
INSERT INTO public.immigration_forms (
  form_code, form_name, form_category, form_description,
  version, is_active, fields_schema, validation_rules
) VALUES (
  'N-400', 'Application for Naturalization', 'citizenship', 'Naturalization application',
  1, true,
  '{"sections":[{"id":"bio","title":"Biographic","fields":[
    {"id":"last_name","label":"Last Name","type":"text","required":true,"maxLength":40},
    {"id":"first_name","label":"First Name","type":"text","required":true,"maxLength":40},
    {"id":"marital_status","label":"Marital Status","type":"select","required":true,"options":["single","married","divorced","widowed"]}
  ]}]}'::jsonb,
  '{"charLimits":{"last_name":40,"first_name":40},"mapping":{
    "last_name":"applicant.last_name","first_name":"applicant.first_name","marital_status":"applicant.marital_status"
  }}'::jsonb
)
ON CONFLICT (form_code, version) DO UPDATE SET
  form_name = EXCLUDED.form_name,
  form_category = EXCLUDED.form_category,
  form_description = EXCLUDED.form_description,
  is_active = EXCLUDED.is_active,
  fields_schema = EXCLUDED.fields_schema,
  validation_rules = EXCLUDED.validation_rules,
  updated_at = now();

-- I-131 --------------------------------------------------------------------
UPDATE public.immigration_forms SET is_active = false WHERE form_code = 'I-131';
INSERT INTO public.immigration_forms (
  form_code, form_name, form_category, form_description,
  version, is_active, fields_schema, validation_rules
) VALUES (
  'I-131', 'Application for Travel Document', 'travel', 'Advance Parole / Reentry Permit',
  1, true,
  '{"sections":[{"id":"travel","title":"Travel Info","fields":[
    {"id":"travel_doc_type","label":"Document Type","type":"select","required":true,"options":["advance_parole","reentry_permit"]},
    {"id":"departure_date","label":"Departure Date","type":"date","required":false},
    {"id":"return_date","label":"Return Date","type":"date","required":false}
  ]}]}'::jsonb,
  '{"mapping":{
    "travel_doc_type":"case.i131.document_type","departure_date":"case.travel.departure","return_date":"case.travel.return"
  }}'::jsonb
)
ON CONFLICT (form_code, version) DO UPDATE SET
  form_name = EXCLUDED.form_name,
  form_category = EXCLUDED.form_category,
  form_description = EXCLUDED.form_description,
  is_active = EXCLUDED.is_active,
  fields_schema = EXCLUDED.fields_schema,
  validation_rules = EXCLUDED.validation_rules,
  updated_at = now();

-- I-539 --------------------------------------------------------------------
UPDATE public.immigration_forms SET is_active = false WHERE form_code = 'I-539';
INSERT INTO public.immigration_forms (
  form_code, form_name, form_category, form_description,
  version, is_active, fields_schema, validation_rules
) VALUES (
  'I-539', 'Application to Extend/Change Nonimmigrant Status', 'nonimmigrant', 'Extend or change status',
  1, true,
  '{"sections":[{"id":"status","title":"Status","fields":[
    {"id":"current_status","label":"Current Status","type":"text","required":true,"maxLength":10},
    {"id":"requested_status","label":"Requested Status","type":"text","required":true,"maxLength":10}
  ]}]}'::jsonb,
  '{"charLimits":{"current_status":10,"requested_status":10},"mapping":{
    "current_status":"case.status.current","requested_status":"case.status.requested"
  }}'::jsonb
)
ON CONFLICT (form_code, version) DO UPDATE SET
  form_name = EXCLUDED.form_name,
  form_category = EXCLUDED.form_category,
  form_description = EXCLUDED.form_description,
  is_active = EXCLUDED.is_active,
  fields_schema = EXCLUDED.fields_schema,
  validation_rules = EXCLUDED.validation_rules,
  updated_at = now();

-- I-140 --------------------------------------------------------------------
UPDATE public.immigration_forms SET is_active = false WHERE form_code = 'I-140';
INSERT INTO public.immigration_forms (
  form_code, form_name, form_category, form_description,
  version, is_active, fields_schema, validation_rules
) VALUES (
  'I-140', 'Immigrant Petition for Alien Worker', 'employment', 'Employment-based immigrant petition',
  1, true,
  '{"sections":[{"id":"employer","title":"Employer","fields":[
    {"id":"company_name","label":"Company Name","type":"text","required":true,"maxLength":80},
    {"id":"fein","label":"FEIN","type":"text","required":false,"mask":"##-#######","maxLength":10}
  ]},{"id":"position","title":"Position","fields":[
    {"id":"job_title","label":"Job Title","type":"text","required":true,"maxLength":60},
    {"id":"salary","label":"Proffered Wage","type":"number","required":false}
  ]}]}'::jsonb,
  '{"charLimits":{"company_name":80,"job_title":60},"masks":{"fein":"^[0-9]{2}-[0-9]{7}$"},"mapping":{
    "company_name":"case.employer.name","fein":"case.employer.fein","job_title":"case.position.title","salary":"case.position.wage"
  }}'::jsonb
)
ON CONFLICT (form_code, version) DO UPDATE SET
  form_name = EXCLUDED.form_name,
  form_category = EXCLUDED.form_category,
  form_description = EXCLUDED.form_description,
  is_active = EXCLUDED.is_active,
  fields_schema = EXCLUDED.fields_schema,
  validation_rules = EXCLUDED.validation_rules,
  updated_at = now();

-- I-751 --------------------------------------------------------------------
UPDATE public.immigration_forms SET is_active = false WHERE form_code = 'I-751';
INSERT INTO public.immigration_forms (
  form_code, form_name, form_category, form_description,
  version, is_active, fields_schema, validation_rules
) VALUES (
  'I-751', 'Petition to Remove Conditions on Residence', 'conditions', 'Remove conditions on residence',
  1, true,
  '{"sections":[{"id":"marriage","title":"Marriage","fields":[
    {"id":"marriage_date","label":"Marriage Date","type":"date","required":true},
    {"id":"spouse_last_name","label":"Spouse Last Name","type":"text","required":true,"maxLength":40},
    {"id":"spouse_first_name","label":"Spouse First Name","type":"text","required":true,"maxLength":40}
  ]}]}'::jsonb,
  '{"charLimits":{"spouse_last_name":40,"spouse_first_name":40},"mapping":{
    "marriage_date":"applicant.marriage.date","spouse_last_name":"spouse.last_name","spouse_first_name":"spouse.first_name"
  }}'::jsonb
)
ON CONFLICT (form_code, version) DO UPDATE SET
  form_name = EXCLUDED.form_name,
  form_category = EXCLUDED.form_category,
  form_description = EXCLUDED.form_description,
  is_active = EXCLUDED.is_active,
  fields_schema = EXCLUDED.fields_schema,
  validation_rules = EXCLUDED.validation_rules,
  updated_at = now();

-- DS-160 -------------------------------------------------------------------
UPDATE public.immigration_forms SET is_active = false WHERE form_code = 'DS-160';
INSERT INTO public.immigration_forms (
  form_code, form_name, form_category, form_description,
  version, is_active, fields_schema, validation_rules
) VALUES (
  'DS-160', 'Online Nonimmigrant Visa Application', 'consular', 'Consular nonimmigrant application',
  1, true,
  '{"sections":[{"id":"bio","title":"Personal","fields":[
    {"id":"surname","label":"Surname","type":"text","required":true,"maxLength":40},
    {"id":"given_names","label":"Given Names","type":"text","required":true,"maxLength":40},
    {"id":"passport_number","label":"Passport Number","type":"text","required":true,"maxLength":9}
  ]},{"id":"travel","title":"Travel","fields":[
    {"id":"purpose","label":"Purpose of Trip","type":"select","required":true,"options":["B1","B2","F1","J1","H1B"]}
  ]}]}'::jsonb,
  '{"charLimits":{"surname":40,"given_names":40,"passport_number":9},"mapping":{
    "surname":"applicant.last_name","given_names":"applicant.first_name","passport_number":"applicant.passport.number","purpose":"case.travel.purpose"
  }}'::jsonb
)
ON CONFLICT (form_code, version) DO UPDATE SET
  form_name = EXCLUDED.form_name,
  form_category = EXCLUDED.form_category,
  form_description = EXCLUDED.form_description,
  is_active = EXCLUDED.is_active,
  fields_schema = EXCLUDED.fields_schema,
  validation_rules = EXCLUDED.validation_rules,
  updated_at = now();

COMMIT;