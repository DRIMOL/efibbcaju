#!/bin/bash

# Script de instalação do webhook EFI Bank
# Este script configura automaticamente o ambiente para o webhook EFI Bank

# Cores para melhor visualização
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Função para exibir mensagens
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

# Função para verificar se o comando foi executado com sucesso
check_success() {
    if [ $? -eq 0 ]; then
        print_message "$1"
    else
        print_error "$2"
        exit 1
    fi
}

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then
    print_warning "Este script precisa ser executado como root (sudo)."
    print_warning "Execute novamente com: sudo ./install.sh"
    exit 1
fi

# Determinar o usuário para instalação
if [ -n "$SUDO_USER" ]; then
    INSTALL_USER=$SUDO_USER
    print_message "Instalando para o usuário: $INSTALL_USER"
else
    INSTALL_USER="root"
    print_message "Instalando como usuário root"
fi

# Início da instalação
print_message "Iniciando a instalação do webhook EFI Bank..."
print_message "Verificando pré-requisitos..."

# Verificar se o Ubuntu é versão 20.04
if ! grep -q "Ubuntu 20.04" /etc/os-release; then
    print_warning "Este script foi projetado para Ubuntu 20.04."
    read -p "Deseja continuar mesmo assim? (s/n): " continue_anyway
    if [ "$continue_anyway" != "s" ]; then
        print_message "Instalação cancelada."
        exit 0
    fi
fi

# Atualizar repositórios
print_message "Atualizando repositórios..."
apt update
check_success "Repositórios atualizados com sucesso." "Falha ao atualizar repositórios."

# Instalar dependências
print_message "Instalando dependências..."
apt install -y apt-transport-https ca-certificates curl software-properties-common git
check_success "Dependências instaladas com sucesso." "Falha ao instalar dependências."

# Verificar se o Docker já está instalado
if command -v docker &> /dev/null; then
    print_message "Docker já está instalado."
else
    # Instalar Docker
    print_message "Instalando Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt update
    apt install -y docker-ce
    check_success "Docker instalado com sucesso." "Falha ao instalar Docker."
fi

# Verificar se o Docker Compose já está instalado
if command -v docker-compose &> /dev/null; then
    print_message "Docker Compose já está instalado."
else
    # Instalar Docker Compose
    print_message "Instalando Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    check_success "Docker Compose instalado com sucesso." "Falha ao instalar Docker Compose."
fi

# Adicionar usuário ao grupo docker (apenas se não for root)
if [ "$INSTALL_USER" != "root" ]; then
    print_message "Adicionando usuário ao grupo docker..."
    usermod -aG docker $INSTALL_USER
    check_success "Usuário adicionado ao grupo docker." "Falha ao adicionar usuário ao grupo docker."
else
    print_message "Usuário root já tem permissões para Docker."
fi

# Criar diretório do projeto
print_message "Configurando o projeto..."

# Determinar o diretório do projeto
if [ "$INSTALL_USER" = "root" ]; then
    PROJECT_DIR="/root/efybank"
else
    PROJECT_DIR="/home/$INSTALL_USER/efybank"
fi

print_message "Diretório do projeto: $PROJECT_DIR"

# Verificar se o diretório já existe
if [ -d "$PROJECT_DIR" ]; then
    print_warning "O diretório $PROJECT_DIR já existe."
    read -p "Deseja remover e recriar? (s/n): " recreate_dir
    if [ "$recreate_dir" = "s" ]; then
        rm -rf "$PROJECT_DIR"
    else
        print_warning "Usando o diretório existente."
    fi
fi

# Clonar o repositório se o diretório não existir
if [ ! -d "$PROJECT_DIR" ]; then
    print_message "Clonando o repositório do GitHub..."
    if [ "$INSTALL_USER" = "root" ]; then
        git clone https://github.com/DRIMOL/efibbcaju.git $PROJECT_DIR
    else
        su - $INSTALL_USER -c "git clone https://github.com/DRIMOL/efibbcaju.git ~/efybank"
    fi
    check_success "Repositório clonado com sucesso." "Falha ao clonar o repositório."
