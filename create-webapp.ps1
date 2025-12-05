# Create and configure Azure Web App for the chatbot
# This script sets up everything needed from scratch

Write-Host "`n=== Azure Web App Setup for GBS Chatbot ===" -ForegroundColor Cyan
Write-Host "This script will create and configure the Web App with all required settings.`n" -ForegroundColor Gray

# Load environment variables
if (Test-Path ".\set-env-vars.ps1") {
    . .\set-env-vars.ps1
} else {
    Write-Host "Error: set-env-vars.ps1 not found. Please run it first." -ForegroundColor Red
    exit 1
}

# Configuration
$APP_NAME = "gbs-chatbot-webapp"
$PLAN_NAME = "gbs-chatbot-plan"

Write-Host "`nStep 1: Creating App Service Plan..." -ForegroundColor Cyan
Write-Host "  Name: $PLAN_NAME" -ForegroundColor Gray
Write-Host "  SKU: B1 (Basic, 1 core, 1.75GB RAM)" -ForegroundColor Gray

az appservice plan create `
  --name $PLAN_NAME `
  --resource-group $env:RES_GROUP `
  --is-linux `
  --sku B1 `
  --output none

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to create App Service Plan" -ForegroundColor Red
    exit 1
}
Write-Host "✅ App Service Plan created" -ForegroundColor Green

Write-Host "`nStep 2: Creating Web App..." -ForegroundColor Cyan
Write-Host "  Name: $APP_NAME" -ForegroundColor Gray
Write-Host "  Image: $env:ACR_NAME.azurecr.io/gbs-azure-chatbot:latest" -ForegroundColor Gray

az webapp create `
  --name $APP_NAME `
  --resource-group $env:RES_GROUP `
  --plan $PLAN_NAME `
  --deployment-container-image-name "$env:ACR_NAME.azurecr.io/gbs-azure-chatbot:latest" `
  --output none

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to create Web App" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Web App created" -ForegroundColor Green

Write-Host "`nStep 3: Enabling Managed Identity..." -ForegroundColor Cyan

# Enable system-assigned identity first
$identity = az webapp identity assign `
  --name $APP_NAME `
  --resource-group $env:RES_GROUP `
  --query principalId `
  --output tsv

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to enable system-assigned managed identity" -ForegroundColor Red
    exit 1
}
Write-Host "✅ System-assigned Managed Identity enabled: $identity" -ForegroundColor Green

# Attach user-assigned identity if it exists
Write-Host "  Checking for user-assigned identity..." -ForegroundColor Gray
$userIdentityId = az identity show --name gbs-chatbot-managed-identity --resource-group $env:RES_GROUP --query id -o tsv 2>$null

if ($LASTEXITCODE -eq 0 -and $userIdentityId) {
    Write-Host "  Attaching user-assigned identity..." -ForegroundColor Gray
    az webapp identity assign `
      --name $APP_NAME `
      --resource-group $env:RES_GROUP `
      --identities $userIdentityId `
      --output none
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ User-assigned identity attached" -ForegroundColor Green
    } else {
        Write-Host "Warning: Failed to attach user-assigned identity" -ForegroundColor Yellow
    }
} else {
    Write-Host "  No user-assigned identity found (gbs-chatbot-managed-identity)" -ForegroundColor Gray
}

Write-Host "`nStep 4: Granting Key Vault access..." -ForegroundColor Cyan
Write-Host "  Waiting for identity to propagate..." -ForegroundColor Gray

# Wait longer and retry for identity propagation
$maxRetries = 12
$retryCount = 0
$success = $false

while (-not $success -and $retryCount -lt $maxRetries) {
    if ($retryCount -gt 0) {
        Write-Host "  Retry $retryCount/$maxRetries - waiting 15 more seconds..." -ForegroundColor Gray
        Start-Sleep -Seconds 15
    } else {
        Start-Sleep -Seconds 30
    }
    
    $kvScope = az keyvault show --name $env:AKV_NAME --query id -o tsv
    
    az role assignment create `
      --role "Key Vault Secrets User" `
      --assignee $identity `
      --scope $kvScope `
      --output none 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        $success = $true
        Write-Host "✅ Key Vault access granted to system-assigned identity" -ForegroundColor Green
    } else {
        $retryCount++
        if ($retryCount -ge $maxRetries) {
            Write-Host "Failed to grant Key Vault access after $maxRetries attempts." -ForegroundColor Red
            Write-Host "The managed identity may need more time to propagate." -ForegroundColor Yellow
            Write-Host "You can manually grant access with:" -ForegroundColor Yellow
            Write-Host "  az role assignment create --role 'Key Vault Secrets User' --assignee $identity --scope $kvScope" -ForegroundColor White
            exit 1
        }
    }
}

