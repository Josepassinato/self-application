import "https://deno.land/x/xhr@0.1.0/mod.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface EFilingRequest {
  caseId: string;
  accountId: string;
  packageUri?: string;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { caseId, accountId, packageUri }: EFilingRequest = await req.json();

    console.log(`Starting e-filing process for case ${caseId} with account ${accountId}`);

    // Get case and account information
    const { data: caseData, error: caseError } = await supabase
      .from('cases')
      .select('*, clients(*)')
      .eq('id', caseId)
      .single();

    if (caseError || !caseData) {
      throw new Error(`Case not found: ${caseError?.message}`);
    }

    const { data: accountData, error: accountError } = await supabase
      .from('efiling_accounts')
      .select('*')
      .eq('id', accountId)
      .single();

    if (accountError || !accountData) {
      throw new Error(`E-filing account not found: ${accountError?.message}`);
    }

    // Log start of process
    await logEFilingStep(supabase, caseId, accountId, 'start', 'in_progress', 'Iniciando processo de e-filing');

    // Simulate USCIS e-filing process (in production, would use Playwright/Puppeteer)
    const steps = [
      { step: 'login', message: 'Fazendo login na conta USCIS' },
      { step: 'form_selection', message: 'Selecionando tipo de formulário' },
      { step: 'form_filling', message: 'Preenchendo dados do formulário' },
      { step: 'document_upload', message: 'Fazendo upload de documentos' },
      { step: 'evidence_upload', message: 'Fazendo upload de evidências' },
      { step: 'review', message: 'Revisando submissão' },
      { step: 'submit', message: 'Submetendo formulário' },
      { step: 'receipt', message: 'Capturando receipt number' }
    ];

    for (const stepInfo of steps) {
      await logEFilingStep(supabase, caseId, accountId, stepInfo.step, 'in_progress', stepInfo.message);
      
      // Simulate processing time
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Simulate potential failure
      if (stepInfo.step === 'submit' && Math.random() < 0.1) { // 10% chance of failure
        await logEFilingStep(supabase, caseId, accountId, stepInfo.step, 'failed', 'Erro na submissão - formulário rejeitado');
        throw new Error('Submissão rejeitada pelo USCIS');
      }
      
      await logEFilingStep(supabase, caseId, accountId, stepInfo.step, 'completed', `${stepInfo.message} - concluído`);
    }

    // Generate receipt number and save confirmation
    const receiptNumber = `MSC${Date.now().toString().slice(-10)}`;
    const confirmationUrl = `uscis_receipts/${caseId}/confirmation_${receiptNumber}.pdf`;

    // Create case event for receipt
    await supabase
      .from('case_events')
      .insert({
        case_id: caseId,
        event_type: 'form_submitted',
        receipt_number: receiptNumber,
        document_url: confirmationUrl,
        description: `Formulário submetido com sucesso. Receipt Number: ${receiptNumber}`
      });

    // Update case status
    await supabase
      .from('cases')
      .update({ 
        status: 'em_andamento',
        observacoes: `E-filing concluído. Receipt: ${receiptNumber}`
      })
      .eq('id', caseId);

    // Schedule biometrics appointment detection (simulate)
    await scheduleEventMonitoring(supabase, caseId, receiptNumber);

    await logEFilingStep(supabase, caseId, accountId, 'complete', 'completed', `Processo concluído. Receipt: ${receiptNumber}`);

    console.log(`E-filing completed successfully for case ${caseId}. Receipt: ${receiptNumber}`);

    return new Response(JSON.stringify({
      success: true,
      receiptNumber,
      confirmationUrl,
      message: 'E-filing concluído com sucesso'
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error('Error in uscis-efiling:', error);
    
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

async function logEFilingStep(
  supabase: any,
  caseId: string,
  accountId: string,
  step: string,
  status: string,
  message: string
) {
  await supabase
    .from('efiling_logs')
    .insert({
      case_id: caseId,
      account_id: accountId,
      step,
      status,
      message,
      execution_time_ms: Math.floor(Math.random() * 2000) + 500 // Simulate execution time
    });
}

async function scheduleEventMonitoring(supabase: any, caseId: string, receiptNumber: string) {
  // Simulate scheduling biometrics appointment (would be done via periodic monitoring)
  setTimeout(async () => {
    const appointmentDate = new Date();
    appointmentDate.setDate(appointmentDate.getDate() + 14); // 2 weeks from now

    await supabase
      .from('case_events')
      .insert({
        case_id: caseId,
        event_type: 'biometrics_appointment',
        event_date: appointmentDate.toISOString(),
        location: 'USCIS Application Support Center - São Paulo',
        receipt_number: receiptNumber,
        description: 'Agendamento de coleta de dados biométricos'
      });
  }, 5000); // Simulate 5 second delay
}