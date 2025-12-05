# Check deployment status
Write-Host "Checking container deployment..." -ForegroundColor Green

# Get container logs
Write-Host "`nContainer Logs (last 50 lines):" -ForegroundColor Cyan
az container logs --resource-group $env:RES_GROUP --name gbs-chatbot-container | Select-Object -Last 50

# Get container state
Write-Host "`n`nContainer State:" -ForegroundColor Cyan
az container show --resource-group $env:RES_GROUP --name gbs-chatbot-container --query "{Name:name,State:instanceView.state,RestartCount:instanceView.restartCount}" --output table

# Get container events
Write-Host "`n`nContainer Events:" -ForegroundColor Cyan
az container show --resource-group $env:RES_GROUP --name gbs-chatbot-container --query "instanceView.events[].{Time:lastTimestamp,Type:type,Message:message}" --output table
