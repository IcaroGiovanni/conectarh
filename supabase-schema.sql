-- =============================================
-- SUPABASE SCHEMA - Conecta RH
-- =============================================

-- =============================================
-- 1. ENUMS
-- =============================================

DROP TYPE IF EXISTS modality_type CASCADE;
DROP TYPE IF EXISTS contract_type CASCADE;
DROP TYPE IF EXISTS experience_level CASCADE;
DROP TYPE IF EXISTS application_status CASCADE;
DROP TYPE IF EXISTS request_status CASCADE;
DROP TYPE IF EXISTS job_status CASCADE;
DROP TYPE IF EXISTS user_status CASCADE;

CREATE TYPE modality_type AS ENUM ('Remoto', 'Hibrido', 'Presencial');
CREATE TYPE contract_type AS ENUM ('CLT', 'PJ', 'Freelancer', 'Estagio');
CREATE TYPE experience_level AS ENUM ('Estagio', 'Junior', 'Pleno', 'Senior');
CREATE TYPE application_status AS ENUM ('pending', 'reviewed', 'approved', 'rejected');
CREATE TYPE request_status AS ENUM ('pending', 'contacted', 'in_progress', 'completed', 'cancelled');
CREATE TYPE job_status AS ENUM ('active', 'paused', 'closed', 'draft');
CREATE TYPE user_status AS ENUM ('pending', 'approved', 'rejected');

-- =============================================
-- 2. TABELAS
-- =============================================

