# Deploy chatbot to Azure Web App
# Run .\set-env-vars.ps1 first to set environment variables

# Load environment variables
if (Test-Path ".\set-env-vars.ps1") {
    . .\set-env-vars.ps1
} else {
    Write-Host "Error: set-env-vars.ps1 not found. Please run it first." -ForegroundColor Red
    exit 1
}

Write-Host "Configuring App Service settings..." -ForegroundColor Cyan

# Set basic settings
az webapp config appsettings set `
  --name gbs-chatbot-webapp `
  --resource-group $env:RES_GROUP `
  --settings `
    WEBSITES_PORT=80 `
    PORT=80 `
    RUNNING_IN_PRODUCTION=true `
    GUNICORN_TIMEOUT=300 `
  --output none

# Set Key Vault references
Write-Host "  Configuring Key Vault references..." -ForegroundColor Gray
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
    
    # Use cmd to avoid PowerShell parsing issues with @ and parentheses
    cmd /c "az webapp config appsettings set --name gbs-chatbot-webapp --resource-group $env:RES_GROUP --settings `"$key=$value`" --output none 2>nul"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to set $key" -ForegroundColor Red
        exit 1
    }
}

# Remove old variable names if they exist
Write-Host "`n  Cleaning up old variable names..." -ForegroundColor Gray
$oldVars = @("AZURE_SEARCH_INDEX", "AZURE_SEARCH_KEY", "AZURE_SEARCH_SERVICE_ENDPOINT")
az webapp config appsettings delete --name gbs-chatbot-webapp --resource-group $env:RES_GROUP --setting-names $oldVars --output none 2>$null

Write-Host "`nRestarting web app..." -ForegroundColor Cyan
az webapp restart --name gbs-chatbot-webapp --resource-group $env:RES_GROUP --output none

Write-Host "`n✅ Web app configured!" -ForegroundColor Green
Write-Host "URL: https://gbs-chatbot-webapp.azurewebsites.net" -ForegroundColor Cyan
Write-Host "`nTo view logs:" -ForegroundColor Yellow
Write-Host "  az webapp log tail --name gbs-chatbot-webapp --resource-group $env:RES_GROUP" -ForegroundColor Gray
