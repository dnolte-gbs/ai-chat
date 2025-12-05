# Deploy container to Azure Container Instances
# This script deploys the app with proper timeout settings for streaming responses

Write-Host "Deploying container to Azure Container Instances..." -ForegroundColor Green

az container create `
  --resource-group $env:RES_GROUP `
  --name gbs-chatbot-container `
  --image "$env:ACR_NAME.azurecr.io/gbs-azure-chatbot:latest" `
  --registry-login-server "$env:ACR_NAME.azurecr.io" `
  --registry-username $(az keyvault secret show --vault-name $env:AKV_NAME --name "$env:ACR_NAME-pull-usr" --query value -o tsv) `
  --registry-password $(az keyvault secret show --vault-name $env:AKV_NAME --name "$env:ACR_NAME-pull-pwd" --query value -o tsv) `
  --secure-environment-variables `
    PORT=80 `
    RUNNING_IN_PRODUCTION=true `
    GUNICORN_TIMEOUT=300 `
    AZURE_CLIENT_ID=$(az keyvault secret show --vault-name $env:AKV_NAME --name AZURE-CLIENT-ID --query value -o tsv) `
    AZURE_AI_CHAT_DEPLOYMENT_NAME=$(az keyvault secret show --vault-name $env:AKV_NAME --name AZURE-AI-CHAT-DEPLOYMENT-NAME --query value -o tsv) `
    AZURE_AI_EMBED_DEPLOYMENT_NAME=$(az keyvault secret show --vault-name $env:AKV_NAME --name AZURE-AI-EMBED-DEPLOYMENT-NAME --query value -o tsv) `
    AZURE_AI_EMBED_DIMENSIONS=$(az keyvault secret show --vault-name $env:AKV_NAME --name AZURE-AI-EMBED-DIMENSIONS --query value -o tsv) `
    AZURE_EXISTING_AIPROJECT_API_KEY=$(az keyvault secret show --vault-name $env:AKV_NAME --name AZURE-EXISTING-AIPROJECT-API-KEY --query value -o tsv) `
    AZURE_EXISTING_AIPROJECT_ENDPOINT=$(az keyvault secret show --vault-name $env:AKV_NAME --name AZURE-EXISTING-AIPROJECT-ENDPOINT --query value -o tsv) `
  --assign-identity $env:USER_IDENTITY_ID `
  --dns-name-label "acr-tasks-$env:ACR_NAME" `
  --os-type Linux `
  --cpu 1 `
  --memory 1.5 `
  --query '{FQDN:ipAddress.fqdn}' `
  --output table

Write-Host "Container deployment complete!" -ForegroundColor Green
