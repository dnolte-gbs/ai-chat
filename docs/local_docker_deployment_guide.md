# Local Docker Deployment Guide

This guide explains how to run the GBS Chatbot locally using Docker for development and testing purposes.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Running the Application](#running-the-application)
- [Development Workflow](#development-workflow)
- [Troubleshooting](#troubleshooting)

## Overview

Local Docker deployment allows you to:
- Test changes quickly without deploying to Azure
- Develop and debug in an environment similar to production
- Run the full stack (frontend + backend) in a single container
- Test with real Azure services or mock data

**Two deployment methods:**
1. **Docker Compose** (Recommended) - Easy configuration with `.env` file
2. **Docker CLI** - Direct control with command-line arguments

## Prerequisites

### Required Software

- **Docker Desktop** - Version 20.x or higher
  - Download: https://www.docker.com/products/docker-desktop
  - Ensure it's running before starting

- **Git** - For cloning the repository

- **Text Editor** - VS Code, Notepad++, or any editor for `.env` files

### Optional Tools

- **Node.js 22.x + pnpm 10.x** - Only needed if building frontend separately
- **Python 3.13** - Only needed for local development without Docker

### Azure Resources

You'll need access to:
- **Azure AI Project** - For chat and embeddings
- **Azure AI Search** - For RAG (optional)
- Azure credentials (API keys or managed identity)

## Quick Start

### Method 1: Docker Compose (Easiest)

```powershell
# 1. Navigate to project directory
cd "d:\dev\products\AI Chat"

# 2. Create .env file from template
Copy-Item src\.env.sample src\.env

# 3. Edit src/.env with your Azure credentials
code src\.env  # or use any text editor

# 4. Build and run
docker-compose up --build
```

The app will be available at: **http://localhost:8085**

### Method 2: Docker CLI

```powershell
# 1. Build image
docker build -t gbs-azure-chatbot:latest -f src/Dockerfile src/

# 2. Run container
docker run -p 8085:50505 `
  -e AZURE_EXISTING_AIPROJECT_ENDPOINT="your-endpoint" `
  -e AZURE_EXISTING_AIPROJECT_API_KEY="your-api-key" `
  -e AZURE_AI_CHAT_DEPLOYMENT_NAME="gpt-4o-mini" `
  -e AZURE_AI_EMBED_DEPLOYMENT_NAME="text-embedding-3-large" `
  -e AZURE_AI_EMBED_DIMENSIONS="3072" `
  gbs-azure-chatbot:latest
```

## Configuration

### Environment Variables

Create `src/.env` file with the following variables:

#### Minimal Configuration (Without RAG)

```env
# Azure AI Project Configuration
AZURE_EXISTING_AIPROJECT_ENDPOINT=https://your-project.services.ai.azure.com/api/projects/your-project
AZURE_EXISTING_AIPROJECT_API_KEY=your-api-key-here

# Model Configuration
AZURE_AI_CHAT_DEPLOYMENT_NAME=gpt-4o-mini
AZURE_AI_EMBED_DEPLOYMENT_NAME=text-embedding-3-large
AZURE_AI_EMBED_DIMENSIONS=3072
```

#### Full Configuration (With RAG Search)

```env
# Azure AI Project Configuration
AZURE_EXISTING_AIPROJECT_ENDPOINT=https://your-project.services.ai.azure.com/api/projects/your-project
AZURE_EXISTING_AIPROJECT_API_KEY=your-api-key-here

# Model Configuration
AZURE_AI_CHAT_DEPLOYMENT_NAME=gpt-4o-mini
AZURE_AI_EMBED_DEPLOYMENT_NAME=text-embedding-3-large
AZURE_AI_EMBED_DIMENSIONS=3072

# Azure AI Search Configuration (Optional - for RAG)
AZURE_AI_SEARCH_ENDPOINT=https://your-search-service.search.windows.net
AZURE_AI_SEARCH_INDEX_NAME=your-index-name
AZURE_AI_SEARCH_API_KEY=your-search-api-key

# Connection String (Alternative to endpoint + API key)
# AZURE_AIPROJECT_CONNECTION_STRING=region.api.azureml.ms;subscription-id;resource-group;project-name
```

### Finding Azure Credentials

#### Azure AI Project Endpoint and API Key

1. Open [Azure Portal](https://portal.azure.com)
2. Navigate to your **Azure AI Project**
3. Click on **Keys and Endpoint** (left sidebar)
4. Copy:
   - **Endpoint** → `AZURE_EXISTING_AIPROJECT_ENDPOINT`
   - **Key 1** → `AZURE_EXISTING_AIPROJECT_API_KEY`

#### Azure AI Search Credentials

1. Open [Azure Portal](https://portal.azure.com)
2. Navigate to your **Azure AI Search** resource
3. Click on **Keys** (left sidebar)
4. Copy:
   - **URL** → `AZURE_AI_SEARCH_ENDPOINT`
   - **Primary admin key** → `AZURE_AI_SEARCH_API_KEY`
5. Click on **Indexes** to find your index name → `AZURE_AI_SEARCH_INDEX_NAME`

#### Model Deployment Names

1. Open [Azure AI Foundry](https://ai.azure.com)
2. Navigate to your project
3. Click on **Deployments** (left sidebar)
4. Copy the deployment names:
   - Chat model (e.g., `gpt-4o-mini`) → `AZURE_AI_CHAT_DEPLOYMENT_NAME`
   - Embeddings model (e.g., `text-embedding-3-large`) → `AZURE_AI_EMBED_DEPLOYMENT_NAME`

### Docker Compose Configuration

The `docker-compose.yml` file in the project root:

```yaml
services:
  app:
    build:
      context: ./src    
      dockerfile: Dockerfile
    image: gbs-azure-chatbot:latest
    container_name: gbs-azure-chatbot
    ports:
      - "8085:50505"  # Maps host:8085 to container:50505
    env_file:
      - ./src/.env
    environment:
      - PYTHONUNBUFFERED=1  # For real-time log output
```

**Port Mapping:**
- **8085** - Local machine (host) port
- **50505** - Container internal port (default in Dockerfile)

To change the local port, edit `docker-compose.yml`:
```yaml
ports:
  - "3000:50505"  # Now accessible at http://localhost:3000
```

## Running the Application

### Start the Application

#### Using Docker Compose

```powershell
# Build and start in foreground (with logs)
docker-compose up --build

# Or start in background (detached mode)
docker-compose up -d --build

# View logs (if running in background)
docker-compose logs -f
```

#### Using Docker CLI

```powershell
# Build image
docker build -t gbs-azure-chatbot:latest -f src/Dockerfile src/

# Run container
docker run -p 8085:50505 --env-file src/.env gbs-azure-chatbot:latest

# Or run in background
docker run -d -p 8085:50505 --name gbs-chatbot --env-file src/.env gbs-azure-chatbot:latest
```

### Access the Application

Open your browser and navigate to:
- **http://localhost:8085**

You should see the chatbot interface.

### Stop the Application

#### Docker Compose

```powershell
# Stop containers (keeps them)
docker-compose stop

# Stop and remove containers
docker-compose down

# Stop, remove, and clean up volumes
docker-compose down -v
```

#### Docker CLI

```powershell
# Stop container
docker stop gbs-chatbot

# Remove container
docker rm gbs-chatbot

# Or stop and remove in one command
docker rm -f gbs-chatbot
```

## Development Workflow

### Making Code Changes

#### Frontend Changes

If you modify frontend code (React/TypeScript):

```powershell
# Option 1: Rebuild everything with Docker
docker-compose down
docker-compose up --build

# Option 2: Build frontend locally first (faster iteration)
cd src/frontend
pnpm install
pnpm build
cd ../..
docker-compose up --build
```

#### Backend Changes

If you modify backend code (Python/FastAPI):

```powershell
# Rebuild and restart
docker-compose down
docker-compose up --build
```

### Hot Reload Development

For rapid development without rebuilding:

```powershell
# Run backend locally (outside Docker)
cd src
python -m pip install -r requirements.txt
python -m uvicorn api.main:create_app --factory --reload --port 50505

# Run frontend locally (in another terminal)
cd src/frontend
pnpm install
pnpm dev  # Runs on http://localhost:5173
```

### Viewing Logs

#### Docker Compose

```powershell
# View all logs
docker-compose logs

# Follow logs in real-time
docker-compose logs -f

# View specific service logs
docker-compose logs -f app

# Last 100 lines
docker-compose logs --tail=100
```

#### Docker CLI

```powershell
# View logs
docker logs gbs-chatbot

# Follow logs
docker logs -f gbs-chatbot

# Last 100 lines
docker logs --tail=100 gbs-chatbot
```

### Inspecting the Container

```powershell
# Check container status
docker ps

# View container details
docker inspect gbs-chatbot

# Execute commands inside container
docker exec -it gbs-chatbot bash

# View environment variables
docker exec gbs-chatbot env

# Check processes
docker exec gbs-chatbot ps aux
```

### Debugging

#### Enable Verbose Logging

Add to `src/.env`:
```env
LOG_LEVEL=DEBUG
PYTHONUNBUFFERED=1
```

Then rebuild:
```powershell
docker-compose up --build
```

#### Access Container Shell

```powershell
# Start a shell inside running container
docker exec -it gbs-chatbot bash

# Then inside the container:
cd /code
ls -la
cat api/main.py
```

#### Test Endpoints Manually

```powershell
# Health check
curl http://localhost:8085/health

# Test chat endpoint
Invoke-RestMethod -Uri "http://localhost:8085/api/chat" -Method POST -Body '{"message":"Hello"}' -ContentType "application/json"
```

## Troubleshooting

### Container Won't Start

#### Check Docker is Running

```powershell
docker version
```

If error, start Docker Desktop.

#### Check Port Availability

```powershell
# Check if port 8085 is in use
netstat -ano | findstr :8085

# Kill process using the port (if needed)
Stop-Process -Id <PID> -Force
```

#### View Startup Errors

```powershell
docker-compose logs
```

Common errors:
- **Port already in use**: Change port in `docker-compose.yml`
- **Missing .env file**: Create `src/.env` from `src/.env.sample`
- **Invalid credentials**: Check Azure endpoint and API key

### Build Fails

#### Clear Docker Cache

```powershell
# Remove old images
docker-compose down --rmi all

# Clean build cache
docker builder prune -a

# Rebuild
docker-compose up --build
```

#### Check Disk Space

```powershell
# View Docker disk usage
docker system df

# Clean up unused resources
docker system prune -a --volumes
```

#### Frontend Build Errors

If frontend build fails inside Docker:

```powershell
# Build frontend locally first to see detailed errors
cd src/frontend
pnpm install
pnpm build

# Fix any errors, then rebuild Docker image
cd ../..
docker-compose up --build
```

### Application Errors

#### "RAG search will not be used"

This is normal if you haven't configured Azure AI Search. The app will work without RAG.

To enable RAG, add to `src/.env`:
```env
AZURE_AI_SEARCH_ENDPOINT=https://your-search.search.windows.net
AZURE_AI_SEARCH_INDEX_NAME=your-index
AZURE_AI_SEARCH_API_KEY=your-key
```

#### Authentication Errors

**"invalid_scope" or "unauthorized"**

Check:
1. Endpoint URL is correct (should end with `/api/projects/your-project`)
2. API key is valid (not expired)
3. Model deployment names match your Azure deployments

```powershell
# Test credentials manually
$endpoint = "your-endpoint"
$apiKey = "your-api-key"
Invoke-RestMethod -Uri "$endpoint/info" -Headers @{"api-key"=$apiKey}
```

#### Module Import Errors

```
ModuleNotFoundError: No module named 'xxx'
```

**Solution:** Rebuild image (clears Python cache)
```powershell
docker-compose down --rmi all
docker-compose up --build
```

#### Slow Performance

**Container uses too much CPU/Memory:**

```powershell
# Check resource usage
docker stats gbs-chatbot

# Limit resources in docker-compose.yml:
services:
  app:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
```

### Network Issues

#### Can't Access Localhost

Try these URLs:
- http://localhost:8085
- http://127.0.0.1:8085
- http://host.docker.internal:8085 (from inside container)

#### Azure Services Unreachable

```powershell
# Test connectivity from container
docker exec gbs-chatbot curl -I https://your-endpoint.services.ai.azure.com

# Check DNS resolution
docker exec gbs-chatbot nslookup your-endpoint.services.ai.azure.com
```

If fails, check:
- Firewall settings
- VPN connection
- Corporate proxy

### Container Keeps Restarting

```powershell
# Check why it's restarting
docker logs gbs-chatbot

# View exit code
docker inspect gbs-chatbot --format='{{.State.ExitCode}}'
```

Common causes:
- Application crash on startup
- Missing required environment variables
- Port conflict

## Advanced Configuration

### Custom Port Configuration

Change container internal port:

```env
# Add to src/.env
PORT=8080
```

Update docker-compose.yml:
```yaml
ports:
  - "8085:8080"  # host:container
```

### Volume Mounting for Development

Edit `docker-compose.yml` to mount local code:

```yaml
services:
  app:
    volumes:
      - ./src/api:/code/api:ro  # Mount backend (read-only)
      - ./src/frontend/dist:/code/frontend/dist:ro  # Mount frontend
```

Now you can edit code without rebuilding (backend only, requires restart).

### Environment-Specific Configs

Create multiple `.env` files:

```powershell
# Development
src/.env.dev

# Staging
src/.env.staging

# Production
src/.env.prod
```

Use specific file:
```powershell
docker run --env-file src/.env.dev -p 8085:50505 gbs-azure-chatbot:latest
```

### Persistent Data

To persist application data:

```yaml
services:
  app:
    volumes:
      - chatbot-data:/code/data

volumes:
  chatbot-data:
```

### Docker Compose Profiles

For conditional services:

```yaml
services:
  app:
    # ... main app config

  debug:
    profiles: ["debug"]
    # ... debug-specific config
```

Run with profile:
```powershell
docker-compose --profile debug up
```

## Performance Optimization

### Reduce Build Time

**.dockerignore file:**
```
node_modules/
.git/
.vscode/
*.pyc
__pycache__/
.pytest_cache/
*.log
.DS_Store
```

### Multi-Stage Builds

The Dockerfile already uses multi-stage approach:
1. Install dependencies
2. Build frontend
3. Clean up build tools

### Caching Strategies

```powershell
# Use BuildKit for better caching
$env:DOCKER_BUILDKIT=1
docker-compose build

# Build with cache from registry
docker build --cache-from gbs-azure-chatbot:latest -t gbs-azure-chatbot:latest -f src/Dockerfile src/
```

## Testing

### Running Tests Locally

```powershell
# Run tests inside container
docker exec gbs-chatbot pytest /code/tests

# Run specific test file
docker exec gbs-chatbot pytest /code/tests/test_search_index_manager.py

# Run with coverage
docker exec gbs-chatbot pytest --cov=/code/api /code/tests
```

### Test Configuration

Create `src/.env.test`:
```env
# Use test credentials
AZURE_EXISTING_AIPROJECT_ENDPOINT=test-endpoint
AZURE_EXISTING_AIPROJECT_API_KEY=test-key
```

Run tests:
```powershell
docker run --env-file src/.env.test gbs-azure-chatbot:latest pytest
```

## Comparison: Local vs Azure

| Aspect | Local Docker | Azure Deployment |
|--------|-------------|------------------|
| Setup Time | Minutes | 15-30 minutes |
| Cost | Free (local resources) | Varies by service tier |
| Scalability | Single instance | Auto-scaling available |
| HTTPS | Manual setup | Automatic |
| Managed Identity | Not available | Supported |
| Custom Domain | Not available | Supported |
| Monitoring | Docker logs | App Insights, Log Analytics |
| Best For | Development, Testing | Production, Staging |

## Next Steps

After successful local testing:

1. **Push to Git** - Commit your changes
2. **Build for Azure** - Use `.\build-image.ps1`
3. **Deploy to Azure** - Use `.\create-webapp.ps1` or `.\deploy-container.ps1`
4. **Set up CI/CD** - Automate deployments

See also:
- [Container Deployment Guide](./container_deployment_guide.md) - Building and pushing to Azure
- [Web App Deployment Guide](./webapp_deployment_guide.md) - Production deployment

## Useful Commands Reference

### Quick Reference

```powershell
# Start everything
docker-compose up -d

# View logs
docker-compose logs -f

# Restart after changes
docker-compose restart

# Rebuild and restart
docker-compose up --build

# Stop everything
docker-compose down

# Clean everything
docker-compose down -v --rmi all

# Shell into container
docker exec -it gbs-chatbot bash

# Check resource usage
docker stats gbs-chatbot
```

### Health Checks

```powershell
# Check if app is responding
curl http://localhost:8085

# Check specific endpoint
Invoke-WebRequest -Uri http://localhost:8085/api/health

# View container health
docker inspect gbs-chatbot --format='{{.State.Health.Status}}'
```

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [React + Vite Documentation](https://vitejs.dev/)
- [Azure AI Documentation](https://learn.microsoft.com/azure/ai-services/)

## Support

For local development issues:
1. Check Docker Desktop is running
2. Verify `.env` file configuration
3. Review container logs: `docker-compose logs`
4. Try rebuilding: `docker-compose up --build`
5. Check the troubleshooting section above
6. Consult the main deployment guides

For Azure-specific issues, see:
- [Container Deployment Guide](./container_deployment_guide.md)
- [Web App Deployment Guide](./webapp_deployment_guide.md)
