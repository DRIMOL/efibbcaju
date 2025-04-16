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

// Log function
function logMessage($message) {
    $logFile = __DIR__ . '/webhook.log';
    $timestamp = date('Y-m-d H:i:s');
    file_put_contents($logFile, "[$timestamp] $message" . PHP_EOL, FILE_APPEND);
}

// Response function
function sendResponse($status, $message) {
    http_response_code($status);
    // Apenas retorna a string "200" em vez de um objeto JSON
    echo "200";
    logMessage("Response sent: $status - $message");
    exit;
}

// Forward to n8n webhook
function forwardToN8n($data) {
    $n8nWebhook = 'https://back.bcaju.ai/v1/efi_padrao';
    
    $ch = curl_init($n8nWebhook);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/json',
    ]);
    
    logMessage("Forwarding data to n8n webhook: " . json_encode($data));
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    
    if (curl_errno($ch)) {
        logMessage("Error forwarding to n8n: " . curl_error($ch));
        return false;
    }
    
    curl_close($ch);
    
    logMessage("n8n webhook response: HTTP $httpCode - $response");
    return ($httpCode >= 200 && $httpCode < 300);
}

// Main webhook handler
try {
    // Check if the request is using mTLS
    // Nginx will set this header if mTLS validation passes
    $clientVerified = isset($_SERVER['HTTP_X_CLIENT_VERIFIED']) && $_SERVER['HTTP_X_CLIENT_VERIFIED'] === 'SUCCESS';
    
    if (!$clientVerified) {
        logMessage("mTLS verification failed");
        sendResponse(403, "mTLS verification required");
    }
    
    // Get the request body
    $requestBody = file_get_contents('php://input');
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
    
    // Always return 200 status code
    if ($forwardResult) {
        sendResponse(200, "Webhook processed successfully");
    } else {
        // Log the error but still return 200
        logMessage("Warning: Failed to forward webhook data to n8n, but returning 200 as requested");
        sendResponse(200, "Webhook received");
    }
    
} catch (Exception $e) {
    logMessage("Error processing webhook: " . $e->getMessage());
    sendResponse(500, "Internal server error: " . $e->getMessage());
}
