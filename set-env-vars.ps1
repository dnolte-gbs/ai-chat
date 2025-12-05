$env:ACR_NAME = 'gbschatbot'
$env:AKV_NAME = $env:ACR_NAME + "-vault"
$env:RES_GROUP = "gbs-chatbot-resource-group" 
$env:ROLE = "AcrPull"
$env:WORKSPACE_ID=$(az monitor log-analytics workspace show --resource-group $env:RES_GROUP --workspace-name gbschatbotloganalytics --query customerId -o tsv)
$env:WORKSPACE_KEY=$(az monitor log-analytics workspace get-shared-keys --resource-group $env:RES_GROUP --workspace-name gbschatbotloganalytics --query primarySharedKey -o tsv)

# Print out the set variables
Write-Host "Environment Variables Set:" -ForegroundColor Green
Write-Host "  ACR_NAME: $env:ACR_NAME"
Write-Host "  AKV_NAME: $env:AKV_NAME"
Write-Host "  RES_GROUP: $env:RES_GROUP"
Write-Host "  ROLE: $env:ROLE"
Write-Host "  WORKSPACE_ID: $env:WORKSPACE_ID"
Write-Host "  WORKSPACE_KEY: $(if ($env:WORKSPACE_KEY) { '[SET]' } else { '[NOT SET]' })" -ForegroundColor $(if ($env:WORKSPACE_KEY) { "Green" } else { "Yellow" })
Write-Host "`nVariables ready for use." -ForegroundColor Cyan