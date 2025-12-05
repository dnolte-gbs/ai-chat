# Azure AD Authentication Setup Summary

## Overview

Azure AD Authentication (Easy Auth) has been successfully enabled for the GBS Chatbot Web App. Users must now sign in with their Microsoft/Azure AD account to access the application.

## Configuration Details

### App Registration
- **Name**: `gbs-chatbot-webapp`
- **Application (Client) ID**: `bb0dad1f-b0d0-4fdb-b4a2-016846068b53`
- **Tenant ID**: `f7b5ccec-02b7-4b66-8079-40f2e51e5346`
- **Redirect URI**: `https://gbs-chatbot-webapp.azurewebsites.net/.auth/login/aad/callback`

### Authentication Settings
- **Status**: ✅ Enabled
- **Provider**: Azure Active Directory
- **Action**: RedirectToLoginPage (unauthenticated users are redirected to login)
- **Web App URL**: https://gbs-chatbot-webapp.azurewebsites.net

## What This Means

### Security Benefits

✅ **User Authentication Required**
- All users must sign in with their Azure AD account
- No anonymous access to the chatbot

✅ **Organization-Only Access**
- Only users in your Azure AD tenant can access the app
- External users are blocked by default

✅ **Automatic User Identity**
- User information is available to the app via headers
- Audit trail of who accessed the application

✅ **Session Management**
- Azure handles session tokens and refresh
- Automatic logout after session expiration

### User Experience

**First Visit:**
1. User navigates to `https://gbs-chatbot-webapp.azurewebsites.net`
2. Automatically redirected to Microsoft login page
3. Signs in with work/school account
4. Redirected back to the chatbot
5. Can now use the application

**Subsequent Visits:**
- If session is still valid, user goes directly to the app
- If session expired, user is prompted to sign in again

## Testing Authentication

### Test the Login Flow

```powershell
# Open the app in browser
start https://gbs-chatbot-webapp.azurewebsites.net
```

**Expected behavior:**
1. Browser redirects to `https://login.microsoftonline.com`
2. Microsoft login page appears
3. Enter your Azure AD credentials
4. After successful login, redirect to the chatbot
5. You can now use the application

### Verify Configuration

```powershell
# Check authentication status
az webapp auth-classic show `
  --name gbs-chatbot-webapp `
  --resource-group gbs-chatbot-resource-group `
  --query "{Enabled:enabled, Action:unauthenticatedClientAction, ClientId:clientId}"
```

Expected output:
```
Enabled    Action               ClientId
---------  -------------------  ------------------------------------
True       RedirectToLoginPage  bb0dad1f-b0d0-4fdb-b4a2-016846068b53
```

## Managing User Access

### View App Registration

Portal Link:
```
https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/bb0dad1f-b0d0-4fdb-b4a2-016846068b53
```

Or navigate manually:
1. Open [Azure Portal](https://portal.azure.com)
2. Search for **App registrations**
3. Find `gbs-chatbot-webapp`

### Add/Remove Users

**Option 1: Enterprise Applications (Recommended)**

1. Open [Azure Portal](https://portal.azure.com)
2. Navigate to **Enterprise Applications**
3. Search for `gbs-chatbot-webapp`
4. Click **Users and groups**
5. Click **+ Add user/group**
6. Select users or groups to grant access
7. Assign the default role
8. Click **Assign**

**Option 2: All Users by Default**

By default, all users in your Azure AD tenant can access the app. To restrict:

1. Go to Enterprise Applications → `gbs-chatbot-webapp`
2. Click **Properties**
3. Set **Assignment required** to **Yes**
4. Click **Save**
5. Now only explicitly assigned users can access

### Remove User Access

1. Go to Enterprise Applications → `gbs-chatbot-webapp` → **Users and groups**
2. Select the user
3. Click **Remove**

## Advanced Configuration

### Allow External Users (Guest Access)

```powershell
# Allow guest users from specific domains
az webapp auth-classic update `
  --name gbs-chatbot-webapp `
  --resource-group gbs-chatbot-resource-group `
  --allowed-external-redirect-urls "https://yourdomain.com"
```

