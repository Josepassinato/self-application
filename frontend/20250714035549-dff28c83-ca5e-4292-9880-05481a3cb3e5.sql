-- Create chat_conversations table for storing AI chat history
CREATE TABLE public.chat_conversations (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id),
  case_id UUID REFERENCES public.cases(id),
  thread_id TEXT NOT NULL,
  title TEXT,
  last_message_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Create chat_messages table for individual messages
CREATE TABLE public.chat_messages (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id UUID NOT NULL REFERENCES public.chat_conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
  content TEXT NOT NULL,
  message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'document_reference', 'case_update')),
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.chat_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for chat_conversations
CREATE POLICY "Users can view their own conversations" 
ON public.chat_conversations 
FOR SELECT 
USING (user_id = auth.uid());

CREATE POLICY "Users can create their own conversations" 
ON public.chat_conversations 
FOR INSERT 
WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own conversations" 
ON public.chat_conversations 
FOR UPDATE 
USING (user_id = auth.uid());

-- RLS Policies for chat_messages
CREATE POLICY "Users can view messages from their conversations" 
ON public.chat_messages 
FOR SELECT 
USING (
  conversation_id IN (
    SELECT id FROM public.chat_conversations 
    WHERE user_id = auth.uid()
  )
);

CREATE POLICY "Users can create messages in their conversations" 
ON public.chat_messages 
FOR INSERT 
WITH CHECK (
  conversation_id IN (
    SELECT id FROM public.chat_conversations 
    WHERE user_id = auth.uid()
  )
);

-- Create indexes for performance
CREATE INDEX idx_chat_conversations_user_id ON public.chat_conversations(user_id);
CREATE INDEX idx_chat_conversations_case_id ON public.chat_conversations(case_id);
CREATE INDEX idx_chat_conversations_thread_id ON public.chat_conversations(thread_id);
CREATE INDEX idx_chat_messages_conversation_id ON public.chat_messages(conversation_id);
CREATE INDEX idx_chat_messages_created_at ON public.chat_messages(created_at);

-- Trigger to update updated_at on conversations
CREATE TRIGGER update_chat_conversations_updated_at
BEFORE UPDATE ON public.chat_conversations
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger to update last_message_at when new message is added
CREATE OR REPLACE FUNCTION public.update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.chat_conversations 
  SET last_message_at = NEW.created_at
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_conversation_last_message_trigger
AFTER INSERT ON public.chat_messages
FOR EACH ROW
EXECUTE FUNCTION public.update_conversation_last_message();