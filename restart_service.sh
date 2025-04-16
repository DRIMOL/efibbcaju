#!/bin/bash

# Script para reiniciar o serviço de webhook

echo "=== Reiniciando o serviço de webhook ==="
echo

# Criar diretórios de logs se não existirem
echo "Criando diretórios de logs..."
mkdir -p logs/nginx logs/php
chmod -R 777 logs

# Verificar se os certificados existem
echo "Verificando certificados..."
if [ ! -f "./certs/server.crt" ] || [ ! -f "./certs/server.key" ] || [ ! -f "./certs/certificate-chain-prod.crt" ]; then
  echo "AVISO: Alguns certificados podem estar faltando. Execute ./check_certs.sh para mais detalhes."
fi

# Parar os containers
echo "Parando containers..."
docker-compose down

# Remover logs antigos (opcional)
echo "Limpando logs antigos..."
rm -f logs/nginx/*.log logs/php/*.log

# Iniciar os containers
echo "Iniciando containers..."
docker-compose up -d

# Verificar status
echo "Verificando status dos containers..."
docker-compose ps

echo
echo "=== Serviço reiniciado ==="
echo "Para verificar os logs, execute: docker-compose logs -f"
echo "Para testar o webhook, acesse: https://bb.bcaju.com.br/webhook?test=true"