### Configure Token Store

```powershell
# Enable token store to access user tokens in your app
az webapp auth-classic update `
  --name gbs-chatbot-webapp `
  --resource-group gbs-chatbot-resource-group `
  --token-store true
```

### Add API Permissions

If your app needs to access other Microsoft APIs (e.g., Microsoft Graph):

1. Go to App Registration → **API permissions**
2. Click **+ Add a permission**
3. Select Microsoft Graph or other APIs
4. Choose required permissions
5. Click **Grant admin consent**

### Custom Login Page

To customize the login experience:

1. Go to App Registration → **Branding & properties**
2. Set:
   - Logo
   - Home page URL
   - Terms of service URL
   - Privacy statement URL
3. Save changes

## Troubleshooting

### Users Can't Sign In

**Check 1: User exists in Azure AD**
```powershell
az ad user show --id user@yourdomain.com
```

**Check 2: Assignment required**
- If "Assignment required" is Yes, explicitly add the user

**Check 3: Authentication is enabled**
```powershell
az webapp auth-classic show --name gbs-chatbot-webapp --resource-group gbs-chatbot-resource-group
```

### HTTP 401 Error at Callback

**Symptom:** Authentication redirects to callback URL but shows "HTTP ERROR 401"

**Cause:** ID token issuance not enabled in App Registration

**Solution:** Enable ID token issuance:
```powershell
az ad app update --id bb0dad1f-b0d0-4fdb-b4a2-016846068b53 --enable-id-token-issuance true
```

Then restart the web app:
```powershell
az webapp restart --name gbs-chatbot-webapp --resource-group gbs-chatbot-resource-group
```

**Note:** This fix is now included in the `enable-auth.ps1` script.

### Redirect Loop

**Solution:** Clear browser cookies and cache, then try again

**Alternative:** Verify redirect URI matches exactly:
```
https://gbs-chatbot-webapp.azurewebsites.net/.auth/login/aad/callback
```

### "AADSTS50011: The reply URL specified in the request does not match"

**Solution:** Update redirect URI in App Registration:

```powershell
az ad app update `
  --id bb0dad1f-b0d0-4fdb-b4a2-016846068b53 `
  --web-redirect-uris "https://gbs-chatbot-webapp.azurewebsites.net/.auth/login/aad/callback"
```

### Access User Information in App

User information is available via HTTP headers:

```python
# In your FastAPI app
from fastapi import Request

@app.get("/user")
async def get_user(request: Request):
    user_id = request.headers.get("X-MS-CLIENT-PRINCIPAL-ID")
    user_name = request.headers.get("X-MS-CLIENT-PRINCIPAL-NAME")
    return {"id": user_id, "name": user_name}
```

Available headers:
- `X-MS-CLIENT-PRINCIPAL-ID` - User's Azure AD object ID
- `X-MS-CLIENT-PRINCIPAL-NAME` - User's email/UPN
- `X-MS-CLIENT-PRINCIPAL-IDP` - Identity provider (aad)
- `X-MS-TOKEN-AAD-ID-TOKEN` - JWT ID token (if token store enabled)

## Disabling Authentication

If you need to disable authentication (e.g., for public demo):

```powershell
az webapp auth-classic update `
  --name gbs-chatbot-webapp `
  --resource-group gbs-chatbot-resource-group `
  --enabled false
```

**⚠️ Warning:** This makes the app publicly accessible again!

## Re-enabling Authentication

Run the setup script:

```powershell
.\enable-auth.ps1
```

Or manually:

```powershell
az webapp auth-classic update `
  --name gbs-chatbot-webapp `
  --resource-group gbs-chatbot-resource-group `
  --enabled true `
  --action LoginWithAzureActiveDirectory `
  --aad-client-id bb0dad1f-b0d0-4fdb-b4a2-016846068b53 `
  --aad-token-issuer-url "https://login.microsoftonline.com/f7b5ccec-02b7-4b66-8079-40f2e51e5346/v2.0"
```

