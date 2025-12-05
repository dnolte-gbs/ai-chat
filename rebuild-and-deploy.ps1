# Complete rebuild and deploy script
# Rebuilds frontend, backend, and deploys to Azure

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Complete Rebuild and Deploy" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Step 1: Set environment variables
Write-Host "`n[1/6] Setting environment variables..." -ForegroundColor Green
.\set-env-vars.ps1

# Step 2: Rebuild frontend
Write-Host "`n[2/6] Rebuilding frontend..." -ForegroundColor Green
Push-Location src/frontend
Write-Host "  - Installing dependencies..." -ForegroundColor Gray
pnpm install
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to install frontend dependencies" -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host "  - Building frontend..." -ForegroundColor Gray
pnpm build
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build frontend" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

# Step 3: Login to Azure Container Registry
Write-Host "`n[3/6] Logging in to Azure Container Registry..." -ForegroundColor Green
az acr login --name $env:ACR_NAME
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to login to ACR" -ForegroundColor Red
    exit 1
}

# Step 4: Build the Docker image
Write-Host "`n[4/6] Building Docker image..." -ForegroundColor Green
Write-Host "  - Packaging frontend and backend into Docker image" -ForegroundColor Gray
.\build-image.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build image" -ForegroundColor Red
    exit 1
}

# Step 5: Push image to Azure Container Registry
Write-Host "`n[5/6] Pushing image to Azure Container Registry..." -ForegroundColor Green
Write-Host "  - Removing node_modules to avoid path length issues..." -ForegroundColor Gray
# Use robocopy to delete with long path support
if (Test-Path "src/frontend/node_modules") {
    $tempEmpty = New-Item -ItemType Directory -Path "$env:TEMP\empty_$(Get-Random)" -Force
    robocopy $tempEmpty "src/frontend/node_modules" /MIR /R:0 /W:0 | Out-Null
    Remove-Item $tempEmpty -Force
    Remove-Item "src/frontend/node_modules" -Force -ErrorAction SilentlyContinue
}
Write-Host "  - Uploading to ACR..." -ForegroundColor Gray
az acr build --registry $env:ACR_NAME --image gbs-azure-chatbot:latest --file src/Dockerfile src/
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to push image to ACR" -ForegroundColor Red
    exit 1
}

# Step 6: Deploy to Azure Container Instances
Write-Host "`n[6/6] Deploying to Azure Container Instances..." -ForegroundColor Green
.\deploy-container.ps1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to deploy container" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Rebuild and Deploy Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Your application should be live in a few moments." -ForegroundColor Gray
Write-Host "Check Azure Container Instances for the container status." -ForegroundColor Gray
