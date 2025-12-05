# Azure Web App Deployment Guide

This guide explains how to deploy the GBS Chatbot as an Azure Web App using the automated deployment script.

## Prerequisites

Before running the deployment script, ensure you have:

1. **Azure CLI** installed and authenticated (`az login`)
2. **Azure Container Registry (ACR)** with your chatbot image
3. **Azure Key Vault** with all required secrets
4. **User-assigned Managed Identity** created (named `gbs-chatbot-managed-identity`)
5. **Environment variables** configured (run `.\set-env-vars.ps1`)

## Required Key Vault Secrets

Your Key Vault must contain the following secrets:

### AI Service Configuration
- `AZURE-CLIENT-ID` - Client ID of the user-assigned managed identity
- `AZURE-EXISTING-AIPROJECT-API-KEY` - Azure AI Project API key
- `AZURE-EXISTING-AIPROJECT-ENDPOINT` - Azure AI Project endpoint URL
- `AZURE-AI-CHAT-DEPLOYMENT-NAME` - Name of the chat model deployment
- `AZURE-AI-EMBED-DEPLOYMENT-NAME` - Name of the embeddings model deployment
- `AZURE-AI-EMBED-DIMENSIONS` - Dimensions for embeddings (e.g., 1536)

### Search Service Configuration
- `AZURE-AI-SEARCH-ENDPOINT` - Azure AI Search service endpoint URL
- `AZURE-AI-SEARCH-INDEX-NAME` - Name of the search index
- `AZURE-AI-SEARCH-API-KEY` - Azure AI Search API key

### Container Registry Credentials
- `{ACR_NAME}-pull-usr` - ACR username for pulling images
- `{ACR_NAME}-pull-pwd` - ACR password for pulling images

## Deployment Steps

### 1. Prepare Your Environment

```powershell
# Load environment variables
.\set-env-vars.ps1
```

This sets up:
- `ACR_NAME` - Your Azure Container Registry name
- `AKV_NAME` - Your Azure Key Vault name
- `RES_GROUP` - Your Azure Resource Group name

### 2. Run the Deployment Script

```powershell
.\create-webapp.ps1
```

The script will automatically:

1. **Create App Service Plan** (B1 SKU - Basic tier)
2. **Create Web App** with Linux container support
3. **Enable Managed Identities**:
   - System-assigned identity (for Key Vault access)
   - User-assigned identity (for Azure AI Services)
4. **Grant Key Vault Access** to both identities
5. **Configure Container Registry** authentication
6. **Set Startup Command** for gunicorn
7. **Configure App Settings**:
   - Port configuration (80)
   - Production flag
   - Gunicorn timeout
8. **Configure Key Vault References** for all secrets
9. **Enable Logging** (application and Docker logs)
10. **Start the Web App**

### 3. Verify Deployment

After the script completes, verify the deployment:

```powershell
# Check app status
az webapp show --name gbs-chatbot-webapp --resource-group $env:RES_GROUP --query "state" -o tsv

# View live logs
az webapp log tail --name gbs-chatbot-webapp --resource-group $env:RES_GROUP

# Open the app in browser
start https://gbs-chatbot-webapp.azurewebsites.net
```

## Architecture Overview

### Managed Identities

The Web App uses two managed identities:

1. **System-Assigned Identity**
   - Automatically created with the Web App
   - Used for accessing Key Vault secrets
   - Deleted when the Web App is deleted

2. **User-Assigned Identity** (`gbs-chatbot-managed-identity`)
   - Shared identity that can be reused
   - Used for Azure AI Services and Azure Search authentication
   - Persists independently of the Web App

### Environment Variables

The app uses Key Vault references for secure configuration:

```
AZURE_CLIENT_ID=@Microsoft.KeyVault(SecretUri=https://your-vault.vault.azure.net/secrets/AZURE-CLIENT-ID/)
```

This pattern allows the app to retrieve secrets at runtime without storing sensitive values in configuration.

### Application Flow

1. **Startup**: Container starts, gunicorn launches the FastAPI app
2. **Authentication**: App uses managed identity to authenticate to Azure services
3. **Configuration**: Key Vault secrets are loaded via managed identity
4. **RAG Setup**: Search index is verified/created if needed
5. **Ready**: App accepts requests on port 80

## Configuration Details

### App Service Plan
- **Name**: `gbs-chatbot-plan`
- **SKU**: B1 (Basic)
- **OS**: Linux
- **Specs**: 1 core, 1.75GB RAM

