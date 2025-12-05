# Deploy chatbot to Azure Web App
# Run .\set-env-vars.ps1 first to set environment variables

Write-Host "Configuring App Service settings..." -ForegroundColor Cyan

# Set basic settings
az webapp config appsettings set `
  --name gbs-chatbot-webapp `
  --resource-group gbs-chatbot-resource-group `
  --settings `
    PORT=80 `
    RUNNING_IN_PRODUCTION=true `
    GUNICORN_TIMEOUT=300

# Set Key Vault references
$kvSettings = @{
    "AZURE_CLIENT_ID" = "@Microsoft.KeyVault(SecretUri=https://gbschatbot-vault.vault.azure.net/secrets/AZURE-CLIENT-ID/)"
    "AZURE_AI_CHAT_DEPLOYMENT_NAME" = "@Microsoft.KeyVault(SecretUri=https://gbschatbot-vault.vault.azure.net/secrets/AZURE-AI-CHAT-DEPLOYMENT-NAME/)"
    "AZURE_AI_EMBED_DEPLOYMENT_NAME" = "@Microsoft.KeyVault(SecretUri=https://gbschatbot-vault.vault.azure.net/secrets/AZURE-AI-EMBED-DEPLOYMENT-NAME/)"
    "AZURE_AI_EMBED_DIMENSIONS" = "@Microsoft.KeyVault(SecretUri=https://gbschatbot-vault.vault.azure.net/secrets/AZURE-AI-EMBED-DIMENSIONS/)"
    "AZURE_EXISTING_AIPROJECT_API_KEY" = "@Microsoft.KeyVault(SecretUri=https://gbschatbot-vault.vault.azure.net/secrets/AZURE-EXISTING-AIPROJECT-API-KEY/)"
    "AZURE_EXISTING_AIPROJECT_ENDPOINT" = "@Microsoft.KeyVault(SecretUri=https://gbschatbot-vault.vault.azure.net/secrets/AZURE-EXISTING-AIPROJECT-ENDPOINT/)"
    "AZURE_SEARCH_SERVICE_ENDPOINT" = "@Microsoft.KeyVault(SecretUri=https://gbschatbot-vault.vault.azure.net/secrets/AZURE-SEARCH-SERVICE-ENDPOINT/)"
    "AZURE_SEARCH_INDEX" = "@Microsoft.KeyVault(SecretUri=https://gbschatbot-vault.vault.azure.net/secrets/AZURE-SEARCH-INDEX/)"
    "AZURE_SEARCH_KEY" = "@Microsoft.KeyVault(SecretUri=https://gbschatbot-vault.vault.azure.net/secrets/AZURE-SEARCH-KEY/)"
}

foreach ($key in $kvSettings.Keys) {
    Write-Host "  Setting: $key" -ForegroundColor Gray
    $value = $kvSettings[$key]
    
    # Use cmd to avoid PowerShell parsing issues with @ and parentheses
    cmd /c "az webapp config appsettings set --name gbs-chatbot-webapp --resource-group gbs-chatbot-resource-group --settings `"$key=$value`" --output none 2>nul"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to set $key" -ForegroundColor Red
        exit 1
    }
}

Write-Host "`nRestarting web app..." -ForegroundColor Cyan
az webapp restart --name gbs-chatbot-webapp --resource-group gbs-chatbot-resource-group

Write-Host "`n✅ Web app configured!" -ForegroundColor Green
Write-Host "URL: https://gbs-chatbot-webapp.azurewebsites.net" -ForegroundColor Cyan
Write-Host "`nTo view logs:" -ForegroundColor Yellow
Write-Host "  az webapp log tail --name gbs-chatbot-webapp --resource-group gbs-chatbot-resource-group" -ForegroundColor Gray
