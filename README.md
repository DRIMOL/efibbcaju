# EFI Bank Webhook Service

Este serviço implementa um webhook para receber notificações da EFI Bank, validar a autenticação mTLS e encaminhar os dados validados para o webhook do n8n.

## Estrutura do Projeto

```
efybank/
├── certs/                  # Diretório para armazenar certificados
├── www/                    # Diretório para arquivos PHP
│   └── webhook.php         # Manipulador do webhook
├── logs/                   # Diretório para logs (criado automaticamente)
├── docker-compose.yml      # Configuração do Docker Compose
├── Dockerfile.php          # Dockerfile para o contêiner PHP
├── nginx-webhook.conf      # Configuração do Nginx
└── README.md               # Este arquivo
```

## Requisitos

- Docker
- Docker Compose
- Certificados SSL para seu domínio
- Certificado público da EFI Bank

## Configuração

### 1. Obtenha os Certificados

Baixe o certificado público da EFI Bank:

- Produção: https://certificados.efipay.com.br/webhooks/certificate-chain-prod.crt
- Homologação: https://certificados.efipay.com.br/webhooks/certificate-chain-homolog.crt

Salve o certificado no diretório `certs/`.

### 2. Configure seus Certificados SSL

Coloque seus certificados SSL no diretório `certs/`:
- Certificado: `certs/your-certificate.crt`
- Chave privada: `certs/your-private.key`

### 3. Atualize a Configuração do Nginx

Edite o arquivo `nginx-webhook.conf` para apontar para os caminhos corretos dos certificados:

```nginx
ssl_certificate /etc/nginx/certs/your-certificate.crt;
ssl_certificate_key /etc/nginx/certs/your-private.key;
ssl_client_certificate /etc/nginx/certs/certificate-chain-prod.crt;
```

Atualize também o `server_name` para seu domínio real.

### 4. Crie os Diretórios de Logs

```powershell
mkdir -p logs/nginx logs/php
```

## Execução

Para iniciar o serviço:

```powershell
docker-compose up -d
```

Para verificar os logs:

```powershell
docker-compose logs -f
```

## Funcionamento

1. O Nginx recebe as requisições HTTPS e verifica a autenticação mTLS usando o certificado público da EFI Bank.
2. Se a autenticação for bem-sucedida, a requisição é encaminhada para o PHP.
3. O script PHP valida a requisição e encaminha os dados para o webhook do n8n em `https://back.bcaju.ai/v1/efi_padrao`.
4. Uma resposta de sucesso (código 200) é enviada de volta para a EFI Bank.

## Logs

Os logs do webhook são armazenados em:
- `www/webhook.log`: Logs do processamento do webhook
- `logs/nginx/`: Logs do Nginx
- `logs/php/`: Logs do PHP-FPM

## Solução de Problemas

Se você encontrar problemas com a autenticação mTLS, verifique:
1. Se o certificado da EFI Bank está correto e acessível
2. Se seus certificados SSL estão configurados corretamente
3. Se o Nginx está configurado para exigir a verificação do cliente
4. Os logs do Nginx para mensagens de erro relacionadas à SSL/TLS
