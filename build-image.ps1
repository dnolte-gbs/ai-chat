Write-Host "Fixing file permissions..." -ForegroundColor Green
# Remove problematic files that cause permission issues
Remove-Item -Path "src/frontend/node_modules" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "src/.git" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Building Docker image (no cache)..." -ForegroundColor Green
docker build --no-cache -t "$($env:ACR_NAME).azurecr.io/gbs-azure-chatbot:latest" -f src/Dockerfile src/