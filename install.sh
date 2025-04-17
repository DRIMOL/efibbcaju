#!/bin/bash
# Script de instalação automatizada para o EFI Bank Webhook
# Este script configura o ambiente necessário para o webhook do EFI Bank

# Cores para saída no terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Função para exibir mensagens
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

# Verificar se está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    error "Este script precisa ser executado como root (sudo)."
    exit 1
fi

# Verificar se é Ubuntu 20.04
if [ ! -f /etc/os-release ] || ! grep -q 'VERSION="20.04' /etc/os-release; then
    warn "Este script foi projetado para Ubuntu 20.04. A execução em outros sistemas pode causar problemas."
    read -p "Deseja continuar mesmo assim? (s/n): " choice
    if [ "$choice" != "s" ]; then
        error "Instalação cancelada."
        exit 1
    fi
fi

log "Iniciando instalação do EFI Bank Webhook..."

# Atualizar repositórios e pacotes
log "Atualizando repositórios e pacotes..."
apt-get update
apt-get upgrade -y

# Instalar dependências
log "Instalando dependências..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    nginx \
    php7.4-fpm \
    php7.4-curl \
    php7.4-json \
    php7.4-common \
    certbot \
    python3-certbot-nginx \
    git

# Verificar se Docker já está instalado
if ! command -v docker &> /dev/null; then
    log "Instalando Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
else
    log "Docker já está instalado."
fi

# Verificar se Docker Compose já está instalado
if ! command -v docker-compose &> /dev/null; then
    log "Instalando Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    log "Docker Compose já está instalado."
fi

# Criar diretórios necessários
log "Criando diretórios..."
mkdir -p /etc/efibank/certs
mkdir -p /var/log/efibank
mkdir -p /var/www/efibank/www

# Baixar certificado da EFI Bank
log "Baixando certificado da EFI Bank..."
curl -o /etc/efibank/certs/certificate-chain-prod.crt https://certificados.efipay.com.br/webhooks/certificate-chain-prod.crt

# Verificar se o certificado foi baixado com sucesso
if [ ! -f /etc/efibank/certs/certificate-chain-prod.crt ]; then
    error "Falha ao baixar o certificado da EFI Bank. Verifique sua conexão com a internet."
    exit 1
fi

# Copiar arquivos do projeto
log "Copiando arquivos do projeto..."
cp -r www/* /var/www/efibank/www/
cp nginx-webhook.conf /etc/nginx/sites-available/bb.bcaju.com.br.conf

# Habilitar o site no Nginx
ln -sf /etc/nginx/sites-available/bb.bcaju.com.br.conf /etc/nginx/sites-enabled/

# Verificar configuração do Nginx
nginx -t
if [ $? -ne 0 ]; then
    error "Configuração do Nginx inválida. Verifique o arquivo nginx-webhook.conf."
    exit 1
fi

# Perguntar se deseja obter certificado SSL com Certbot
read -p "Deseja obter um certificado SSL para bb.bcaju.com.br usando Certbot? (s/n): " choice
if [ "$choice" = "s" ]; then
    log "Obtendo certificado SSL com Certbot..."
    certbot --nginx -d bb.bcaju.com.br
    
    # Copiar certificados para o diretório do EFI Bank
    cp /etc/letsencrypt/live/bb.bcaju.com.br/fullchain.pem /etc/efibank/certs/server_ssl.crt.pem
    cp /etc/letsencrypt/live/bb.bcaju.com.br/privkey.pem /etc/efibank/certs/server_ssl.key.pem
else
    warn "Você optou por não obter um certificado SSL automaticamente."
    warn "Você precisará configurar manualmente os certificados SSL em /etc/efibank/certs/"
fi

# Configurar permissões
log "Configurando permissões..."
chown -R www-data:www-data /var/www/efibank
chmod -R 755 /var/www/efibank

# Reiniciar serviços
log "Reiniciando serviços..."
systemctl restart php7.4-fpm
systemctl restart nginx

log "Instalação concluída com sucesso!"
log "Seu webhook está configurado em: https://bb.bcaju.com.br/"
log "Verifique os logs em: /var/log/efibank/webhook.log"

# Instruções finais
echo ""
echo "============================================================"
echo "                  PRÓXIMOS PASSOS                          "
echo "============================================================"
echo "1. Verifique se o domínio bb.bcaju.com.br está apontando para este servidor"
echo "2. Certifique-se de que os certificados SSL estão configurados corretamente"
echo "3. Teste o webhook usando o comando:"
echo "   curl -k --cert /etc/efibank/certs/certificate-chain-prod.crt https://bb.bcaju.com.br/"
echo "4. Configure o webhook na EFI Bank usando a URL: https://bb.bcaju.com.br/"
echo "============================================================"
