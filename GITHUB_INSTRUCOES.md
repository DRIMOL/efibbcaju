# Instruções para GitHub e Implantação no Ubuntu

Este documento contém instruções para enviar o projeto para o GitHub específico (https://github.com/MakeToMe/efybank.git) e depois fazer o clone na VM Ubuntu 20.04 que já está instalada.

## 1. Enviar o Projeto para o GitHub

### 1.1. No Windows (Máquina Local)

```powershell
# Navegar para a pasta do projeto
cd c:\Users\User\CascadeProjects\efybank

# Inicializar um repositório Git
git init

# Criar um arquivo .gitignore
echo "certs/*" > .gitignore
echo "logs/*" >> .gitignore
echo "!certs/.gitkeep" >> .gitignore
echo "!logs/.gitkeep" >> .gitignore
echo "!logs/nginx/.gitkeep" >> .gitignore
echo "!logs/php/.gitkeep" >> .gitignore

# Criar arquivos .gitkeep para manter a estrutura de diretórios
mkdir -p certs logs/nginx logs/php
echo "" > certs/.gitkeep
echo "" > logs/.gitkeep
echo "" > logs/nginx/.gitkeep
echo "" > logs/php/.gitkeep

# Adicionar todos os arquivos ao controle de versão
git add .

# Fazer o primeiro commit
git commit -m "Versão inicial do webhook EFI Bank"

# Adicionar o repositório remoto
git remote add origin https://github.com/MakeToMe/efybank.git

# Enviar para o GitHub
git push -u origin master
```

## 2. Clonar e Configurar o Projeto na VM Ubuntu

### 2.1. Clonar o Repositório

```bash
# Navegar para o diretório home
cd ~

# Clonar o repositório
git clone https://github.com/MakeToMe/efybank.git efybank

# Navegar para a pasta do projeto
cd efybank

# Criar a estrutura de diretórios necessária
mkdir -p certs logs/nginx logs/php
```

### 2.2. Baixar os Certificados

```bash
# Navegar para a pasta de certificados
cd ~/efybank/certs

# Baixar o certificado de produção da EFI Bank
curl -o certificate-chain-prod.crt https://certificados.efipay.com.br/webhooks/certificate-chain-prod.crt

# Ou, para ambiente de homologação
curl -o certificate-chain-homolog.crt https://certificados.efipay.com.br/webhooks/certificate-chain-homolog.crt
```

### 2.3. Gerar Certificados SSL para Testes

```bash
# Navegar para a pasta de certificados
cd ~/efybank/certs

# Gerar uma chave privada
openssl genrsa -out server.key 2048

# Gerar um certificado autoassinado (válido por 365 dias)
openssl req -new -x509 -key server.key -out server.crt -days 365 -subj "/CN=localhost"
```

### 2.4. Configurar o Nginx

```bash
# Navegar para a pasta do projeto
cd ~/efybank

# Editar o arquivo de configuração do Nginx
nano nginx-webhook.conf
```

Modifique as seguintes linhas para apontar para seus certificados:

```nginx
# Substitua estas linhas
ssl_certificate /path/to/your/certificate.crt;
ssl_certificate_key /path/to/your/private.key;
ssl_client_certificate /path/to/efi/certificate-chain-prod.crt;

# Para algo como isso (para ambiente de teste local)
ssl_certificate /etc/nginx/certs/server.crt;
ssl_certificate_key /etc/nginx/certs/server.key;
ssl_client_certificate /etc/nginx/certs/certificate-chain-prod.crt;
```

### 2.5. Iniciar os Contêineres Docker

```bash
# Navegar para a pasta do projeto
cd ~/efybank

# Construir e iniciar os contêineres em segundo plano
docker-compose up -d
```

## 3. Verificar a Instalação

```bash
# Verificar se os contêineres estão em execução
docker-compose ps

# Verificar logs
docker-compose logs

# Testar o webhook (isso deve falhar com erro 403 devido à verificação mTLS)
curl -k -X POST https://localhost/webhook -d '{"teste": true}'
```

## 4. Configuração para Produção

Para configurar o ambiente de produção, siga as instruções na seção 7 do arquivo GUIA_INSTALACAO.md.

## 5. Atualizar o Projeto

Se você fizer alterações no repositório GitHub, você pode atualizar a instalação na VM Ubuntu:

```bash
# Navegar para a pasta do projeto
cd ~/efybank

# Parar os contêineres
docker-compose down

# Puxar as alterações mais recentes do GitHub
git pull

# Reconstruir e iniciar os contêineres
docker-compose up -d --build
```