## Monitoring and Logs

### View Sign-in Logs

1. Open [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory**
3. Click **Sign-in logs**
4. Filter by Application: `gbs-chatbot-webapp`
5. View who signed in, when, and from where

### Authentication Diagnostics

```powershell
# View authentication settings
az webapp auth-classic show `
  --name gbs-chatbot-webapp `
  --resource-group gbs-chatbot-resource-group

# View Web App logs
az webapp log tail `
  --name gbs-chatbot-webapp `
  --resource-group gbs-chatbot-resource-group
```

### Enable Diagnostic Logging

```powershell
# Enable authentication logs
az monitor diagnostic-settings create `
  --name auth-logs `
  --resource /subscriptions/{sub-id}/resourceGroups/gbs-chatbot-resource-group/providers/Microsoft.Web/sites/gbs-chatbot-webapp `
  --logs '[{"category": "AppServiceAuthenticationLogs","enabled": true}]' `
  --workspace {log-analytics-workspace-id}
```

## Security Best Practices

✅ **Enabled** - Azure AD Authentication  
✅ **Recommended** - Require assignment (restrict to specific users)  
✅ **Recommended** - Enable sign-in logs for audit trail  
⚠️ **Consider** - Multi-factor authentication (MFA) enforcement  
⚠️ **Consider** - Conditional access policies  
⚠️ **Consider** - IP restrictions for additional security  

### Enable MFA (Recommended)

1. Open [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** → **Security** → **Conditional Access**
3. Create a new policy:
   - Name: "Require MFA for Chatbot"
   - Users: Select users/groups
   - Cloud apps: Select `gbs-chatbot-webapp`
   - Grant controls: Require MFA
4. Enable policy

### Add IP Restrictions

```powershell
# Restrict to office network
az webapp config access-restriction add `
  --name gbs-chatbot-webapp `
  --resource-group gbs-chatbot-resource-group `
  --rule-name "Office" `
  --action Allow `
  --ip-address 203.0.113.0/24 `
  --priority 100
```

## Related Documentation

- [Create New App Registration](./create_new_app_registration.md)
- [Azure App Service Auth Setup](./azure_app_service_auth_setup.md)
- [Web App Deployment Guide](./webapp_deployment_guide.md)

## Quick Reference

### Key Information

| Setting | Value |
|---------|-------|
| App Registration | `gbs-chatbot-webapp` |
| Client ID | `bb0dad1f-b0d0-4fdb-b4a2-016846068b53` |
| Tenant ID | `f7b5ccec-02b7-4b66-8079-40f2e51e5346` |
| Web App URL | https://gbs-chatbot-webapp.azurewebsites.net |
| Redirect URI | https://gbs-chatbot-webapp.azurewebsites.net/.auth/login/aad/callback |
| Authentication | Enabled ✅ |

### Useful Commands

```powershell
# Check auth status
az webapp auth-classic show --name gbs-chatbot-webapp --resource-group gbs-chatbot-resource-group

# Enable auth
.\enable-auth.ps1

# Disable auth
az webapp auth-classic update --name gbs-chatbot-webapp --resource-group gbs-chatbot-resource-group --enabled false

# View logs
az webapp log tail --name gbs-chatbot-webapp --resource-group gbs-chatbot-resource-group

# Open app in browser
start https://gbs-chatbot-webapp.azurewebsites.net
```

## Support

For authentication issues:
1. Check user exists in Azure AD
2. Verify authentication is enabled
3. Check redirect URI matches exactly
4. Review sign-in logs in Azure Portal
5. Clear browser cache and try again

For application issues after authentication:
- See [Web App Deployment Guide](./webapp_deployment_guide.md)
- Check application logs
- Verify environment variables are set correctly

## Summary

✅ **Azure AD Authentication is enabled and working**  
✅ **Only authenticated users in your organization can access the chatbot**  
✅ **All access is logged and auditable**  
✅ **Session management is automatic**  

The GBS Chatbot Web App is now secure and ready for production use! 🔐
