# Enable Azure AD Authentication for GBS Chatbot Web App
# This script configures Azure App Service Authentication (Easy Auth)

Write-Host "`n=== Azure AD Authentication Setup ===" -ForegroundColor Cyan
Write-Host "This script enables Azure AD login requirement for the Web App.`n" -ForegroundColor Gray

# Load environment variables
if (Test-Path ".\set-env-vars.ps1") {
    . .\set-env-vars.ps1
} else {
    Write-Host "Error: set-env-vars.ps1 not found. Please run it first." -ForegroundColor Red
    exit 1
}

# Configuration
$APP_NAME = "gbs-chatbot-webapp"
$APP_REG_NAME = "gbs-chatbot-webapp"
$WEB_APP_URL = "https://$APP_NAME.azurewebsites.net"
$REDIRECT_URI = "$WEB_APP_URL/.auth/login/aad/callback"

Write-Host "Step 1: Checking for existing App Registration..." -ForegroundColor Cyan
$existingApp = az ad app list --display-name $APP_REG_NAME | ConvertFrom-Json

if ($existingApp.Count -gt 0) {
    Write-Host "  Found existing App Registration: $($existingApp[0].displayName)" -ForegroundColor Yellow
    $clientId = $existingApp[0].appId
    Write-Host "  Application (client) ID: $clientId" -ForegroundColor Gray
} else {
    Write-Host "  Creating new App Registration..." -ForegroundColor Gray
    $appReg = az ad app create `
        --display-name $APP_REG_NAME `
        --web-redirect-uris $REDIRECT_URI | ConvertFrom-Json
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create App Registration" -ForegroundColor Red
        exit 1
    }
    
    $clientId = $appReg.appId
    Write-Host "✅ App Registration created" -ForegroundColor Green
    Write-Host "  Display Name: $($appReg.displayName)" -ForegroundColor Gray
    Write-Host "  Application (client) ID: $clientId" -ForegroundColor Gray
}

Write-Host "`nStep 2: Getting Tenant ID..." -ForegroundColor Cyan
$tenantId = az account show --query tenantId -o tsv
Write-Host "  Tenant ID: $tenantId" -ForegroundColor Gray

Write-Host "`nStep 3: Enabling ID Token Issuance..." -ForegroundColor Cyan
az ad app update --id $clientId --enable-id-token-issuance true --output none
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to enable ID token issuance" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ ID token issuance enabled" -ForegroundColor Green

Write-Host "`nStep 4: Setting Application ID URI..." -ForegroundColor Cyan
$appIdUri = "api://$clientId"
az ad app update --id $clientId --identifier-uris $appIdUri --output none
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Warning: Could not set Application ID URI (may already exist)" -ForegroundColor Yellow
} else {
    Write-Host "  ✓ Application ID URI: $appIdUri" -ForegroundColor Green
}

Write-Host "`nStep 5: Configuring Web App Authentication..." -ForegroundColor Cyan
$issuer = "https://login.microsoftonline.com/$tenantId/v2.0"

az webapp auth-classic update `
    --name $APP_NAME `
    --resource-group $env:RES_GROUP `
    --enabled true `
    --action LoginWithAzureActiveDirectory `
    --aad-client-id $clientId `
    --aad-token-issuer-url $issuer `
    --aad-allowed-token-audiences $WEB_APP_URL $appIdUri `
    --output none

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to configure authentication" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Authentication configured with allowed audiences" -ForegroundColor Green

Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "✅ Azure AD Authentication Enabled!" -ForegroundColor Green
Write-Host "="*60 -ForegroundColor Cyan

Write-Host "`nAuthentication Details:" -ForegroundColor Cyan
Write-Host "  App Registration: $APP_REG_NAME" -ForegroundColor Gray
Write-Host "  Client ID: $clientId" -ForegroundColor Gray
Write-Host "  Tenant ID: $tenantId" -ForegroundColor Gray
Write-Host "  Redirect URI: $REDIRECT_URI" -ForegroundColor Gray

Write-Host "`nWhat This Means:" -ForegroundColor Cyan
Write-Host "  ✓ Users must sign in with Azure AD to access the app" -ForegroundColor Green
Write-Host "  ✓ Only users in your organization can access it" -ForegroundColor Green
Write-Host "  ✓ Anonymous access is blocked" -ForegroundColor Green

Write-Host "`nTesting:" -ForegroundColor Cyan
Write-Host "  1. Open: $WEB_APP_URL" -ForegroundColor Gray
Write-Host "  2. You will be redirected to Microsoft login" -ForegroundColor Gray
Write-Host "  3. Sign in with your Azure AD account" -ForegroundColor Gray
Write-Host "  4. You'll be redirected back to the app" -ForegroundColor Gray

Write-Host "`nManaging Access:" -ForegroundColor Cyan
Write-Host "  View App Registration in Azure Portal:" -ForegroundColor Gray
Write-Host "    https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/$clientId" -ForegroundColor White
Write-Host "`n  Add users/groups in Enterprise Applications:" -ForegroundColor Gray
Write-Host "    https://portal.azure.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Users/objectId/$clientId" -ForegroundColor White

Write-Host "`nDisable Authentication (if needed):" -ForegroundColor Yellow
Write-Host "  az webapp auth-classic update --name $APP_NAME --resource-group $env:RES_GROUP --enabled false`n" -ForegroundColor White