# Also grant Key Vault access to user-assigned identity if it exists
if ($userIdentityId) {
    Write-Host "  Granting Key Vault access to user-assigned identity..." -ForegroundColor Gray
    $userIdentityPrincipalId = az identity show --name gbs-chatbot-managed-identity --resource-group $env:RES_GROUP --query principalId -o tsv
    
    az role assignment create `
      --role "Key Vault Secrets User" `
      --assignee $userIdentityPrincipalId `
      --scope $kvScope `
      --output none 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Key Vault access granted to user-assigned identity" -ForegroundColor Green
    } else {
        Write-Host "  Note: User-assigned identity may already have access" -ForegroundColor Gray
    }
}

Write-Host "`nStep 5: Configuring Container Registry..." -ForegroundColor Cyan
az webapp config container set `
  --name $APP_NAME `
  --resource-group $env:RES_GROUP `
  --container-registry-url "https://$env:ACR_NAME.azurecr.io" `
  --container-registry-user $(az keyvault secret show --vault-name $env:AKV_NAME --name "$env:ACR_NAME-pull-usr" --query value -o tsv) `
  --container-registry-password $(az keyvault secret show --vault-name $env:AKV_NAME --name "$env:ACR_NAME-pull-pwd" --query value -o tsv) `
  --output none

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to configure container registry" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Container Registry configured" -ForegroundColor Green

Write-Host "`nStep 6: Setting startup command..." -ForegroundColor Cyan
az webapp config set `
  --name $APP_NAME `
  --resource-group $env:RES_GROUP `
  --startup-file "gunicorn --config gunicorn.conf.py api.main:create_app()" `
  --output none

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to set startup command" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Startup command configured" -ForegroundColor Green

Write-Host "`nStep 7: Configuring basic app settings..." -ForegroundColor Cyan
az webapp config appsettings set `
  --name $APP_NAME `
  --resource-group $env:RES_GROUP `
  --settings `
    WEBSITES_PORT=80 `
    PORT=80 `
    RUNNING_IN_PRODUCTION=true `
    GUNICORN_TIMEOUT=300 `
  --output none

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to set basic settings" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Basic settings configured" -ForegroundColor Green

Write-Host "`nStep 8: Configuring Key Vault references..." -ForegroundColor Cyan
$kvSettings = @{
    "AZURE_CLIENT_ID" = "@Microsoft.KeyVault(SecretUri=https://$env:AKV_NAME.vault.azure.net/secrets/AZURE-CLIENT-ID/)"
    "AZURE_AI_CHAT_DEPLOYMENT_NAME" = "@Microsoft.KeyVault(SecretUri=https://$env:AKV_NAME.vault.azure.net/secrets/AZURE-AI-CHAT-DEPLOYMENT-NAME/)"
    "AZURE_AI_EMBED_DEPLOYMENT_NAME" = "@Microsoft.KeyVault(SecretUri=https://$env:AKV_NAME.vault.azure.net/secrets/AZURE-AI-EMBED-DEPLOYMENT-NAME/)"
    "AZURE_AI_EMBED_DIMENSIONS" = "@Microsoft.KeyVault(SecretUri=https://$env:AKV_NAME.vault.azure.net/secrets/AZURE-AI-EMBED-DIMENSIONS/)"
    "AZURE_EXISTING_AIPROJECT_API_KEY" = "@Microsoft.KeyVault(SecretUri=https://$env:AKV_NAME.vault.azure.net/secrets/AZURE-EXISTING-AIPROJECT-API-KEY/)"
    "AZURE_EXISTING_AIPROJECT_ENDPOINT" = "@Microsoft.KeyVault(SecretUri=https://$env:AKV_NAME.vault.azure.net/secrets/AZURE-EXISTING-AIPROJECT-ENDPOINT/)"
    "AZURE_AI_SEARCH_ENDPOINT" = "@Microsoft.KeyVault(SecretUri=https://$env:AKV_NAME.vault.azure.net/secrets/AZURE-AI-SEARCH-ENDPOINT/)"
    "AZURE_AI_SEARCH_INDEX_NAME" = "@Microsoft.KeyVault(SecretUri=https://$env:AKV_NAME.vault.azure.net/secrets/AZURE-AI-SEARCH-INDEX-NAME/)"
    "AZURE_AI_SEARCH_API_KEY" = "@Microsoft.KeyVault(SecretUri=https://$env:AKV_NAME.vault.azure.net/secrets/AZURE-AI-SEARCH-API-KEY/)"
}