-- Companies (Empresas)
CREATE TABLE companies (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(255) UNIQUE NOT NULL,
  description TEXT,
  website VARCHAR(500),
  logo_url VARCHAR(500),
  industry VARCHAR(100),
  company_size VARCHAR(50),
  founded_year INTEGER,
  headquarters VARCHAR(255),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Jobs (Vagas)
CREATE TABLE jobs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  responsibilities TEXT,
  requirements TEXT,
  differentials TEXT,
  benefits TEXT,
  salary_min DECIMAL(10,2),
  salary_max DECIMAL(10,2),
  salary_display VARCHAR(100),
  location VARCHAR(255) NOT NULL,
  modality modality_type NOT NULL,
  contract_type contract_type NOT NULL,
  experience_level experience_level NOT NULL,
  area VARCHAR(100) NOT NULL,
  status job_status DEFAULT 'active',
  is_featured BOOLEAN DEFAULT false,
  published_at TIMESTAMPTZ DEFAULT now(),
  closed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Candidates (Candidatos)
CREATE TABLE candidates (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID,
  full_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  phone VARCHAR(50),
  city VARCHAR(100),
  linkedin_url VARCHAR(500),
  resume_file_path VARCHAR(500),
  experience_years INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Job Applications (Candidaturas)
CREATE TABLE job_applications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,
  candidate_id UUID REFERENCES candidates(id) ON DELETE CASCADE,
  resume_file_path VARCHAR(500),
  message TEXT,
  status application_status DEFAULT 'pending',
  applied_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(job_id, candidate_id)
);

-- Recruitment Requests (Pedidos de Contratação)
CREATE TABLE recruitment_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  company_name VARCHAR(255) NOT NULL,
  contact_name VARCHAR(255) NOT NULL,
  contact_email VARCHAR(255) NOT NULL,
  contact_phone VARCHAR(50),
  company_industry VARCHAR(100),
  job_title VARCHAR(255) NOT NULL,
  job_description TEXT NOT NULL,
  quantity INTEGER DEFAULT 1,
  salary_range VARCHAR(100),
  deadline DATE,
  notes TEXT,
  status request_status DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Testimonials (Depoimentos)
CREATE TABLE testimonials (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  author_name VARCHAR(255) NOT NULL,
  author_role VARCHAR(255),
  author_company VARCHAR(255),
  author_avatar VARCHAR(500),
  content TEXT NOT NULL,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- FAQ Items
CREATE TABLE faq_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  question VARCHAR(500) NOT NULL,
  answer TEXT NOT NULL,
  category VARCHAR(100) DEFAULT 'geral',
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Users (Auth - perfis estendidos)
CREATE TABLE users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name VARCHAR(255),
  role VARCHAR(50) DEFAULT 'funcionario',
  status user_status DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Site Settings
CREATE TABLE site_settings (
  key VARCHAR(255) PRIMARY KEY,
  value TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- 3. INDEXES
-- =============================================

CREATE INDEX idx_jobs_status ON jobs(status);
CREATE INDEX idx_jobs_area ON jobs(area);
CREATE INDEX idx_jobs_modality ON jobs(modality);
CREATE INDEX idx_jobs_location ON jobs(location);
CREATE INDEX idx_jobs_company ON jobs(company_id);
CREATE INDEX idx_jobs_featured ON jobs(is_featured) WHERE is_featured = true;
CREATE INDEX idx_applications_job ON job_applications(job_id);
CREATE INDEX idx_applications_candidate ON job_applications(candidate_id);
CREATE INDEX idx_candidates_email ON candidates(email);

-- =============================================
-- 4. RLS POLICIES
-- =============================================

ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE candidates ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE recruitment_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE testimonials ENABLE ROW LEVEL SECURITY;
ALTER TABLE faq_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE site_settings ENABLE ROW LEVEL SECURITY;

-- Jobs: leitura pública
CREATE POLICY "Jobs are viewable by everyone" ON jobs FOR SELECT USING (true);
CREATE POLICY "Companies are viewable by everyone" ON companies FOR SELECT USING (true);
CREATE POLICY "Testimonials are viewable by everyone" ON testimonials FOR SELECT USING (true);
CREATE POLICY "FAQ are viewable by everyone" ON faq_items FOR SELECT USING (true);

-- Candidates: só o próprio candidato
CREATE POLICY "Candidates can view own profile" ON candidates FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Candidates can update own profile" ON candidates FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Anyone can insert candidates" ON candidates FOR INSERT WITH CHECK (true);

-- Job Applications
CREATE POLICY "Candidates can view own applications" ON job_applications FOR SELECT USING (
  candidate_id IN (SELECT id FROM candidates WHERE user_id = auth.uid())
);
CREATE POLICY "Anyone can insert applications" ON job_applications FOR INSERT WITH CHECK (true);

-- Recruitment Requests: qualquer um pode criar
CREATE POLICY "Anyone can insert recruitment requests" ON recruitment_requests FOR INSERT WITH CHECK (true);

-- Users
CREATE POLICY "Users can view own profile" ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Anyone can insert users" ON users FOR INSERT WITH CHECK (true);

-- =============================================
-- 5. TRIGGERS
-- =============================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, full_name, role, status)
  VALUES (NEW.id, NEW.raw_user_meta_data->>'full_name', 'funcionario', 'pending');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

CREATE TRIGGER set_companies_updated_at BEFORE UPDATE ON companies FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_jobs_updated_at BEFORE UPDATE ON jobs FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_candidates_updated_at BEFORE UPDATE ON candidates FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_job_applications_updated_at BEFORE UPDATE ON job_applications FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_recruitment_requests_updated_at BEFORE UPDATE ON recruitment_requests FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- =============================================
-- 6. SEED DATA - EMPRESAS
-- =============================================

INSERT INTO companies (name, slug, description, website, industry, company_size, founded_year, headquarters) VALUES
('TechX Solutions', 'techx-solutions', 'Empresa líder em soluções de tecnologia e inovação digital.', 'https://techx.com.br', 'Tecnologia', '200-500', 2015, 'São Paulo, SP'),
('MarketPro Digital', 'marketpro-digital', 'Agência de marketing digital de alto desempenho.', 'https://marketpro.com.br', 'Marketing', '50-100', 2018, 'São Paulo, SP'),
('FinanceHub Consulting', 'financehub', 'Consultoria financeira especializada em investimentos.', 'https://financehub.com.br', 'Financeiro', '100-200', 2012, 'Rio de Janeiro, RJ'),
('DataSoft Analytics', 'datasoft-analytics', 'Plataforma de análise de dados e inteligência artificial.', 'https://datasoft.com.br', 'Tecnologia', '100-200', 2017, 'Porto Alegre, RS'),
('RecruitHub RH', 'recruithub', 'Empresa de recrutamento e gestão de talentos.', 'https://recruithub.com.br', 'Recursos Humanos', '50-100', 2019, 'Belo Horizonte, MG'),
('ViaGroup Logística', 'viagroup-logistica', 'Logística e cadeia de suprimentos de ponta a ponta.', 'https://viagroup.com.br', 'Logística', '500-1000', 2008, 'Curitiba, PR'),
('SalesForce Brasil', 'salesforce-br', 'Representação comercial e vendas B2B.', 'https://salesforcebr.com.br', 'Vendas', '50-100', 2020, 'São Paulo, SP'),
('CreativeHub Design', 'creativehub', 'Estúdio de design e branding criativo.', 'https://creativehub.com.br', 'Design', '20-50', 2021, 'Florianópolis, SC'),
('GroupExpress Transportes', 'groupexpress', 'Transporte e logística expressa nacional.', 'https://groupexpress.com.br', 'Logística', '200-500', 2010, 'São Paulo, SP'),
('PeopleFirst RH', 'peoplefirst', 'Consultoria em gestão de pessoas e cultura organizacional.', 'https://peoplefirst.com.br', 'Recursos Humanos', '50-100', 2016, 'Rio de Janeiro, RJ'),
('AppWorks Mobile', 'appworks', 'Desenvolvimento de aplicativos mobile inovadores.', 'https://appworks.com.br', 'Tecnologia', '50-100', 2019, 'São Paulo, SP'),
('AgroTech Solutions', 'agrotech-solutions', 'Tecnologia aplicada ao agronegócio.', 'https://agrotech.com.br', 'Agronegócio', '100-200', 2014, 'Goiânia, GO');

-- =============================================
-- 7. SEED DATA - VAGAS
-- =============================================

INSERT INTO jobs (company_id, title, description, responsibilities, requirements, differentials, benefits, salary_min, salary_max, salary_display, location, modality, contract_type, experience_level, area, is_featured) VALUES
((SELECT id FROM companies WHERE slug = 'techx-solutions'), 'Desenvolvedor Full Stack', 'Estamos em busca de um(a) Desenvolvedor(a) Full Stack para integrar nosso time de tecnologia.', 'Desenvolver e manter aplicações web escaláveis com React e Node.js\nProjetar e implementar APIs RESTful e GraphQL\nColaborar com designers e product managers\nRealizar code review\nParticipar de discussões técnicas\nEscrever testes unitários e de integração\nMonitorar e otimizar performance', 'Experiência mínima de 3 anos com desenvolvimento web full stack\nDomínio de React, TypeScript e Node.js\nConhecimento em bancos de dados SQL e NoSQL\nExperiência com Git\nConhecimento em métodos ágeis\nBoa comunicação\nInglês técnico', 'Experiência com cloud services (AWS, Azure ou GCP)\nConhecimento em Docker e Kubernetes\nExperiência com CI/CD\nCertificações na área', 'Salário competitivo\nAuxílio home office\nPlano de saúde e odontológico\nVale-refeição\nPlano de desenvolvimento profissional\nFérias e folgas flexíveis', 8000, 12000, 'R$ 8.000 - R$ 12.000', 'Remoto', 'Remoto', 'CLT', 'Pleno', 'Tecnologia', true),

((SELECT id FROM companies WHERE slug = 'marketpro-digital'), 'Analista de Marketing Digital', 'Procuramos um(a) Analista de Marketing Digital para gerenciar nossas campanhas online.', 'Gerenciar campanhas de Google Ads e Meta Ads\nCriar conteúdo para redes sociais\nAnalisar métricas de performance\nOtimizar SEO e SEM\nGerenciar tráfego pago\nCriar relatórios semanais\nColaborar com o time de design', 'Experiência de 2+ anos em marketing digital\nDomínio de Google Analytics e Google Ads\nConhecimento em SEO\nExperiência com Meta Ads\nHabilidade com ferramentas de design\nBoa comunicação', 'Certificação Google Ads\nExperiência com marketing de conteúdo\nConhecimento em automação de marketing', 'Vale-refeição\nPlano de saúde\nHome office flexível\nBônus por resultados\nCapacitação contínua', 5000, 7000, 'R$ 5.000 - R$ 7.000', 'São Paulo', 'Hibrido', 'CLT', 'Pleno', 'Marketing', true),

((SELECT id FROM companies WHERE slug = 'financehub'), 'Consultor Financeiro', 'Buscamos um Consultor Financeiro experiente para assessores nossos clientes.', 'Assessorar clientes em investimentos\nAnalisar perfil de risco\nMontar portfólios personalizados\nRealizar reuniões de acompanhamento\nEmitir relatórios de performance\nAcompanhar mercado financeiro', 'Experiência mínima de 5 anos em consultoria financeira\nCVM ativa\nConhecimento em produtos financeiros\nBoa capacidade analítica', 'Experiência com planejamento patrimonial\nCertificações CFA ou similar', 'Comissões atrativas\nPlano de saúde\nAuxílio de transporte', 12000, 18000, 'R$ 12.000 - R$ 18.000', 'Rio de Janeiro', 'Presencial', 'PJ', 'Senior', 'Financeiro', true),

((SELECT id FROM companies WHERE slug = 'datasoft-analytics'), 'Cientista de Dados', 'Procuramos um(a) Cientista de Dados para extrair insights valiosos dos nossos dados.', 'Desenvolver modelos preditivos\nAnalisar grandes volumes de dados\nCriar dashboards interativos\nColaborar com times de produto\nAutomatizar processos de dados\nPesquisar novas técnicas de ML', 'Experiência com Python e R\nDomínio de SQL\nConhecimento em Machine Learning\nExperiência com ferramentas de visualização\nFormação em áreas quantitativas', 'Experiência com Spark e Big Data\nMestrado ou Doutorado\nCertificações em cloud', 'Salário competitivo\n100% home office\nFlexibilidade de horário\nPlano de saúde', 10000, 15000, 'R$ 10.000 - R$ 15.000', 'Remoto', 'Remoto', 'CLT', 'Pleno', 'Tecnologia', true),

((SELECT id FROM companies WHERE slug = 'recruithub'), 'Coordenador(a) de RH', 'Buscamos um(a) Coordenador(a) de RH para liderar nosso departamento.', 'Coordenar processo de recrutamento e seleção\nGerenciar time de RH\nDesenvolver programas de treinamento\nGerenciar folha de pagamento\nCuidar do clima organizacional\nImplementar políticas de RH', 'Experiência de 5+ anos em RH\nExperiência em liderança de equipes\nConhecimento em legislação trabalhista\nGraduação em RH ou Administração', 'MBA em RH\nExperiência com people analytics\nCertificações em RH', 'Plano de saúde e odontológico\nVale-alimentação\nParticipação nos lucros', 8500, 11000, 'R$ 8.500 - R$ 11.000', 'Belo Horizonte', 'Hibrido', 'CLT', 'Senior', 'Recursos Humanos', false),

((SELECT id FROM companies WHERE slug = 'viagroup-logistica'), 'Gerente de Operações', 'Procuramos um Gerente de Operações para liderar nossa logística.', 'Gerenciar operações logísticas\nOtimizar processos de supply chain\nLiderar equipe de operações\nControlar custos operacionais\nImplementar indicadores de performance\nGarantir qualidade do serviço', 'Experiência de 7+ anos em operações/logística\nExperiência em liderança\nConhecimento em lean manufacturing\nGraduação em Engenharia ou Administração', 'MBA em Gestão de Operações\nExperiência com ERP\nCertificações lean', 'PLR\nPlano de saúde premium\nAuxílio alimentação', 11000, 16000, 'R$ 11.000 - R$ 16.000', 'Curitiba', 'Presencial', 'CLT', 'Senior', 'Operações', false),

((SELECT id FROM companies WHERE slug = 'salesforce-br'), 'Executivo(a) de Vendas', 'Buscamos um(a) Executivo(a) de Vendas para expandir nosso mercado.', 'Prospecar novos clientes\nRealizar reuniões de apresentação\nNegociar contratos\nAtingir metas de vendas\nManter relacionamento com clientes\nAtualizar CRM', 'Experiência de 2+ anos em vendas B2B\nBoa comunicação\nProatividade\nMeta-driven', 'Experiência no segmento de tecnologia\nConhecimento em vendas consultivas', 'Comissão sobre vendas\nPlano de saúde\nAjuda de custos', 6000, 9000, 'R$ 6.000 - R$ 9.000', 'São Paulo', 'Presencial', 'CLT', 'Pleno', 'Vendas', false),

((SELECT id FROM companies WHERE slug = 'creativehub'), 'UX/UI Designer', 'Procuramos um(a) UX/UI Designer para criar experiências incríveis.', 'Projetar interfaces de usuário\nCriar wireframes e protótipos\nRealizar pesquisas de usabilidade\nColaborar com desenvolvedores\nManter design system\nApresentar soluções para stakeholders', 'Experiência de 3+ anos em UX/UI\nDomínio de Figma\nConhecimento em HTML/CSS\nPortfólio comprovado', 'Experiência com Design Thinking\nConhecimento em acessibilidade\nExperiência com apps mobile', 'Trabalho 100% remoto\nHorário flexível\nEquipamento fornecido', 7000, 10000, 'R$ 7.000 - R$ 10.000', 'Remoto', 'Remoto', 'PJ', 'Pleno', 'Tecnologia', true),

((SELECT id FROM companies WHERE slug = 'groupexpress'), 'Auxiliar Administrativo', 'Buscamos um Auxiliar Administrativo para nosso escritório.', 'Controlar agenda de reuniões\nOrganizar documentos\nAtender telefones e e-mails\nPreparar relatórios\nOrganizar arquivo\nApoiar setor financeiro', 'Ensino médio completo\nExperiência em rotinas administrativas\nDomínio do pacote Office\nOrganização e proatividade', 'Curso técnico em administração\nExperiência em empresas de logística', 'Vale-refeição\nPlano de saúde\nVale-transporte', 2500, 3500, 'R$ 2.500 - R$ 3.500', 'Belo Horizonte', 'Presencial', 'CLT', 'Junior', 'Operações', false),

((SELECT id FROM companies WHERE slug = 'techx-solutions'), 'Estagiário de Tecnologia', 'Oportunidade de estágio para estudantes de TI.', 'Apoiar time de desenvolvimento\nAprender novas tecnologias\nParticipar de projetos reais\nDesenvolver habilidades técnicas', 'Estar cursando Ciência da Computação ou similar\nConhecimentos básicos de programação\nVontade de aprender', 'Conhecimento de HTML/CSS/JS\nExperiência com Git', 'Bolsa estágio\nVale-refeição\nMentoria profissional', 1800, 2200, 'R$ 1.800 - R$ 2.200', 'São Paulo', 'Hibrido', 'Estagio', 'Estagio', 'Tecnologia', false),

((SELECT id FROM companies WHERE slug = 'peoplefirst'), 'Analista de RH', 'Procuramos um(a) Analista de RH para nosso time.', 'Apoiar processos de recrutamento\nOrganizar treinamentos\nControlar absenteísmo\nGerenciar benefícios\nCuidar da experiência do colaborador\nElaborar relatórios de RH', 'Experiência de 2+ anos em RH\nGraduação em RH ou Psicologia\nConhecimento em legislação trabalhista', 'Experiência com sistemas de RH\nCertificações em gestão de pessoas', 'Plano de saúde\nVale-refeição\nHome office', 5500, 7500, 'R$ 5.500 - R$ 7.500', 'Rio de Janeiro', 'Hibrido', 'CLT', 'Pleno', 'Recursos Humanos', false),

((SELECT id FROM companies WHERE slug = 'appworks'), 'Desenvolvedor Mobile', 'Buscamos um(a) Desenvolvedor(a) Mobile para criar apps incríveis.', 'Desenvolver apps React Native/Flutter\nPublicar nas lojas (App Store/Play Store)\nIntegrar APIs REST\nOtimizar performance\nCorrigir bugs\nColaborar com time de design', 'Experiência de 4+ anos em mobile\nDomínio de React Native ou Flutter\nExperiência com publicação de apps\nConhecimento em CI/CD', 'Experiência com apps financeiros\nConhecimento em testes automatizados\nPublicações na App Store', 'Salário competitivo\n100% remoto\nFlexibilidade total\nEquipamento fornecido', 10000, 14000, 'R$ 10.000 - R$ 14.000', 'Remoto', 'Remoto', 'PJ', 'Senior', 'Tecnologia', true);

-- =============================================
-- 8. SEED DATA - DEPOIMENTOS
-- =============================================

INSERT INTO testimonials (author_name, author_role, author_company, content, rating) VALUES
('Ana Carolina Silva', 'Diretora de RH', 'TechX Solutions', 'O Conecta RH revolucionou nosso processo de recrutamento. Reduzimos o tempo de contratação em 60% e encontramos profissionais incríveis.', 5),
('Marcos Oliveira', 'CEO', 'MarketPro Digital', 'Plataforma incrível! Conseguimos contratar 5 profissionais em apenas 2 semanas. O suporte é excepcional.', 5),
('Juliana Santos', 'Candidata', 'Contratada via plataforma', 'Encontrei minha vaga dos sonhos pelo Conecta RH. Processo rápido e profissional. Super recomendo!', 5),
('Pedro Henrique Costa', 'Gerente de Contratações', 'FinanceHub', 'A qualidade dos candidatos que recebemos é impressionante. O sistema de filtragem é muito eficiente.', 4),
('Fernanda Lima', 'Empreendedora', 'Startup própria', 'Como empreendedora, o Conecta RH me ajudou a montar meu time rapidamente. Ferramenta indispensável!', 5);

-- =============================================
-- 9. SEED DATA - FAQ
-- =============================================

INSERT INTO faq_items (question, answer, category, sort_order) VALUES
('Como me candidatar a uma vaga?', 'Basta acessar a página da vaga desejada, preencher o formulário de candidatura com seus dados e enviar seu currículo. Você receberá uma confirmação por e-mail.', 'candidato', 1),
('Preciso pagar para me candidatar?', 'Não! O Conecta RH é totalmente gratuito para candidatos. Você pode se candidatar a quantas vagas quiser.', 'candidato', 2),
('Como acompanhar minhas candidaturas?', 'Após se candidatar, você pode acessar a área do candidato com seu e-mail e senha para acompanhar o status de todas as suas candidaturas.', 'candidato', 3),
('Como funciona o recrutamento exclusivo?', 'No recrutamento exclusivo, nossa equipe analisa seu perfil e apresenta oportunidades compatíveis com sua experiência e objetivos de carreira.', 'candidato', 4),
('Quanto custa para divulgar uma vaga?', 'Temos planos a partir de R$ 197/mês para divulgação de vagas. Consulte nossa tabela de preços para mais detalhes.', 'empresa', 5),
('Qual o prazo para receber candidaturas?', 'As primeiras candidaturas costumam chegar em até 48 horas após a publicação da vaga, dependendo da área e região.', 'empresa', 6),
('Vocês fazem triagem dos candidatos?', 'Sim! Nossa inteligência artificial e equipe realizam a triagem inicial, apresentando apenas os candidatos mais qualificados para sua vaga.', 'empresa', 7),
('É possível contratar os serviços de recrutamento e seleção?', 'Sim! Oferecemos serviço completo de R&S com equipe especializada. Entre em contato para um orçamento personalizado.', 'empresa', 8),
('Quais são as formas de pagamento?', 'Aceitamos cartão de crédito, boleto bancário e PIX. Planos anuais possuem desconto especial.', 'empresa', 9),
('Como entro em contato com o suporte?', 'Você pode nos contatar pelo e-mail suporte@conectarh.com.br ou pelo WhatsApp +55 31 7578-7604. Nosso horário de atendimento é de segunda a sexta, das 8h às 18h.', 'geral', 10);

-- =============================================
-- 10. STORAGE BUCKET
-- =============================================

-- Criar bucket para currículos (rodar no dashboard ou via SQL)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('resumes', 'resumes', false, 5242880, ARRAY['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document']);
