# Docker Container Build and Deployment Guide

This guide provides comprehensive instructions for building, pushing, and deploying the GBS Chatbot as a Docker container to Azure.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Detailed Steps](#detailed-steps)
- [Deployment Options](#deployment-options)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)

## Overview

The deployment process consists of these main steps:

1. **Build Frontend** - Compile React/TypeScript frontend
2. **Build Docker Image** - Package frontend + backend into container
3. **Push to Registry** - Upload image to Azure Container Registry
4. **Deploy Container** - Run container in Azure (Container Instances or Web App)

## Prerequisites

### Required Tools

- **Docker Desktop** - For building container images
- **Azure CLI** - For Azure operations (`az`)
- **Node.js 22.x** - For frontend builds
- **pnpm 10.x** - Package manager for frontend
- **PowerShell** - For running deployment scripts

### Azure Resources

Before deployment, you need:

1. **Azure Container Registry (ACR)**
   - Name stored in `$env:ACR_NAME`
   - Pull credentials in Key Vault

2. **Azure Key Vault**
   - Name stored in `$env:AKV_NAME`
   - Contains all required secrets (see below)

3. **User-Assigned Managed Identity**
   - Named `gbs-chatbot-managed-identity`
   - Client ID stored in Key Vault as `AZURE-CLIENT-ID`

4. **Azure Resource Group**
   - Name stored in `$env:RES_GROUP`

### Required Key Vault Secrets

```
# AI Service Configuration
AZURE-CLIENT-ID
AZURE-EXISTING-AIPROJECT-API-KEY
AZURE-EXISTING-AIPROJECT-ENDPOINT
AZURE-AI-CHAT-DEPLOYMENT-NAME
AZURE-AI-EMBED-DEPLOYMENT-NAME
AZURE-AI-EMBED-DIMENSIONS

# Search Configuration
AZURE-AI-SEARCH-ENDPOINT
AZURE-AI-SEARCH-INDEX-NAME
AZURE-AI-SEARCH-API-KEY

# Container Registry
{ACR_NAME}-pull-usr
{ACR_NAME}-pull-pwd
```

## Quick Start

### Complete Rebuild and Deploy (Recommended)

For a full rebuild and deployment in one command:

```powershell
.\rebuild-and-deploy.ps1
```

This script:
1. Sets environment variables
2. Rebuilds the frontend
3. Logs into ACR
4. Builds the Docker image
5. Pushes to ACR
6. Deploys to Azure Container Instances

### Manual Step-by-Step

If you prefer manual control:

```powershell
# 1. Load environment variables
.\set-env-vars.ps1

# 2. Build frontend (optional if unchanged)
cd src/frontend
pnpm install
pnpm build
cd ../..

# 3. Login to ACR
.\login.ps1

# 4. Build Docker image
.\build-image.ps1

# 5. Push to ACR
.\push-image.ps1

# 6. Deploy container
.\deploy-container.ps1
```

## Detailed Steps

### Step 1: Environment Setup

```powershell
.\set-env-vars.ps1
```

This loads:
- `ACR_NAME` - Azure Container Registry name
- `AKV_NAME` - Azure Key Vault name
- `RES_GROUP` - Resource Group name
- Other environment-specific variables

**Verify setup:**
```powershell
.\check-env-vars.ps1
```

### Step 2: Build Frontend

The frontend is a React + TypeScript application built with Vite.

```powershell
cd src/frontend

# Install dependencies
pnpm install

# Build production bundle
pnpm build

cd ../..
```

**Output:** `src/frontend/dist/` directory with compiled static files

**Note:** The Dockerfile also builds the frontend, but pre-building can help catch errors early.

### Step 3: Build Docker Image

```powershell
.\build-image.ps1
```

This script:
1. Cleans up problematic files (`node_modules`, `.git`)
2. Builds Docker image with `--no-cache` flag
3. Tags as `{ACR_NAME}.azurecr.io/gbs-azure-chatbot:latest`

**Docker Build Process:**
- Base: `python:3.13.5-slim-bookworm`
- Installs Python dependencies from `requirements.txt`
- Installs Node.js 22.x and pnpm 10.x
- Builds React frontend inside container
- Configures gunicorn for production
- Exposes port 50505 (configurable via `PORT` env var)

**Manual Build:**
```powershell
docker build --no-cache -t "$env:ACR_NAME.azurecr.io/gbs-azure-chatbot:latest" -f src/Dockerfile src/
```

**Verify Image:**
```powershell
docker images | Select-String "gbs-azure-chatbot"
```

### Step 4: Login to Azure Container Registry

```powershell
.\login.ps1
```

Or manually:
```powershell
az acr login --name $env:ACR_NAME
```

**Troubleshooting Login:**
- Ensure you're logged into Azure: `az login`
- Verify ACR name: `echo $env:ACR_NAME`
- Check ACR exists: `az acr show --name $env:ACR_NAME`

### Step 5: Push Image to Registry

```powershell
.\push-image.ps1
```

This uploads the image to Azure Container Registry.

**Manual Push:**
```powershell
docker push "$env:ACR_NAME.azurecr.io/gbs-azure-chatbot:latest"
```

**Monitor Progress:**
The push shows progress for each layer. Large images may take several minutes.

**Verify Push:**
```powershell
az acr repository show --name $env:ACR_NAME --repository gbs-azure-chatbot
```

### Step 6: Deploy Container

You have two deployment options:

#### Option A: Azure Container Instances (ACI)

**Simple, serverless container hosting**

```powershell
.\deploy-container.ps1
```

This creates:
- Container name: `gbs-chatbot-container`
- CPU: 1 core
- Memory: 1.5 GB
- DNS: `acr-tasks-{ACR_NAME}.{region}.azurecontainer.io`
- Managed Identity: Attached for Azure service access

**Manual Deploy:**
```powershell
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
  --assign-identity /subscriptions/{sub-id}/resourcegroups/{rg}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/gbs-chatbot-managed-identity `
  --dns-name-label "gbs-chatbot-$env:ACR_NAME" `
  --os-type Linux `
  --cpu 1 `
  --memory 1.5 `
  --ports 80 `
  --output table
```

#### Option B: Azure Web App

**Production-ready with auto-scaling and custom domains**

```powershell
.\create-webapp.ps1
```

See [Web App Deployment Guide](./webapp_deployment_guide.md) for details.

**Key Differences:**

| Feature | Container Instances | Web App |
|---------|-------------------|---------|
| Setup Complexity | Simple | Moderate |
| Scaling | Manual only | Auto-scaling available |
| Custom Domains | Limited | Full support |
| SSL Certificates | Manual | Automatic (Let's Encrypt) |
| Managed Identity | Supported | Supported |
| Key Vault Integration | Environment vars | Key Vault references |
| Cost | Pay per second | App Service Plan |
| Best For | Dev/Test | Production |

## Deployment Options

### Development Deployment

For quick testing without building:

```powershell
# Run locally with Docker
docker run -p 80:80 `
  -e PORT=80 `
  -e AZURE_CLIENT_ID="your-client-id" `
  -e AZURE_EXISTING_AIPROJECT_API_KEY="your-key" `
  -e AZURE_EXISTING_AIPROJECT_ENDPOINT="your-endpoint" `
  "$env:ACR_NAME.azurecr.io/gbs-azure-chatbot:latest"
```

### Production Deployment

Use Azure Web App (recommended):
```powershell
.\create-webapp.ps1
```

Benefits:
- Automatic HTTPS
- Custom domain support
- Managed certificates
- Auto-scaling
- Deployment slots
- Built-in monitoring

## Container Configuration

### Environment Variables

The container requires these environment variables:

**Required:**
- `PORT` - Port to listen on (default: 80)
- `RUNNING_IN_PRODUCTION` - Set to `true` for managed identity auth
- `AZURE_CLIENT_ID` - Managed identity client ID

**AI Configuration:**
- `AZURE_EXISTING_AIPROJECT_ENDPOINT` - Azure AI Project endpoint
- `AZURE_EXISTING_AIPROJECT_API_KEY` - API key (or use managed identity)
- `AZURE_AI_CHAT_DEPLOYMENT_NAME` - Chat model deployment name
- `AZURE_AI_EMBED_DEPLOYMENT_NAME` - Embeddings model deployment name
- `AZURE_AI_EMBED_DIMENSIONS` - Embedding dimensions (e.g., 1536)

**Search Configuration (Optional):**
- `AZURE_AI_SEARCH_ENDPOINT` - Azure Search endpoint
- `AZURE_AI_SEARCH_INDEX_NAME` - Search index name
- `AZURE_AI_SEARCH_API_KEY` - Search API key

**Application Settings:**
- `GUNICORN_TIMEOUT` - Request timeout in seconds (default: 300)

### Resource Requirements

**Minimum:**
- CPU: 1 core
- Memory: 1 GB
- Disk: 2 GB

**Recommended (Production):**
- CPU: 2 cores
- Memory: 2-4 GB
- Disk: 5 GB

### Port Configuration

Default port is 50505 in Dockerfile, but can be overridden:

```powershell
# Container Instances
--ports 80 -e PORT=80

# Web App
WEBSITES_PORT=80
```

## Troubleshooting

### Build Issues

#### Frontend Build Fails

```powershell
# Check Node.js version
node --version  # Should be 22.x

# Check pnpm version
pnpm --version  # Should be 10.x

# Clear caches
cd src/frontend
pnpm store prune
rm -rf node_modules
pnpm install
```

#### Docker Build Fails

**Error: "no space left on device"**
```powershell
# Clean up Docker
docker system prune -a --volumes
```

**Error: "failed to solve with frontend dockerfile"**
```powershell
# Update Docker Desktop
# Or use legacy builder
$env:DOCKER_BUILDKIT=0
docker build -t ...
```

### Push Issues

#### Authentication Failed

```powershell
# Re-login to Azure
az login

# Re-login to ACR
az acr login --name $env:ACR_NAME
```

#### Push Timeout

```powershell
# Check Docker daemon settings
# Increase timeout in Docker Desktop settings
# Or push with retries
for ($i=0; $i -lt 3; $i++) {
    docker push "$env:ACR_NAME.azurecr.io/gbs-azure-chatbot:latest"
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 10
}
```

### Deployment Issues

#### Container Won't Start

**Check logs:**
```powershell
# Container Instances
az container logs --resource-group $env:RES_GROUP --name gbs-chatbot-container

# Web App
az webapp log tail --name gbs-chatbot-webapp --resource-group $env:RES_GROUP
```

**Common issues:**
- Missing environment variables
- Invalid managed identity
- Port conflicts
- Insufficient resources

#### "No such container" Error

```powershell
# List containers
az container list --resource-group $env:RES_GROUP -o table

# Delete and recreate
az container delete --resource-group $env:RES_GROUP --name gbs-chatbot-container --yes
.\deploy-container.ps1
```

#### Application Errors

**"RAG search will not be used"**
- Check search environment variables are set
- Verify search index exists
- Check managed identity has search permissions

**"invalid_scope" or auth errors**
- Verify managed identity is attached
- Check identity has required role assignments
- Ensure AZURE_CLIENT_ID is correct

**"Module not found" errors**
- Rebuild image: `.\build-image.ps1`
- Check requirements.txt is complete
- Verify Dockerfile COPY commands

### Performance Issues

#### Slow Container Startup

Container cold start can take 30-60 seconds. This is normal for:
- First-time startup
- After container restart
- After image update

**Reduce startup time:**
- Use Web App with "Always On" setting
- Pre-warm with health check endpoint
- Optimize Python imports

#### High Memory Usage

**Monitor:**
```powershell
# Container Instances
az container show --resource-group $env:RES_GROUP --name gbs-chatbot-container --query "containers[0].resources"

# Web App
az webapp show --name gbs-chatbot-webapp --resource-group $env:RES_GROUP --query "siteConfig"
```

**Solutions:**
- Increase memory allocation
- Optimize model loading
- Use gunicorn workers: `--workers 2`

## Maintenance

### Updating the Application

#### Update Code Only

```powershell
# Rebuild and push
.\build-image.ps1
.\push-image.ps1

# Container Instances - delete and recreate
az container delete --resource-group $env:RES_GROUP --name gbs-chatbot-container --yes
.\deploy-container.ps1

# Web App - pull latest image
az webapp config container set `
  --name gbs-chatbot-webapp `
  --resource-group $env:RES_GROUP `
  --container-image-name "$env:ACR_NAME.azurecr.io/gbs-azure-chatbot:latest"
az webapp restart --name gbs-chatbot-webapp --resource-group $env:RES_GROUP
```

#### Update Configuration

**Container Instances:**
```powershell
# Must delete and recreate with new config
az container delete --resource-group $env:RES_GROUP --name gbs-chatbot-container --yes
.\deploy-container.ps1
```

**Web App:**
```powershell
# Update app settings
az webapp config appsettings set `
  --name gbs-chatbot-webapp `
  --resource-group $env:RES_GROUP `
  --settings SETTING_NAME=value

# Restart to apply
az webapp restart --name gbs-chatbot-webapp --resource-group $env:RES_GROUP
```

### Viewing Logs

**Container Instances:**
```powershell
# View logs
az container logs --resource-group $env:RES_GROUP --name gbs-chatbot-container

# Follow logs (stream)
az container attach --resource-group $env:RES_GROUP --name gbs-chatbot-container
```

**Web App:**
```powershell
# Stream logs
az webapp log tail --name gbs-chatbot-webapp --resource-group $env:RES_GROUP

# Download logs
az webapp log download --name gbs-chatbot-webapp --resource-group $env:RES_GROUP --log-file logs.zip
```

### Monitoring

**Container Instances:**
```powershell
# Show details
az container show --resource-group $env:RES_GROUP --name gbs-chatbot-container

# Check status
az container show --resource-group $env:RES_GROUP --name gbs-chatbot-container --query "instanceView.state"
```

**Web App:**
```powershell
# Open in portal
start "https://portal.azure.com/#@/resource/subscriptions/.../resourceGroups/$env:RES_GROUP/providers/Microsoft.Web/sites/gbs-chatbot-webapp/appServices"

# View metrics
az monitor metrics list --resource /subscriptions/.../gbs-chatbot-webapp
```

### Cleanup

**Delete Container Instances:**
```powershell
az container delete --resource-group $env:RES_GROUP --name gbs-chatbot-container --yes
```

**Delete Web App:**
```powershell
az webapp delete --name gbs-chatbot-webapp --resource-group $env:RES_GROUP --yes
az appservice plan delete --name gbs-chatbot-plan --resource-group $env:RES_GROUP --yes
```

**Clean up local Docker:**
```powershell
# Remove images
docker rmi "$env:ACR_NAME.azurecr.io/gbs-azure-chatbot:latest"

# Full cleanup
docker system prune -a --volumes
```

## Best Practices

### Image Management

1. **Tag versions**: Use semantic versioning
   ```powershell
   docker tag "$env:ACR_NAME.azurecr.io/gbs-azure-chatbot:latest" "$env:ACR_NAME.azurecr.io/gbs-azure-chatbot:v1.2.3"
   ```

2. **Multi-stage builds**: Optimize Dockerfile for size
3. **Security scanning**: Use `az acr check-health` and vulnerability scans
4. **Regular updates**: Keep base images and dependencies updated

### Deployment Strategy

1. **Use deployment slots** (Web App) for zero-downtime updates
2. **Test in staging** before production
3. **Implement health checks** for monitoring
4. **Use Application Insights** for telemetry
5. **Set up alerts** for errors and performance issues

### Security

1. **Never commit secrets** to source control
2. **Use Key Vault** for all sensitive data
3. **Enable managed identities** instead of API keys
4. **Restrict network access** with private endpoints
5. **Keep container registry private**
6. **Regular security updates** for base images

### Cost Optimization

1. **Container Instances**:
   - Stopped containers don't incur charges
   - Use appropriate CPU/memory (avoid over-provisioning)
   - Delete when not in use

2. **Web App**:
   - Use auto-scaling to match demand
   - Consider reserved instances for production
   - Use Basic tier for dev/test

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build and Deploy

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Build and push image
        run: |
          az acr login --name ${{ secrets.ACR_NAME }}
          docker build -t ${{ secrets.ACR_NAME }}.azurecr.io/gbs-azure-chatbot:${{ github.sha }} -f src/Dockerfile src/
          docker push ${{ secrets.ACR_NAME }}.azurecr.io/gbs-azure-chatbot:${{ github.sha }}
      
      - name: Deploy to Web App
        run: |
          az webapp config container set \
            --name gbs-chatbot-webapp \
            --resource-group ${{ secrets.RESOURCE_GROUP }} \
            --container-image-name ${{ secrets.ACR_NAME }}.azurecr.io/gbs-azure-chatbot:${{ github.sha }}
```

## Additional Resources

- [Azure Container Registry Documentation](https://docs.microsoft.com/azure/container-registry/)
- [Azure Container Instances Documentation](https://docs.microsoft.com/azure/container-instances/)
- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [Docker Documentation](https://docs.docker.com/)
- [Web App Deployment Guide](./webapp_deployment_guide.md)

## Support

For issues:
1. Check logs first
2. Verify all prerequisites
3. Review error messages carefully
4. Consult Azure documentation
5. Open an issue in the repository
