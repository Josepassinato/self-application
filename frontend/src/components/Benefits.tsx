import { Card, CardContent } from "@/components/ui/card";
import { Shield, Clock, Users, Award, HeadphonesIcon, FileCheck } from "lucide-react";

const benefits = [
  {
    icon: Shield,
    title: "100% Seguro",
    description: "Seus dados protegidos com criptografia de nível bancário"
  },
  {
    icon: Clock,
    title: "Processo Rápido",
    description: "Média de 30 dias para aprovação de processos"
  },
  {
    icon: Users,
    title: "Especialistas Dedicados",
    description: "Equipe de advogados especializados em imigração"
  },
  {
    icon: Award,
    title: "Taxa de Sucesso 98%",
    description: "Mais de 5.000 processos aprovados com sucesso"
  },
  {
    icon: HeadphonesIcon,
    title: "Suporte 24/7",
    description: "Atendimento especializado disponível quando precisar"
  },
  {
    icon: FileCheck,
    title: "Garantia Total",
    description: "Aprovação garantida ou reembolso de 100% do valor"
  }
];

const Benefits = () => {
  return (
    <section className="py-20 bg-gradient-subtle">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <div className="text-center space-y-4 mb-16">
          <h2 className="text-3xl md:text-4xl font-bold text-foreground">
            Por que escolher a OSPREY?
          </h2>
          <p className="text-lg text-muted-foreground max-w-2xl mx-auto">
            Somos a plataforma líder em auto aplicação imigratória,
            com tecnologia avançada e suporte especializado.
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {benefits.map((benefit, index) => {
            const IconComponent = benefit.icon;
            return (
              <Card key={index} className="border-0 bg-card/50 backdrop-blur-sm hover:bg-card transition-all duration-300">
                <CardContent className="p-6 text-center space-y-4">
                  <div className="mx-auto w-16 h-16 bg-gradient-primary rounded-full flex items-center justify-center">
                    <IconComponent className="h-8 w-8 text-primary-foreground" />
                  </div>
                  <h3 className="text-xl font-semibold text-foreground">
                    {benefit.title}
                  </h3>
                  <p className="text-muted-foreground">
                    {benefit.description}
                  </p>
                </CardContent>
              </Card>
            );
          })}
        </div>
      </div>
    </section>
  );
};

export default Benefits;