### Web App
- **Name**: `gbs-chatbot-webapp`
- **Runtime**: Docker Container
- **Image**: `{ACR_NAME}.azurecr.io/gbs-azure-chatbot:latest`
- **Port**: 80
- **Startup Command**: `gunicorn --config gunicorn.conf.py api.main:create_app()`

### Key Environment Variables

| Variable | Purpose | Source |
|----------|---------|--------|
| `RUNNING_IN_PRODUCTION` | Enables managed identity auth | Direct value: `true` |
| `WEBSITES_PORT` | Container port | Direct value: `80` |
| `PORT` | Application port | Direct value: `80` |
| `GUNICORN_TIMEOUT` | Request timeout | Direct value: `300` |
| `AZURE_CLIENT_ID` | Managed identity client ID | Key Vault |
| `AZURE_AI_SEARCH_ENDPOINT` | Search service URL | Key Vault |
| `AZURE_AI_SEARCH_INDEX_NAME` | Search index name | Key Vault |
| `AZURE_AI_SEARCH_API_KEY` | Search API key | Key Vault |

## Troubleshooting

### Red Icons in Environment Variables

If you see red icons next to Key Vault references in the Azure Portal:

1. **Wait 1-2 minutes** for role assignments to propagate
2. **Refresh the page** in Azure Portal
3. **Verify permissions**:
   ```powershell
   # Check role assignments
   az role assignment list --assignee {IDENTITY_PRINCIPAL_ID} --scope {KEY_VAULT_ID}
   ```

### App Won't Start

Check the logs:
```powershell
az webapp log tail --name gbs-chatbot-webapp --resource-group $env:RES_GROUP
```

Common issues:
- **gunicorn errors**: Check startup command syntax
- **Import errors**: Verify container image is built correctly
- **Auth errors**: Ensure managed identities have proper permissions

### RAG Search Not Working

If you see "The RAG search will not be used" in logs:

1. Verify all search-related environment variables are set:
   - `AZURE_AI_SEARCH_ENDPOINT`
   - `AZURE_AI_SEARCH_INDEX_NAME`
   - `AZURE_AI_EMBED_DEPLOYMENT_NAME`

2. Check Key Vault secrets exist with correct names

3. Restart the app:
   ```powershell
   az webapp restart --name gbs-chatbot-webapp --resource-group $env:RES_GROUP
   ```

## Useful Commands

### View Logs
```powershell
# Stream live logs
az webapp log tail --name gbs-chatbot-webapp --resource-group $env:RES_GROUP

# Download logs
az webapp log download --name gbs-chatbot-webapp --resource-group $env:RES_GROUP --log-file logs.zip
```

### Restart App
```powershell
az webapp restart --name gbs-chatbot-webapp --resource-group $env:RES_GROUP
```

### Update Container Image
```powershell
az webapp config container set `
  --name gbs-chatbot-webapp `
  --resource-group $env:RES_GROUP `
  --container-image-name $env:ACR_NAME.azurecr.io/gbs-azure-chatbot:latest
```

### View Configuration
```powershell
# List all app settings
az webapp config appsettings list --name gbs-chatbot-webapp --resource-group $env:RES_GROUP -o table

# Show managed identities
az webapp identity show --name gbs-chatbot-webapp --resource-group $env:RES_GROUP
```

### Delete Resources
```powershell
# Delete Web App
az webapp delete --name gbs-chatbot-webapp --resource-group $env:RES_GROUP

# Delete App Service Plan
az appservice plan delete --name gbs-chatbot-plan --resource-group $env:RES_GROUP
```

## Security Best Practices

1. **Use Managed Identities**: Never store credentials in app settings
2. **Key Vault Integration**: All secrets should be in Key Vault
3. **RBAC Permissions**: Grant minimum required permissions
4. **Enable Logging**: Keep logs for troubleshooting and auditing
5. **HTTPS Only**: Production apps should enforce HTTPS (enabled by default)
6. **Regular Updates**: Keep container images updated with security patches

## Performance Considerations

- **App Service Plan**: Scale up to S1 or higher for production workloads
- **Timeout Settings**: Adjust `GUNICORN_TIMEOUT` based on expected request duration
- **Container Warmup**: First request after restart may be slow (cold start)
- **Scaling**: Enable autoscaling for variable load patterns

## Next Steps

After successful deployment:

1. Configure custom domain (optional)
2. Enable App Service Authentication (optional)
3. Set up Application Insights for monitoring
4. Configure deployment slots for zero-downtime updates
5. Implement CI/CD pipeline for automated deployments

## Support

For issues or questions:
- Check logs: `az webapp log tail`
- Review Azure Portal: Monitor and diagnose sections
- Consult Azure documentation: https://docs.microsoft.com/azure/app-service/
