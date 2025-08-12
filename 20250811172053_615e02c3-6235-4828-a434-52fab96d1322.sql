-- Fix security warnings by setting search_path for functions
CREATE OR REPLACE FUNCTION public.update_service_rating()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
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
$$;

CREATE OR REPLACE FUNCTION public.update_marketplace_updated_at()
RETURNS TRIGGER 
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;