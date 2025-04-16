# Guia de Instalação e Configuração do Webhook EFI Bank

Este guia fornece instruções passo a passo para configurar o serviço de webhook que recebe notificações da EFI Bank, valida a autenticação mTLS e encaminha os dados para o webhook do n8n.

## Pré-requisitos

- Ubuntu 20.04 LTS (já instalado)
- Docker e Docker Compose
- Git
- Acesso à internet para baixar os certificados e imagens Docker

## 1. Preparação do Ambiente

### 1.1. Instalar Docker e Docker Compose

```bash
# Atualizar os repositórios
sudo apt update

# Instalar Git se ainda não estiver instalado
sudo apt install -y git

# Instalar dependências necessárias
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Adicionar a chave GPG do Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Adicionar o repositório do Docker
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Atualizar os repositórios novamente
sudo apt update

# Instalar o Docker
sudo apt install -y docker-ce

# Adicionar seu usuário ao grupo docker (para executar docker sem sudo)
sudo usermod -aG docker $USER

# Instalar o Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verificar a instalação
docker --version
docker-compose --version
```

> **Nota**: Após adicionar seu usuário ao grupo docker, você precisará fazer logout e login novamente para que as alterações tenham efeito.

### 1.2. Clonar o Repositório do GitHub

```bash
# Navegar para o diretório home ou outro de sua preferência
cd ~

# Clonar o repositório
git clone https://github.com/MakeToMe/efybank.git

# Navegar para a pasta do projeto
cd efybank

# Criar a estrutura de diretórios necessária
mkdir -p certs logs/nginx logs/php
```

## 2. Obtenção dos Certificados

### 2.1. Baixar o Certificado da EFI Bank

```bash
# Navegar para a pasta de certificados
cd ~/efybank/certs

# Baixar o certificado de produção da EFI Bank
curl -o certificate-chain-prod.crt https://certificados.efipay.com.br/webhooks/certificate-chain-prod.crt

# Ou, para ambiente de homologação
curl -o certificate-chain-homolog.crt https://certificados.efipay.com.br/webhooks/certificate-chain-homolog.crt
```

### 2.2. Preparar seus Certificados SSL

Para um ambiente de produção, você precisará de certificados SSL válidos para seu domínio. Para testes locais, você pode gerar certificados autoassinados:

```bash
# Navegar para a pasta de certificados
cd ~/efybank/certs

# Instalar OpenSSL se ainda não estiver instalado
sudo apt install -y openssl

# Gerar uma chave privada
openssl genrsa -out server.key 2048

# Gerar um certificado autoassinado (válido por 365 dias)
openssl req -new -x509 -key server.key -out server.crt -days 365 -subj "/CN=localhost"
```

> **Nota**: Para produção, substitua estes certificados autoassinados por certificados válidos emitidos por uma autoridade certificadora confiável.

## 3. Configuração do Nginx

### 3.1. Atualizar a Configuração do Nginx

Edite o arquivo `nginx-webhook.conf` para apontar para os caminhos corretos dos certificados:

```bash
# Abrir o arquivo de configuração com o editor nano
nano ~/efybank/nginx-webhook.conf
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

Também atualize o `server_name` para seu domínio real ou use `localhost` para testes locais:

```nginx
server_name localhost;  # ou seu domínio real
```

## 4. Configuração do PHP

### 4.1. Verificar o Arquivo Webhook PHP

O arquivo `webhook.php` já está configurado para encaminhar os dados para o webhook do n8n em `https://back.bcaju.ai/v1/efi_padrao`. Se você precisar alterar este URL, edite o arquivo:

```bash
# Abrir o arquivo PHP com o editor nano
nano ~/efybank/www/webhook.php
```

Localize a função `forwardToN8n` e atualize o URL do webhook se necessário:

```php
function forwardToN8n($data) {
    $n8nWebhook = 'https://back.bcaju.ai/v1/efi_padrao';
    // ...
}
```

## 5. Construção e Execução dos Contêineres Docker

### 5.1. Verificar o Status do Docker

Certifique-se de que o Docker esteja em execução no seu sistema Ubuntu:

```bash
sudo systemctl status docker
```

Se não estiver em execução, inicie-o:

```bash
sudo systemctl start docker
```

### 5.2. Construir e Iniciar os Contêineres

```bash
# Navegar para a pasta do projeto
cd ~/efybank

# Construir e iniciar os contêineres em segundo plano
docker-compose up -d
```

Este comando irá:
1. Baixar as imagens base do Nginx e PHP (se ainda não estiverem disponíveis localmente)
2. Construir a imagem personalizada do PHP com as extensões necessárias
3. Criar e iniciar os contêineres conforme definido no arquivo `docker-compose.yml`

### 5.3. Verificar se os Contêineres Estão em Execução

```powershell
docker-compose ps
```

Você deverá ver dois contêineres em execução: um para o Nginx e outro para o PHP.

## 6. Verificação e Testes

### 6.1. Verificar os Logs

```bash
# Verificar logs do serviço
docker-compose logs

# Para acompanhar os logs em tempo real
docker-compose logs -f

# Para verificar apenas os logs do Nginx
docker-compose logs nginx

# Para verificar apenas os logs do PHP
docker-compose logs php
```

