import { Button } from "@/components/ui/button";
import { ArrowRight, CheckCircle } from "lucide-react";
import heroImage from "@/assets/hero-immigration.jpg";

const Hero = () => {
  return (
    <section className="bg-gradient-subtle min-h-[90vh] flex items-center">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid lg:grid-cols-2 gap-12 items-center">
          <div className="space-y-8">
            <div className="space-y-4">
              <h1 className="text-4xl md:text-5xl lg:text-6xl font-bold text-foreground leading-tight">
                Simplifique sua
                <span className="bg-gradient-hero bg-clip-text text-transparent"> Jornada Imigratória</span>
              </h1>
              <p className="text-lg md:text-xl text-muted-foreground leading-relaxed">
                Plataforma completa para auto aplicação de processos imigratórios. 
                Rápido, seguro e totalmente digital.
              </p>
            </div>

            <div className="space-y-3">
              <div className="flex items-center space-x-3">
                <CheckCircle className="h-5 w-5 text-success" />
                <span className="text-muted-foreground">Processo 100% digital</span>
              </div>
              <div className="flex items-center space-x-3">
                <CheckCircle className="h-5 w-5 text-success" />
                <span className="text-muted-foreground">Suporte especializado 24/7</span>
              </div>
              <div className="flex items-center space-x-3">
                <CheckCircle className="h-5 w-5 text-success" />
                <span className="text-muted-foreground">Aprovação garantida ou reembolso total</span>
              </div>
            </div>

            <div className="flex flex-col sm:flex-row gap-4">
              <Button variant="hero" size="xl" className="text-lg">
                Iniciar Aplicação
                <ArrowRight className="h-5 w-5" />
              </Button>
              <Button variant="outline" size="xl" className="text-lg">
                Ver Como Funciona
              </Button>
            </div>

            <div className="flex items-center space-x-8 text-sm text-muted-foreground">
              <div className="flex items-center space-x-2">
                <div className="w-2 h-2 bg-success rounded-full"></div>
                <span>+5.000 aprovações</span>
              </div>
              <div className="flex items-center space-x-2">
                <div className="w-2 h-2 bg-primary rounded-full"></div>
                <span>Média 30 dias</span>
              </div>
            </div>
          </div>

          <div className="relative">
            <div className="relative z-10">
              <img
                src={heroImage}
                alt="Documentos de imigração OSPREY"
                className="w-full h-auto rounded-2xl shadow-elegant"
              />
            </div>
            <div className="absolute -top-6 -right-6 w-full h-full bg-gradient-primary rounded-2xl opacity-20 z-0"></div>
          </div>
        </div>
      </div>
    </section>
  );
};

export default Hero;