foreach ($key in $kvSettings.Keys) {
    Write-Host "  Setting: $key" -ForegroundColor Gray
    $value = $kvSettings[$key]
    
    # Use cmd to avoid PowerShell parsing issues with parentheses
    cmd /c "az webapp config appsettings set --name $APP_NAME --resource-group $env:RES_GROUP --settings `"$key=$value`" --output none 2>nul"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: Failed to set $key" -ForegroundColor Yellow
    }
}
Write-Host "✅ Key Vault references configured" -ForegroundColor Green

# Remove old variable names if they exist
Write-Host "`nStep 8b: Cleaning up old variable names..." -ForegroundColor Cyan
$oldVars = @("AZURE_SEARCH_INDEX", "AZURE_SEARCH_KEY", "AZURE_SEARCH_SERVICE_ENDPOINT")
az webapp config appsettings delete --name $APP_NAME --resource-group $env:RES_GROUP --setting-names $oldVars --output none 2>$null
Write-Host "✅ Old variables cleaned up" -ForegroundColor Green

Write-Host "`nStep 9: Enabling logging..." -ForegroundColor Cyan
az webapp log config `
  --name $APP_NAME `
  --resource-group $env:RES_GROUP `
  --application-logging filesystem `
  --level verbose `
  --docker-container-logging filesystem `
  --output none

if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: Failed to configure logging" -ForegroundColor Yellow
} else {
    Write-Host "✅ Logging enabled" -ForegroundColor Green
}

Write-Host "`nStep 10: Starting Web App..." -ForegroundColor Cyan
az webapp restart --name $APP_NAME --resource-group $env:RES_GROUP --output none

Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "✅ Web App Setup Complete!" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Cyan

Write-Host "`nWeb App Details:" -ForegroundColor Cyan
Write-Host "  Name: $APP_NAME" -ForegroundColor Gray
Write-Host "  URL: https://$APP_NAME.azurewebsites.net" -ForegroundColor Gray
Write-Host "  Resource Group: $env:RES_GROUP" -ForegroundColor Gray
Write-Host "  Container Image: $env:ACR_NAME.azurecr.io/gbs-azure-chatbot:latest" -ForegroundColor Gray

Write-Host "`nUseful Commands:" -ForegroundColor Cyan
Write-Host "  View logs:" -ForegroundColor Gray
Write-Host "    az webapp log tail --name $APP_NAME --resource-group $env:RES_GROUP" -ForegroundColor White
Write-Host "`n  Restart app:" -ForegroundColor Gray
Write-Host "    az webapp restart --name $APP_NAME --resource-group $env:RES_GROUP" -ForegroundColor White
Write-Host "`n  Update container image:" -ForegroundColor Gray
Write-Host "    az webapp config container set --name $APP_NAME --resource-group $env:RES_GROUP --container-image-name $env:ACR_NAME.azurecr.io/gbs-azure-chatbot:latest" -ForegroundColor White
Write-Host "`n  Delete app:" -ForegroundColor Gray
Write-Host "    az webapp delete --name $APP_NAME --resource-group $env:RES_GROUP" -ForegroundColor White
Write-Host "    az appservice plan delete --name $PLAN_NAME --resource-group $env:RES_GROUP" -ForegroundColor White

Write-Host "`n⏳ Waiting for app to start (this may take 1-2 minutes)..." -ForegroundColor Yellow
Write-Host "   You can check the status at: https://$APP_NAME.azurewebsites.net`n" -ForegroundColor Gray
