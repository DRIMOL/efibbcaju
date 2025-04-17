#!/bin/bash
# Script para verificar os certificados do EFI Bank Webhook
# Este script verifica a validade dos certificados SSL e da EFI Bank

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

# Verificar certificado do servidor
log "Verificando certificado SSL do servidor..."
if [ -f /etc/efibank/certs/server_ssl.crt.pem ]; then
    # Obter data de expiração
    expiry_date=$(openssl x509 -enddate -noout -in /etc/efibank/certs/server_ssl.crt.pem | cut -d= -f2)
    expiry_epoch=$(date -d "$expiry_date" +%s)
    current_epoch=$(date +%s)
    days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    if [ $days_left -lt 0 ]; then
        error "O certificado SSL do servidor EXPIROU há $((-days_left)) dias!"
    elif [ $days_left -lt 30 ]; then
        warn "O certificado SSL do servidor irá expirar em $days_left dias."
    else
        log "O certificado SSL do servidor é válido por mais $days_left dias."
    fi
    
    # Mostrar informações do certificado
    log "Informações do certificado SSL do servidor:"
    openssl x509 -text -noout -in /etc/efibank/certs/server_ssl.crt.pem | grep -E "Subject:|Issuer:|Not Before:|Not After :"
else
    error "Certificado SSL do servidor não encontrado em /etc/efibank/certs/server_ssl.crt.pem"
fi

echo ""

# Verificar certificado da EFI Bank
log "Verificando certificado da EFI Bank..."
if [ -f /etc/efibank/certs/certificate-chain-prod.crt ]; then
    # Obter data de expiração
    expiry_date=$(openssl x509 -enddate -noout -in /etc/efibank/certs/certificate-chain-prod.crt | cut -d= -f2)
    expiry_epoch=$(date -d "$expiry_date" +%s)
    current_epoch=$(date +%s)
    days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    if [ $days_left -lt 0 ]; then
        error "O certificado da EFI Bank EXPIROU há $((-days_left)) dias!"
        warn "É necessário baixar um novo certificado em: https://certificados.efipay.com.br/webhooks/certificate-chain-prod.crt"
    elif [ $days_left -lt 30 ]; then
        warn "O certificado da EFI Bank irá expirar em $days_left dias."
    else
        log "O certificado da EFI Bank é válido por mais $days_left dias."
    fi
    
    # Mostrar informações do certificado
    log "Informações do certificado da EFI Bank:"
    openssl x509 -text -noout -in /etc/efibank/certs/certificate-chain-prod.crt | grep -E "Subject:|Issuer:|Not Before:|Not After :"
else
    error "Certificado da EFI Bank não encontrado em /etc/efibank/certs/certificate-chain-prod.crt"
    log "Baixando certificado da EFI Bank..."
    mkdir -p /etc/efibank/certs
    curl -o /etc/efibank/certs/certificate-chain-prod.crt https://certificados.efipay.com.br/webhooks/certificate-chain-prod.crt
    
    if [ $? -eq 0 ]; then
        log "Certificado da EFI Bank baixado com sucesso."
    else
        error "Falha ao baixar o certificado da EFI Bank."
    fi
fi

echo ""

# Testar configuração mTLS
log "Testando configuração mTLS..."
if [ -f /etc/efibank/certs/certificate-chain-prod.crt ] && [ -f /etc/efibank/certs/server_ssl.crt.pem ]; then
    log "Realizando teste de conexão mTLS para bb.bcaju.com.br..."
    
    # Verificar se o domínio está configurado localmente
    if grep -q "bb.bcaju.com.br" /etc/hosts; then
        curl_output=$(curl -s -o /dev/null -w "%{http_code}" -k --cert /etc/efibank/certs/certificate-chain-prod.crt https://bb.bcaju.com.br/)
        
        if [ "$curl_output" = "200" ]; then
            log "Teste de conexão mTLS bem-sucedido! Código de resposta: 200"
        else
            warn "Teste de conexão mTLS retornou código: $curl_output"
        fi
    else
        warn "O domínio bb.bcaju.com.br não está configurado em /etc/hosts. Não é possível testar localmente."
        warn "Adicione a seguinte linha ao arquivo /etc/hosts para testar localmente:"
        warn "127.0.0.1 bb.bcaju.com.br"
    fi
else
    error "Não é possível testar a configuração mTLS sem os certificados necessários."
fi

echo ""
log "Verificação de certificados concluída."