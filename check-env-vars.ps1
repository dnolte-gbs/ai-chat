# Check if the container has all required environment variables
Write-Host "Checking container environment variables..." -ForegroundColor Green

az container show --resource-group $env:RES_GROUP --name gbs-chatbot-container --query "containers[0].environmentVariables[].{Name:name,Value:secureValue}" --output table

Write-Host "`nNote: Secure values won't be displayed for security reasons." -ForegroundColor Yellow
Write-Host "Check if all these variables are set:" -ForegroundColor Cyan
Write-Host "  - AZURE_CLIENT_ID" -ForegroundColor Gray
Write-Host "  - AZURE_AI_CHAT_DEPLOYMENT_NAME" -ForegroundColor Gray
Write-Host "  - AZURE_EXISTING_AIPROJECT_ENDPOINT" -ForegroundColor Gray
Write-Host "  - AZURE_EXISTING_AIPROJECT_API_KEY" -ForegroundColor Gray
Write-Host "  - RUNNING_IN_PRODUCTION=true" -ForegroundColor Gray
