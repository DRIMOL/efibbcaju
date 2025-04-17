#!/bin/bash
# Script para reiniciar os serviços do EFI Bank Webhook
# Este script reinicia os serviços Nginx e PHP-FPM

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

# Verificar se os serviços estão instalados
if ! command -v nginx &> /dev/null; then
    error "Nginx não está instalado. Execute o script install.sh primeiro."
    exit 1
fi

if ! command -v php-fpm7.4 &> /dev/null && ! command -v php-fpm &> /dev/null; then
    error "PHP-FPM não está instalado. Execute o script install.sh primeiro."
    exit 1
fi

# Verificar se estamos usando Docker
if [ -f /Users/diegolima/Documents/efibank/docker-compose.yml ]; then
    log "Detectado ambiente Docker. Reiniciando contêineres..."
    cd /Users/diegolima/Documents/efibank
    docker-compose down
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        log "Contêineres Docker reiniciados com sucesso."
    else
        error "Falha ao reiniciar os contêineres Docker."
        exit 1
    fi
else
    # Reiniciar serviços no sistema
    log "Reiniciando serviço PHP-FPM..."
    systemctl restart php7.4-fpm
    
    if [ $? -eq 0 ]; then
        log "Serviço PHP-FPM reiniciado com sucesso."
    else
        error "Falha ao reiniciar o serviço PHP-FPM."
        exit 1
    fi
    
    log "Reiniciando serviço Nginx..."
    systemctl restart nginx
    
    if [ $? -eq 0 ]; then
        log "Serviço Nginx reiniciado com sucesso."
    else
        error "Falha ao reiniciar o serviço Nginx."
        exit 1
    fi
fi

# Verificar status dos serviços
if [ -f /Users/diegolima/Documents/efibank/docker-compose.yml ]; then
    log "Status dos contêineres Docker:"
    docker-compose ps
else
    log "Status do serviço PHP-FPM:"
    systemctl status php7.4-fpm --no-pager
    
    echo ""
    
    log "Status do serviço Nginx:"
    systemctl status nginx --no-pager
fi

# Verificar se o webhook está acessível
log "Verificando se o webhook está acessível..."
if command -v curl &> /dev/null; then
    response=$(curl -s -o /dev/null -w "%{http_code}" -k https://bb.bcaju.com.br/ 2>/dev/null)
    
    if [ "$response" = "403" ]; then
        log "Webhook está acessível e exigindo certificado mTLS (código 403). Isso é esperado."
    elif [ "$response" = "000" ]; then
        warn "Não foi possível conectar ao webhook. Verifique se o domínio está configurado corretamente."
    else
        warn "Webhook retornou código inesperado: $response"
    fi
else
    warn "Comando curl não encontrado. Não é possível verificar a acessibilidade do webhook."
fi

log "Reinicialização dos serviços concluída."
