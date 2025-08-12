import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Plane, GraduationCap, Heart, Briefcase, Users, ArrowRight } from "lucide-react";

const services = [
  {
    icon: Briefcase,
    title: "Visto de Trabalho",
    description: "Processo completo para obtenção de visto de trabalho em diversos países.",
    types: ["H1-B", "L1", "O1", "EB-5"],
    popular: true
  },
  {
    icon: GraduationCap,
    title: "Visto de Estudante",
    description: "Suporte completo para aplicações de visto de estudante e intercâmbio.",
    types: ["F1", "M1", "J1", "F2"],
    popular: false
  },
  {
    icon: Heart,
    title: "Reunificação Familiar",
    description: "Processos de imigração baseados em laços familiares.",
    types: ["CR1", "IR1", "K1", "F2A"],
    popular: false
  },
  {
    icon: Users,
    title: "Residência Permanente",
    description: "Caminhos para obtenção de residência permanente e cidadania.",
    types: ["Green Card", "EB-1", "EB-2", "EB-3"],
    popular: true
  },
  {
    icon: Plane,
    title: "Visto de Turismo",
    description: "Aplicações rápidas para vistos de turismo e negócios.",
    types: ["B1/B2", "ESTA", "VWP"],
    popular: false
  },
  {
    icon: Briefcase,
    title: "Visto de Investidor",
    description: "Processos para empreendedores e investidores.",
    types: ["E2", "EB-5", "L1A"],
    popular: false
  }
];

const Services = () => {
  return (
    <section id="services" className="py-20 bg-background">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center space-y-4 mb-16">
          <h2 className="text-3xl md:text-4xl font-bold text-foreground">
            Nossos Serviços
          </h2>
          <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
            Oferecemos suporte completo para todos os tipos de processos imigratórios,
            com especialistas dedicados para cada categoria.
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {services.map((service, index) => {
            const IconComponent = service.icon;
            return (
              <Card key={index} className="relative hover:shadow-elegant transition-all duration-300 hover:-translate-y-1">
                {service.popular && (
                  <Badge className="absolute -top-2 -right-2 bg-gradient-hero text-primary-foreground">
                    Popular
                  </Badge>
                )}
                <CardHeader className="pb-4">
                  <div className="flex items-center justify-between">
                    <div className="p-3 bg-gradient-subtle rounded-lg">
                      <IconComponent className="h-6 w-6 text-primary" />
                    </div>
                  </div>
                  <CardTitle className="text-xl">{service.title}</CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <p className="text-muted-foreground">
                    {service.description}
                  </p>
                  <div className="flex flex-wrap gap-2">
                    {service.types.map((type, typeIndex) => (
                      <Badge key={typeIndex} variant="secondary" className="text-xs">
                        {type}
                      </Badge>
                    ))}
                  </div>
                  <Button variant="ghost" className="w-full justify-between group">
                    Saiba Mais
                    <ArrowRight className="h-4 w-4 group-hover:translate-x-1 transition-transform" />
                  </Button>
                </CardContent>
              </Card>
            );
          })}
        </div>

        <div className="text-center mt-12">
          <Button variant="professional" size="lg">
            Ver Todos os Serviços
            <ArrowRight className="h-4 w-4" />
          </Button>
        </div>
      </div>
    </section>
  );
};

export default Services;