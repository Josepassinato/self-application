import { Globe, Phone, Mail, MapPin } from "lucide-react";

const Footer = () => {
  return (
    <footer className="bg-foreground text-background">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid md:grid-cols-4 gap-8">
          <div className="space-y-4">
            <div className="flex items-center space-x-2">
              <Globe className="h-8 w-8" />
              <span className="text-xl font-bold">OSPREY</span>
            </div>
            <p className="text-background/70">
              Simplificando processos imigratórios com tecnologia e expertise.
            </p>
            <div className="space-y-2">
              <div className="flex items-center space-x-2 text-sm text-background/70">
                <Phone className="h-4 w-4" />
                <span>+55 (11) 9999-9999</span>
              </div>
              <div className="flex items-center space-x-2 text-sm text-background/70">
                <Mail className="h-4 w-4" />
                <span>contato@osprey.com.br</span>
              </div>
              <div className="flex items-center space-x-2 text-sm text-background/70">
                <MapPin className="h-4 w-4" />
                <span>São Paulo, Brasil</span>
              </div>
            </div>
          </div>

          <div>
            <h3 className="font-semibold mb-4">Serviços</h3>
            <ul className="space-y-2 text-sm text-background/70">
              <li><a href="#" className="hover:text-background transition-smooth">Visto de Trabalho</a></li>
              <li><a href="#" className="hover:text-background transition-smooth">Visto de Estudante</a></li>
              <li><a href="#" className="hover:text-background transition-smooth">Reunificação Familiar</a></li>
              <li><a href="#" className="hover:text-background transition-smooth">Residência Permanente</a></li>
            </ul>
          </div>

          <div>
            <h3 className="font-semibold mb-4">Empresa</h3>
            <ul className="space-y-2 text-sm text-background/70">
              <li><a href="#" className="hover:text-background transition-smooth">Sobre Nós</a></li>
              <li><a href="#" className="hover:text-background transition-smooth">Nossa Equipe</a></li>
              <li><a href="#" className="hover:text-background transition-smooth">Casos de Sucesso</a></li>
              <li><a href="#" className="hover:text-background transition-smooth">Blog</a></li>
            </ul>
          </div>

          <div>
            <h3 className="font-semibold mb-4">Suporte</h3>
            <ul className="space-y-2 text-sm text-background/70">
              <li><a href="#" className="hover:text-background transition-smooth">Central de Ajuda</a></li>
              <li><a href="#" className="hover:text-background transition-smooth">FAQ</a></li>
              <li><a href="#" className="hover:text-background transition-smooth">Política de Privacidade</a></li>
              <li><a href="#" className="hover:text-background transition-smooth">Termos de Uso</a></li>
            </ul>
          </div>
        </div>

        <div className="border-t border-background/20 mt-8 pt-8 text-center text-sm text-background/70">
          <p>&copy; 2024 OSPREY. Todos os direitos reservados.</p>
        </div>
      </div>
    </footer>
  );
};

export default Footer;