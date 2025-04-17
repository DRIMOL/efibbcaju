# EFI Bank Webhook

Este projeto implementa um webhook para receber notificações da EFI Bank com autenticação mTLS (mutual TLS), processar os dados e encaminhá-los para um endpoint específico.

## Estrutura do Projeto

```
/
├── certs/                  # Certificados SSL e da EFI Bank
├── logs/                   # Logs do Nginx e PHP
├── www/                    # Arquivos PHP do webhook
│   └── webhook.php         # Manipulador de webhook em PHP
├── docker-compose.yml      # Configuração dos contêineres Docker
├── install.sh              # Script de instalação automatizada
├── check_certs.sh          # Script para verificar certificados
├── restart_service.sh      # Script para reiniciar os serviços
├── nginx-webhook.conf      # Configuração do Nginx com suporte a mTLS
└── README.md               # Este arquivo
```

## Requisitos

- Ubuntu 20.04 LTS
- Domínio configurado (bb.bcaju.com.br) apontando para o servidor
- Acesso root ao servidor

## Configurações Importantes

- **Domínio**: bb.bcaju.com.br
- **Endpoint de redirecionamento**: https://back.bcaju.ai/v1/efi_padrao
- **Certificado mTLS da EFI Bank**: https://certificados.efipay.com.br/webhooks/certificate-chain-prod.crt

## Instalação

### 1. Clonar o repositório no servidor

```bash
git clone https://github.com/seu-usuario/efibank.git
cd efibank
```

### 2. Tornar os scripts executáveis

```bash
chmod +x install.sh check_certs.sh restart_service.sh
```

### 3. Executar o script de instalação

```bash
sudo ./install.sh
```

O script de instalação irá:
- Atualizar o sistema
- Instalar as dependências necessárias (Nginx, PHP-FPM, Docker, etc.)
- Baixar o certificado da EFI Bank
- Configurar o Nginx com suporte a mTLS
- Obter um certificado SSL para o domínio (opcional)
- Configurar permissões e reiniciar os serviços

## Verificação de Certificados

Para verificar a validade dos certificados SSL e da EFI Bank:

```bash
sudo ./check_certs.sh
```

## Reiniciar Serviços

Para reiniciar os serviços Nginx e PHP-FPM:

```bash
sudo ./restart_service.sh
```

## Funcionamento

1. A EFI Bank envia uma requisição POST para https://bb.bcaju.com.br/
2. O Nginx verifica a autenticação mTLS usando o certificado da EFI Bank
3. Se a autenticação for bem-sucedida, a requisição é encaminhada para o PHP
4. O PHP processa a requisição, registra os dados e encaminha para https://back.bcaju.ai/v1/efi_padrao
5. Uma resposta de sucesso (código 200) é enviada de volta para a EFI Bank

## Logs

Os logs do webhook podem ser encontrados em:
- Logs do Nginx: `/var/log/nginx/bb.bcaju.com.br-access.log` e `/var/log/nginx/bb.bcaju.com.br-error.log`
- Logs do webhook: `/var/log/efibank/webhook.log`

## Solução de Problemas

Se o webhook não estiver funcionando corretamente:

1. Verifique se os serviços estão em execução:
   ```bash
   sudo systemctl status nginx
   sudo systemctl status php7.4-fpm
   ```

2. Verifique os logs:
   ```bash
   tail -f /var/log/nginx/bb.bcaju.com.br-error.log
   tail -f /var/log/efibank/webhook.log
   ```

3. Verifique se os certificados são válidos:
   ```bash
   sudo ./check_certs.sh
   ```

4. Teste a conexão mTLS:
   ```bash
   curl -k --cert /etc/efibank/certs/certificate-chain-prod.crt https://bb.bcaju.com.br/
   ```

## Segurança

Este projeto implementa as seguintes medidas de segurança:

1. **Autenticação mTLS**: Garante que apenas a EFI Bank possa enviar requisições para o webhook
2. **HTTPS**: Todas as comunicações são criptografadas
3. **Validação de JSON**: Verifica se o conteúdo recebido é um JSON válido
4. **Logging**: Registra todas as requisições e respostas para auditoria

## Manutenção

- Verifique regularmente a validade dos certificados usando o script `check_certs.sh`
- Monitore os logs para detectar possíveis problemas
- Atualize o sistema e as dependências regularmente
