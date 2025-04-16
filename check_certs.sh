#!/bin/bash

# Script para verificar os certificados SSL e mTLS

echo "=== Verificando certificados SSL e mTLS ==="
echo

# Verificar se os certificados existem
echo "Verificando existência dos certificados..."
CERT_DIR="./certs"
SERVER_CERT="$CERT_DIR/server.crt"
SERVER_KEY="$CERT_DIR/server.key"
EFI_CERT="$CERT_DIR/certificate-chain-prod.crt"

if [ ! -f "$SERVER_CERT" ]; then
  echo "ERRO: Certificado do servidor não encontrado em $SERVER_CERT"
else
  echo "OK: Certificado do servidor encontrado"
fi

if [ ! -f "$SERVER_KEY" ]; then
  echo "ERRO: Chave privada do servidor não encontrada em $SERVER_KEY"
else
  echo "OK: Chave privada do servidor encontrada"
fi

if [ ! -f "$EFI_CERT" ]; then
  echo "ERRO: Certificado da EFI Bank não encontrado em $EFI_CERT"
else
  echo "OK: Certificado da EFI Bank encontrado"
fi

echo

# Verificar informações do certificado do servidor
if [ -f "$SERVER_CERT" ]; then
  echo "=== Informações do certificado do servidor ==="
  openssl x509 -in "$SERVER_CERT" -text -noout | grep -E "Subject:|Issuer:|Not Before:|Not After :|DNS:"
  echo
fi

# Verificar informações do certificado da EFI Bank
if [ -f "$EFI_CERT" ]; then
  echo "=== Informações do certificado da EFI Bank ==="
  openssl x509 -in "$EFI_CERT" -text -noout | grep -E "Subject:|Issuer:|Not Before:|Not After :"
  echo
fi

# Verificar permissões dos arquivos
echo "=== Verificando permissões dos arquivos ==="
if [ -f "$SERVER_CERT" ]; then
  ls -l "$SERVER_CERT"
fi

if [ -f "$SERVER_KEY" ]; then
  ls -l "$SERVER_KEY"
fi

if [ -f "$EFI_CERT" ]; then
  ls -l "$EFI_CERT"
fi

echo
echo "=== Verificação concluída ==="