### 6.2. Testar o Webhook Localmente

Para testar localmente, você pode usar o curl para enviar uma requisição POST para o webhook:

```bash
# Enviar uma requisição de teste (isso não passará na verificação mTLS, mas é útil para verificar se o serviço está respondendo)
curl -k -X POST https://localhost/webhook -d '{"teste": true}'
```

> **Nota**: Esta requisição deve falhar com um erro 403, pois não inclui o certificado cliente para mTLS.

## 7. Configuração para Produção

### 7.1. Configurar o Firewall

Configure o firewall para permitir tráfego na porta 443:

```bash
# Instalar o UFW se ainda não estiver instalado
sudo apt install -y ufw

# Permitir SSH (importante para não perder acesso ao servidor)
sudo ufw allow ssh

# Permitir HTTPS (porta 443)
sudo ufw allow 443/tcp

# Ativar o firewall
sudo ufw enable

# Verificar o status
sudo ufw status
```

### 7.2. Configurar um Nome de Domínio

Registre um nome de domínio e configure-o para apontar para o IP público do seu servidor.

### 7.3. Obter Certificados SSL Válidos

Para produção, você pode obter certificados SSL gratuitos com Let's Encrypt:

```bash
# Instalar o Certbot
sudo apt install -y certbot

# Obter certificados (substitua seu-dominio.com pelo seu domínio real)
sudo certbot certonly --standalone -d seu-dominio.com

# Os certificados serão salvos em /etc/letsencrypt/live/seu-dominio.com/
# Copiar para a pasta do projeto
sudo cp /etc/letsencrypt/live/seu-dominio.com/fullchain.pem ~/efybank/certs/server.crt
sudo cp /etc/letsencrypt/live/seu-dominio.com/privkey.pem ~/efybank/certs/server.key
```

### 7.4. Atualizar a Configuração do Nginx

Atualize o arquivo `nginx-webhook.conf` com os caminhos para seus certificados SSL válidos e o nome de domínio correto:

```bash
nano ~/efybank/nginx-webhook.conf
```

### 7.5. Reiniciar os Contêineres

```bash
# Navegar para a pasta do projeto
cd ~/efybank

# Parar os contêineres
docker-compose down

# Iniciar os contêineres com a nova configuração
docker-compose up -d
```

## 8. Registrar o Webhook na EFI Bank

Acesse o painel da EFI Bank e registre seu webhook usando a URL completa:

```
https://seu-dominio.com/webhook
```

## 9. Solução de Problemas

### 9.1. Verificar Logs do Webhook

```bash
# Verificar o arquivo de log do webhook
cat ~/efybank/www/webhook.log

# Acompanhar o log em tempo real
tail -f ~/efybank/www/webhook.log
```

### 9.2. Verificar Logs do Nginx

```bash
# Verificar logs de acesso do Nginx
cat ~/efybank/logs/nginx/access.log

# Verificar logs de erro do Nginx
cat ~/efybank/logs/nginx/error.log

# Acompanhar os logs em tempo real
tail -f ~/efybank/logs/nginx/error.log
```

### 9.3. Problemas com Certificados

Se houver problemas com os certificados:

1. Verifique se os caminhos nos arquivos de configuração estão corretos
2. Verifique se os certificados têm as permissões corretas
3. Verifique se os certificados são válidos e não expiraram

```bash
# Verificar informações do certificado
openssl x509 -in ~/efybank/certs/server.crt -text -noout

# Verificar permissões dos certificados
ls -la ~/efybank/certs/

# Corrigir permissões se necessário
chmod 644 ~/efybank/certs/server.crt
chmod 600 ~/efybank/certs/server.key
```

## 10. Manutenção

### 10.1. Atualizar os Contêineres

```bash
# Navegar para a pasta do projeto
cd ~/efybank

# Parar os contêineres
docker-compose down

# Puxar as imagens mais recentes
docker-compose pull

# Reconstruir a imagem personalizada do PHP
docker-compose build

# Iniciar os contêineres atualizados
docker-compose up -d
```

### 10.2. Fazer Backup dos Certificados e Configurações

```bash
# Criar um diretório de backup
mkdir -p ~/backups/efybank

# Copiar certificados e configurações
cp -r ~/efybank/certs ~/backups/efybank/
cp ~/efybank/*.conf ~/backups/efybank/
cp ~/efybank/docker-compose.yml ~/backups/efybank/

# Criar um arquivo compactado do backup
tar -czvf ~/backups/efybank-backup-$(date +%Y%m%d).tar.gz ~/backups/efybank/
```

## 11. Considerações de Segurança

- Mantenha sua chave privada segura e não a compartilhe
- Mantenha o sistema Ubuntu atualizado: `sudo apt update && sudo apt upgrade -y`
- Configure o firewall (UFW) para permitir apenas tráfego necessário
- Atualize regularmente o Nginx e o PHP para as versões mais recentes
- Monitore os logs em busca de atividades suspeitas
- Considere implementar limites de taxa para evitar sobrecarga do servidor
- Configure o fail2ban para proteger contra tentativas de força bruta: `sudo apt install -y fail2ban`
- Desative o acesso SSH por senha e use apenas chaves SSH: `sudo nano /etc/ssh/sshd_config`
