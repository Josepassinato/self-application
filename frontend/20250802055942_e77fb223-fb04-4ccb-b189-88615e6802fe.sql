-- Criar bucket de documentos se não existir
INSERT INTO storage.buckets (id, name, public) 
VALUES ('documents', 'documents', false) 
ON CONFLICT (id) DO NOTHING;

-- Criar políticas para storage de documentos
CREATE POLICY "Users can upload their own documents" 
ON storage.objects 
FOR INSERT 
WITH CHECK (
  bucket_id = 'documents' AND
  EXISTS (
    SELECT 1 FROM platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

CREATE POLICY "Users can view documents from their firm" 
ON storage.objects 
FOR SELECT 
USING (
  bucket_id = 'documents' AND
  EXISTS (
    SELECT 1 FROM platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

CREATE POLICY "Users can update documents from their firm" 
ON storage.objects 
FOR UPDATE 
USING (
  bucket_id = 'documents' AND
  EXISTS (
    SELECT 1 FROM platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

CREATE POLICY "Users can delete documents from their firm" 
ON storage.objects 
FOR DELETE 
USING (
  bucket_id = 'documents' AND
  EXISTS (
    SELECT 1 FROM platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

-- Corrigir tabela case_documents se não tiver as colunas necessárias
DO $$ 
BEGIN
  -- Adicionar colunas se não existirem
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'case_documents' AND column_name = 'signature_required') THEN
    ALTER TABLE case_documents ADD COLUMN signature_required BOOLEAN DEFAULT false;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'case_documents' AND column_name = 'signature_status') THEN
    ALTER TABLE case_documents ADD COLUMN signature_status TEXT DEFAULT 'not_required';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'case_documents' AND column_name = 'file_size') THEN
    ALTER TABLE case_documents ADD COLUMN file_size BIGINT;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'case_documents' AND column_name = 'content_type') THEN
    ALTER TABLE case_documents ADD COLUMN content_type TEXT;
  END IF;
END $$;