fi

# Criar estrutura de diretórios
print_message "Criando estrutura de diretórios..."
if [ "$INSTALL_USER" = "root" ]; then
    mkdir -p $PROJECT_DIR/certs $PROJECT_DIR/logs/nginx $PROJECT_DIR/logs/php
else
    su - $INSTALL_USER -c "mkdir -p ~/efybank/certs ~/efybank/logs/nginx ~/efybank/logs/php"
fi
check_success "Estrutura de diretórios criada com sucesso." "Falha ao criar estrutura de diretórios."

# Baixar certificados
print_message "Baixando certificados da EFI Bank..."
if [ "$INSTALL_USER" = "root" ]; then
    cd $PROJECT_DIR/certs && curl -o certificate-chain-prod.crt https://certificados.efipay.com.br/webhooks/certificate-chain-prod.crt
else
    su - $INSTALL_USER -c "cd ~/efybank/certs && curl -o certificate-chain-prod.crt https://certificados.efipay.com.br/webhooks/certificate-chain-prod.crt"
fi
check_success "Certificado de produção baixado com sucesso." "Falha ao baixar certificado de produção."

# Gerar certificados autoassinados para testes
print_message "Gerando certificados SSL autoassinados para testes..."
if [ "$INSTALL_USER" = "root" ]; then
    cd $PROJECT_DIR/certs && openssl genrsa -out server.key 2048 && openssl req -new -x509 -key server.key -out server.crt -days 365 -subj '/CN=localhost'
else
    su - $INSTALL_USER -c "cd ~/efybank/certs && openssl genrsa -out server.key 2048 && openssl req -new -x509 -key server.key -out server.crt -days 365 -subj '/CN=localhost'"
fi
check_success "Certificados SSL gerados com sucesso." "Falha ao gerar certificados SSL."

# Ajustar permissões dos certificados
print_message "Ajustando permissões dos certificados..."
if [ "$INSTALL_USER" = "root" ]; then
    chmod 644 $PROJECT_DIR/certs/server.crt $PROJECT_DIR/certs/certificate-chain-prod.crt && chmod 600 $PROJECT_DIR/certs/server.key
else
    su - $INSTALL_USER -c "chmod 644 ~/efybank/certs/server.crt ~/efybank/certs/certificate-chain-prod.crt && chmod 600 ~/efybank/certs/server.key"
fi
check_success "Permissões dos certificados ajustadas com sucesso." "Falha ao ajustar permissões dos certificados."

# Iniciar os contêineres Docker
print_message "Iniciando os contêineres Docker..."
if [ "$INSTALL_USER" = "root" ]; then
    cd $PROJECT_DIR && docker-compose up -d
else
    su - $INSTALL_USER -c "cd ~/efybank && docker-compose up -d"
fi
check_success "Contêineres Docker iniciados com sucesso." "Falha ao iniciar contêineres Docker."

# Configurar o firewall
print_message "Configurando o firewall..."
if command -v ufw &> /dev/null; then
    ufw allow ssh
    ufw allow 443/tcp
    ufw --force enable
    check_success "Firewall configurado com sucesso." "Falha ao configurar o firewall."
else
    print_warning "UFW não está instalado. Pulando configuração do firewall."
fi

# Exibir informações finais
print_message "Instalação concluída com sucesso!"
print_message "O webhook está disponível em: https://localhost/webhook"
print_message "Para verificar o status dos contêineres: docker-compose -f $PROJECT_DIR/docker-compose.yml ps"
print_message "Para verificar os logs: docker-compose -f $PROJECT_DIR/docker-compose.yml logs"

if [ "$INSTALL_USER" != "root" ]; then
    print_warning "IMPORTANTE: Você precisa fazer logout e login novamente para que as alterações do grupo docker tenham efeito."
fi

print_warning "Para um ambiente de produção, configure certificados SSL válidos e atualize o arquivo nginx-webhook.conf."
