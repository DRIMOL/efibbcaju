<?php
/**
 * EFI Bank Webhook Handler
 * 
 * Este script recebe notificações do EFI Bank via webhook com autenticação mTLS,
 * processa os dados e encaminha para o endpoint de redirecionamento.
 */

// Configurações
$logFile = '/var/log/efibank/webhook.log';
$redirectEndpoint = 'https://back.bcaju.ai/v1/efi_padrao';

// Função para registrar logs
function logMessage($message) {
    global $logFile;
    $timestamp = date('Y-m-d H:i:s');
    $logEntry = "[$timestamp] $message" . PHP_EOL;
    
    // Garantir que o diretório de logs existe
    $logDir = dirname($logFile);
    if (!is_dir($logDir)) {
        mkdir($logDir, 0755, true);
    }
    
    file_put_contents($logFile, $logEntry, FILE_APPEND);
}

// Verificar se a requisição é POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    logMessage("Método não permitido: " . $_SERVER['REQUEST_METHOD']);
    exit;
}

// Obter o corpo da requisição
$requestBody = file_get_contents('php://input');
if (empty($requestBody)) {
    http_response_code(400);
    logMessage("Corpo da requisição vazio");
    exit;
}

// Verificar se o conteúdo é um JSON válido
$data = json_decode($requestBody, true);
if (json_last_error() !== JSON_ERROR_NONE) {
    http_response_code(400);
    logMessage("JSON inválido: " . json_last_error_msg());
    exit;
}

// Registrar a requisição recebida
logMessage("Webhook recebido: " . $requestBody);

// Verificar se a autenticação mTLS foi bem-sucedida
// Isso é verificado pelo Nginx antes de chegar aqui, mas podemos fazer uma verificação adicional
if (!isset($_SERVER['SSL_CLIENT_VERIFY']) || $_SERVER['SSL_CLIENT_VERIFY'] !== 'SUCCESS') {
    http_response_code(403);
    logMessage("Falha na verificação mTLS: " . ($_SERVER['SSL_CLIENT_VERIFY'] ?? 'Não disponível'));
    exit;
}

// Encaminhar o conteúdo para o endpoint de redirecionamento
$ch = curl_init($redirectEndpoint);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, $requestBody);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Content-Length: ' . strlen($requestBody)
]);

// Executar a requisição
$response = curl_exec($ch);
$httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
curl_close($ch);

// Registrar o resultado do encaminhamento
if ($error) {
    logMessage("Erro ao encaminhar para $redirectEndpoint: $error");
} else {
    logMessage("Encaminhado para $redirectEndpoint. Código HTTP: $httpCode, Resposta: $response");
}

// Responder à EFI Bank com sucesso (independentemente do resultado do encaminhamento)
// Isso é importante para evitar que a EFI Bank faça novas tentativas desnecessárias
http_response_code(200);
echo "200";
