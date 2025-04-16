<?php
/**
 * EFI Bank Webhook Handler
 * 
 * This script validates incoming webhook requests from EFI Bank
 * and forwards the validated data to the n8n webhook.
 */

// Set error reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/php_errors.log');

// Log function
function logMessage($message) {
    $logFile = __DIR__ . '/webhook.log';
    $timestamp = date('Y-m-d H:i:s');
    
    // Garantir que o diretório de logs exista e tenha permissões adequadas
    if (!file_exists($logFile)) {
        touch($logFile);
        chmod($logFile, 0666); // Permissões para garantir que o arquivo seja gravável
    }
    
    file_put_contents($logFile, "[$timestamp] $message" . PHP_EOL, FILE_APPEND);
    error_log("[$timestamp] $message"); // Também log para stderr para aparecer nos logs do container
}

// Log request details
function logRequestDetails() {
    $headers = getallheaders();
    $headerStr = "";
    foreach ($headers as $key => $value) {
        $headerStr .= "$key: $value\n";
    }
    
    $requestBody = file_get_contents('php://input');
    
    logMessage("=== NOVA REQUISIÇÃO RECEBIDA ===");
    logMessage("Método: " . $_SERVER['REQUEST_METHOD']);
    logMessage("URI: " . $_SERVER['REQUEST_URI']);
    logMessage("Server Info: " . json_encode($_SERVER));
    logMessage("Headers:\n$headerStr");
    logMessage("Body: $requestBody");
    
    return $requestBody;
}

// Response function
function sendResponse($status, $message, $body = null) {
    http_response_code($status);
    
    // Se o status for 200 e nenhum corpo específico for fornecido, retorna "200"
    if ($status == 200 && $body === null) {
        echo "200";
        logMessage("Response sent: $status - $message");
        logMessage("Response body: 200");
    } else if ($body !== null) {
        // Se um corpo específico for fornecido, use-o
        echo $body;
        logMessage("Response sent: $status - $message");
        logMessage("Response body: $body");
    } else {
        // Para erros, retorne um JSON com a mensagem de erro
        echo json_encode(['status' => $status, 'message' => $message]);
        logMessage("Response sent: $status - $message");
        logMessage("Response body: " . json_encode(['status' => $status, 'message' => $message]));
    }
    
    logMessage("=== FIM DA REQUISIÇÃO ===");
    exit;
}

// Forward to n8n webhook
function forwardToN8n($data) {
    $n8nWebhook = 'https://rota.bcaju.ai/v1/efi_padrao';
    
    $ch = curl_init($n8nWebhook);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
    ]);
    // Adicionar timeout para evitar esperas longas
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    // Habilitar rastreamento de informações detalhadas
    curl_setopt($ch, CURLINFO_HEADER_OUT, true);
    // Desabilitar verificação SSL para testes (remover em produção)
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, 0);
    
    logMessage("Forwarding data to n8n webhook: " . json_encode($data));
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $info = curl_getinfo($ch);
    
    // Log detalhado da requisição curl
    logMessage("CURL request details:\n" . 
              "URL: {$info['url']}\n" .
              "Request headers: {$info['request_header']}\n" .
              "Total time: {$info['total_time']} seconds\n" .
              "Connect time: {$info['connect_time']} seconds");
    
    if (curl_errno($ch)) {
        logMessage("Error forwarding to n8n: " . curl_error($ch) . " (Code: " . curl_errno($ch) . ")");
        return false;
    }
    
    curl_close($ch);
    
    logMessage("n8n webhook response: HTTP $httpCode - $response");
    return ($httpCode >= 200 && $httpCode < 300);
}

// Criar um endpoint de teste para verificar se o serviço está funcionando
if (isset($_GET['test']) && $_GET['test'] === 'true') {
    logMessage("Test endpoint accessed");
    echo json_encode([
        'status' => 'success',
        'message' => 'Webhook service is running',
        'time' => date('Y-m-d H:i:s'),
        'server_info' => [
            'php_version' => phpversion(),
            'server_software' => $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown'
        ]
    ]);
    exit;
}

// Main webhook handler
try {
    // Log all request details
    $requestBody = logRequestDetails();
    
    // Check if the request is using mTLS
    // Nginx will set this header if mTLS validation passes
    $clientVerified = isset($_SERVER['HTTP_X_CLIENT_VERIFIED']) && $_SERVER['HTTP_X_CLIENT_VERIFIED'] === 'SUCCESS';
    
    logMessage("mTLS verification status: " . ($clientVerified ? "SUCCESS" : "FAILED"));
    logMessage("X-Client-Verified header: " . ($_SERVER['HTTP_X_CLIENT_VERIFIED'] ?? 'Not Set'));
    
    // Verificação rigorosa do mTLS conforme exigido pelo EFI Pay
    if (!$clientVerified) {
        logMessage("mTLS verification failed - Rejecting as required by EFI Pay");
        // Retornar erro 403 conforme exigido pela documentação do EFI Pay
        sendResponse(403, "mTLS verification required");
    }
    
    // Check if request body is empty
    if (empty($requestBody)) {
        logMessage("Empty request body");
        sendResponse(400, "Empty request body");
    }
    
    // Parse the JSON request
    $data = json_decode($requestBody, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        logMessage("Invalid JSON: " . json_last_error_msg());
        sendResponse(400, "Invalid JSON: " . json_last_error_msg());
    }
    
    // Log the received webhook data
    logMessage("Received webhook data: " . $requestBody);
    
    // Forward the data to n8n webhook
    $forwardResult = forwardToN8n($data);
    
    // Log the forward result
    logMessage("Forwarding result: " . ($forwardResult ? "SUCCESS" : "FAILED"));
    
    // Se a verificação mTLS foi bem-sucedida, retorne 200 conforme exigido pelo EFI Pay
    if ($clientVerified) {
        if ($forwardResult) {
            logMessage("mTLS verification SUCCESS and forwarding SUCCESS - Returning 200");
            sendResponse(200, "Webhook processed successfully");
        } else {
            // Mesmo com falha no encaminhamento, se o mTLS foi validado, retorne 200
            logMessage("mTLS verification SUCCESS but forwarding FAILED - Still returning 200 as required by EFI Pay");
            sendResponse(200, "Webhook received");
        }
    } else {
        // Este caso não deveria ocorrer devido à verificação anterior, mas mantemos por segurança
        logMessage("mTLS verification FAILED - Rejecting as required by EFI Pay");
        sendResponse(403, "mTLS verification required");
    }
    
} catch (Exception $e) {
    logMessage("Error processing webhook: " . $e->getMessage());
    logMessage("Stack trace: " . $e->getTraceAsString());
    
    // Em caso de erro interno, ainda verificamos se o mTLS foi validado
    if (isset($_SERVER['HTTP_X_CLIENT_VERIFIED']) && $_SERVER['HTTP_X_CLIENT_VERIFIED'] === 'SUCCESS') {
        // Se o mTLS foi validado, retorne 200 mesmo com erro interno
        logMessage("Internal error but mTLS verification SUCCESS - Returning 200 as required by EFI Pay");
        sendResponse(200, "Webhook received despite internal error");
    } else {
        // Se o mTLS falhou, retorne erro
        logMessage("Internal error and mTLS verification FAILED - Rejecting as required by EFI Pay");
        sendResponse(403, "mTLS verification required");
    }
}
