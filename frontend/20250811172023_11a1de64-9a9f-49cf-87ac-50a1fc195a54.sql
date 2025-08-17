-- Create marketplace services table
CREATE TABLE IF NOT EXISTS public.marketplace_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id UUID NOT NULL,
  provider_name TEXT NOT NULL,
  service_name TEXT NOT NULL,
  description TEXT,
  price DECIMAL(10,2),
  currency TEXT DEFAULT 'USD',
  category TEXT,                     -- translation, medical_exam, courier, photo, etc.
  rating DECIMAL(3,2) DEFAULT 0,
  review_count INTEGER DEFAULT 0,
  contact_info JSONB,                 -- phone, email, website
  availability JSONB,                 -- schedule slots
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  active BOOLEAN DEFAULT true
);

-- Create marketplace providers table
CREATE TABLE IF NOT EXISTS public.marketplace_providers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  business_name TEXT NOT NULL,
  contact_email TEXT NOT NULL,
  contact_phone TEXT,
  business_license TEXT,
  verification_status TEXT DEFAULT 'pending',  -- pending, verified, rejected
  verification_documents JSONB,
  terms_accepted BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  active BOOLEAN DEFAULT true
);

-- Create marketplace bookings table
CREATE TABLE IF NOT EXISTS public.marketplace_bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id UUID NOT NULL REFERENCES public.marketplace_services(id),
  client_id UUID NOT NULL,
  case_id UUID,
  booking_date TIMESTAMPTZ NOT NULL,
  status TEXT DEFAULT 'pending',      -- pending, confirmed, completed, cancelled
  price DECIMAL(10,2) NOT NULL,
  currency TEXT DEFAULT 'USD',
  payment_status TEXT DEFAULT 'pending',  -- pending, paid, failed, refunded
  payment_intent_id TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create marketplace reviews table
CREATE TABLE IF NOT EXISTS public.marketplace_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id UUID NOT NULL REFERENCES public.marketplace_services(id),
  booking_id UUID NOT NULL REFERENCES public.marketplace_bookings(id),
  client_id UUID NOT NULL,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(booking_id)  -- One review per booking
);

-- Enable RLS
ALTER TABLE public.marketplace_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_reviews ENABLE ROW LEVEL SECURITY;

-- RLS Policies for marketplace_services
CREATE POLICY "Anyone can view active services" 
ON public.marketplace_services 
FOR SELECT 
USING (active = true);

CREATE POLICY "Service providers can manage their services" 
ON public.marketplace_services 
FOR ALL 
USING (provider_id IN (
  SELECT id FROM public.marketplace_providers 
  WHERE law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
))
WITH CHECK (provider_id IN (
  SELECT id FROM public.marketplace_providers 
  WHERE law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
));

-- RLS Policies for marketplace_providers
CREATE POLICY "Users can view providers from their firm" 
ON public.marketplace_providers 
FOR SELECT 
USING (law_firm_id IN (
  SELECT law_firm_id FROM public.platform_users 
  WHERE auth_user_id = auth.uid()
));

CREATE POLICY "Users can manage providers from their firm" 
ON public.marketplace_providers 
FOR ALL 
USING (law_firm_id IN (
  SELECT law_firm_id FROM public.platform_users 
  WHERE auth_user_id = auth.uid()
))
WITH CHECK (law_firm_id IN (
  SELECT law_firm_id FROM public.platform_users 
  WHERE auth_user_id = auth.uid()
));

-- RLS Policies for marketplace_bookings
CREATE POLICY "Clients can view their own bookings" 
ON public.marketplace_bookings 
FOR SELECT 
USING (client_id IN (
  SELECT id FROM public.clients 
  WHERE client_user_id = auth.uid()
));

CREATE POLICY "Law firm users can view bookings for their clients" 
ON public.marketplace_bookings 
FOR SELECT 
USING (client_id IN (
  SELECT c.id FROM public.clients c
  JOIN public.platform_users pu ON pu.auth_user_id = c.responsavel_id
  WHERE pu.auth_user_id = auth.uid() OR pu.law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
));

CREATE POLICY "Clients can create bookings" 
ON public.marketplace_bookings 
FOR INSERT 
WITH CHECK (client_id IN (
  SELECT id FROM public.clients 
  WHERE client_user_id = auth.uid()
));

CREATE POLICY "System can update booking status" 
ON public.marketplace_bookings 
FOR UPDATE 
USING (true);

-- RLS Policies for marketplace_reviews
CREATE POLICY "Anyone can view reviews" 
ON public.marketplace_reviews 
FOR SELECT 
USING (true);

CREATE POLICY "Clients can create reviews for their bookings" 
ON public.marketplace_reviews 
FOR INSERT 
WITH CHECK (
  client_id IN (
    SELECT id FROM public.clients 
    WHERE client_user_id = auth.uid()
  ) AND 
  booking_id IN (
    SELECT id FROM public.marketplace_bookings 
    WHERE client_id IN (
      SELECT id FROM public.clients 
      WHERE client_user_id = auth.uid()
    ) AND status = 'completed'
  )
);

-- Create indexes
CREATE INDEX idx_marketplace_services_category ON public.marketplace_services(category);
CREATE INDEX idx_marketplace_services_active ON public.marketplace_services(active);
CREATE INDEX idx_marketplace_services_rating ON public.marketplace_services(rating DESC);
CREATE INDEX idx_marketplace_bookings_client ON public.marketplace_bookings(client_id);
CREATE INDEX idx_marketplace_bookings_service ON public.marketplace_bookings(service_id);
CREATE INDEX idx_marketplace_bookings_date ON public.marketplace_bookings(booking_date);
CREATE INDEX idx_marketplace_reviews_service ON public.marketplace_reviews(service_id);

-- Function to update service rating
CREATE OR REPLACE FUNCTION public.update_service_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.marketplace_services 
  SET 
    rating = (
      SELECT ROUND(AVG(rating)::numeric, 2) 
      FROM public.marketplace_reviews 
      WHERE service_id = NEW.service_id
    ),
    review_count = (
      SELECT COUNT(*) 
      FROM public.marketplace_reviews 
      WHERE service_id = NEW.service_id
    )
  WHERE id = NEW.service_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update rating when review is added
CREATE TRIGGER update_service_rating_trigger
  AFTER INSERT ON public.marketplace_reviews
  FOR EACH ROW
  EXECUTE FUNCTION public.update_service_rating();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_marketplace_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_marketplace_services_updated_at
  BEFORE UPDATE ON public.marketplace_services
  FOR EACH ROW
  EXECUTE FUNCTION public.update_marketplace_updated_at();

CREATE TRIGGER update_marketplace_providers_updated_at
  BEFORE UPDATE ON public.marketplace_providers
  FOR EACH ROW
  EXECUTE FUNCTION public.update_marketplace_updated_at();

CREATE TRIGGER update_marketplace_bookings_updated_at
  BEFORE UPDATE ON public.marketplace_bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.update_marketplace_updated_at();