import { Button } from "@/components/ui/button";
import { ArrowRight, Phone, Mail } from "lucide-react";

const CTA = () => {
  return (
    <section className="py-20 bg-gradient-hero">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center space-y-8 max-w-4xl mx-auto">
          <h2 className="text-3xl md:text-4xl lg:text-5xl font-bold text-primary-foreground">
            Pronto para começar sua jornada?
          </h2>
          <p className="text-lg md:text-xl text-primary-foreground/90 leading-relaxed">
            Mais de 5.000 pessoas já realizaram seus sonhos de imigração conosco.
            Você será o próximo!
          </p>
          
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Button variant="secondary" size="xl" className="text-lg">
              Começar Minha Aplicação
              <ArrowRight className="h-5 w-5" />
            </Button>
            <Button variant="outline" size="xl" className="text-lg border-primary-foreground/20 text-primary-foreground hover:bg-primary-foreground/10">
              Falar com Especialista
              <Phone className="h-5 w-5" />
            </Button>
          </div>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-8 pt-8 border-t border-primary-foreground/20">
            <div className="flex items-center space-x-2 text-primary-foreground/90">
              <Phone className="h-5 w-5" />
              <span>+55 (11) 9999-9999</span>
            </div>
            <div className="flex items-center space-x-2 text-primary-foreground/90">
              <Mail className="h-5 w-5" />
              <span>contato@osprey.com.br</span>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default CTA;