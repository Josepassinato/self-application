import { Button } from "@/components/ui/button";
import { ArrowRight, Globe } from "lucide-react";

const Header = () => {
  return (
    <header className="bg-card border-b border-border shadow-soft">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <div className="flex items-center space-x-2">
            <Globe className="h-8 w-8 text-primary" />
            <span className="text-xl font-bold text-foreground">OSPREY</span>
          </div>
          
          <nav className="hidden md:flex items-center space-x-8">
            <a href="#services" className="text-muted-foreground hover:text-foreground transition-smooth">
              Serviços
            </a>
            <a href="#about" className="text-muted-foreground hover:text-foreground transition-smooth">
              Sobre
            </a>
            <a href="#contact" className="text-muted-foreground hover:text-foreground transition-smooth">
              Contato
            </a>
          </nav>

          <div className="flex items-center space-x-4">
            <Button variant="ghost" size="sm">
              Entrar
            </Button>
            <Button variant="professional" size="sm" className="hidden sm:flex">
              Começar Aplicação
              <ArrowRight className="h-4 w-4" />
            </Button>
          </div>
        </div>
      </div>
    </header>
  );
};

export default Header;