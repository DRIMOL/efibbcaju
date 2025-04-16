<?php
/**
 * Script de teste para verificar a configuração mTLS
 */

// Configurar cabeçalhos para JSON
header('Content-Type: application/json');

// Coletar informações do servidor
$serverInfo = [
    'time' => date('Y-m-d H:i:s'),
    'php_version' => phpversion(),
    'server_software' => $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown',
    'request_method' => $_SERVER['REQUEST_METHOD'],
    'request_uri' => $_SERVER['REQUEST_URI'],
    'client_ip' => $_SERVER['REMOTE_ADDR'],
    'headers' => []
];

// Coletar todos os cabeçalhos
$headers = getallheaders();
foreach ($headers as $key => $value) {
    $serverInfo['headers'][$key] = $value;
}

// Verificar o status da autenticação mTLS
$mtlsStatus = [
    'client_verified' => isset($_SERVER['HTTP_X_CLIENT_VERIFIED']) ? $_SERVER['HTTP_X_CLIENT_VERIFIED'] : 'Not Set',
    'ssl_client_verify' => isset($_SERVER['SSL_CLIENT_VERIFY']) ? $_SERVER['SSL_CLIENT_VERIFY'] : 'Not Set',
    'is_verified' => (isset($_SERVER['HTTP_X_CLIENT_VERIFIED']) && $_SERVER['HTTP_X_CLIENT_VERIFIED'] === 'SUCCESS')
];

// Preparar resposta
$response = [
    'status' => 'success',
    'message' => 'mTLS Test Script',
    'mtls_status' => $mtlsStatus,
    'server_info' => $serverInfo
];

// Registrar acesso em log
$logFile = __DIR__ . '/test_mtls.log';
$timestamp = date('Y-m-d H:i:s');
$logMessage = "[$timestamp] Test script accessed\n";
$logMessage .= "mTLS Status: " . json_encode($mtlsStatus) . "\n";
$logMessage .= "Headers: " . json_encode($serverInfo['headers']) . "\n";
$logMessage .= "----------------------------\n";

// Garantir que o arquivo de log exista e tenha permissões adequadas
if (!file_exists($logFile)) {
    touch($logFile);
    chmod($logFile, 0666);
}
file_put_contents($logFile, $logMessage, FILE_APPEND);

// Retornar resposta
echo json_encode($response, JSON_PRETTY_PRINT);
