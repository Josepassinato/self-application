-- Ensure documents bucket exists and is properly configured
INSERT INTO storage.buckets (id, name, public) 
VALUES ('documents', 'documents', false)
ON CONFLICT (id) DO NOTHING;

-- Create storage policies for document access
CREATE POLICY "Users can view documents from their cases" 
ON storage.objects 
FOR SELECT 
USING (
  bucket_id = 'documents' 
  AND EXISTS (
    SELECT 1 FROM public.case_documents cd
    JOIN public.cases c ON c.id = cd.case_id
    JOIN public.clients cl ON cl.id = c.client_id
    WHERE cd.url = ('documents/' || name)
  )
);

CREATE POLICY "Users can upload documents to their cases" 
ON storage.objects 
FOR INSERT 
WITH CHECK (
  bucket_id = 'documents'
  AND auth.uid() IS NOT NULL
);

CREATE POLICY "Users can update documents from their cases" 
ON storage.objects 
FOR UPDATE 
USING (
  bucket_id = 'documents' 
  AND EXISTS (
    SELECT 1 FROM public.case_documents cd
    JOIN public.cases c ON c.id = cd.case_id
    JOIN public.clients cl ON cl.id = c.client_id
    WHERE cd.url = ('documents/' || name)
  )
);

-- Add signature-related columns to case_documents
ALTER TABLE public.case_documents 
ADD COLUMN IF NOT EXISTS signature_required BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS signature_status TEXT DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS signature_data JSONB,
ADD COLUMN IF NOT EXISTS signed_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS file_size BIGINT,
ADD COLUMN IF NOT EXISTS content_type TEXT;

-- Create document signatures table
CREATE TABLE IF NOT EXISTS public.document_signatures (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  document_id UUID NOT NULL REFERENCES public.case_documents(id) ON DELETE CASCADE,
  signer_type TEXT NOT NULL CHECK (signer_type IN ('client', 'lawyer')),
  signer_id UUID NOT NULL,
  signature_image_url TEXT,
  signature_metadata JSONB,
  signed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS on document_signatures
ALTER TABLE public.document_signatures ENABLE ROW LEVEL SECURITY;

-- Create policies for document signatures
CREATE POLICY "Users can view signatures for their documents" 
ON public.document_signatures 
FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.case_documents cd
    JOIN public.cases c ON c.id = cd.case_id
    JOIN public.clients cl ON cl.id = c.client_id
    WHERE cd.id = document_id
  )
);

CREATE POLICY "Users can create signatures for their documents" 
ON public.document_signatures 
FOR INSERT 
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.case_documents cd
    JOIN public.cases c ON c.id = cd.case_id
    JOIN public.clients cl ON cl.id = c.client_id
    WHERE cd.id = document_id
  )
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_document_signatures_document_id ON public.document_signatures(document_id);
CREATE INDEX IF NOT EXISTS idx_document_signatures_signer ON public.document_signatures(signer_id, signer_type);