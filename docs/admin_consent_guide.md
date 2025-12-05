# Admin Consent Guide for GBS Chatbot

## Issue: "Genehmigung erforderlich" (Approval Required)

When users try to sign in to the GBS Chatbot, they see a message saying "Genehmigung erforderlich" (Approval/Consent Required). This prevents them from accessing the application.

## Why This Happens

Azure App Service authentication uses Azure AD (Entra ID) to authenticate users. Even though the app doesn't request any special API permissions, Azure AD requires **admin consent** for the App Registration in organizations that have restrictive consent policies.

### What Was Checked

✅ **App Registration has no API permissions** - No special access requested  
✅ **Assignment not required** - All organization users are allowed  
✅ **Sign-in audience** - Set to organization only (AzureADMyOrg)  
✅ **ID token issuance** - Enabled correctly  

The consent requirement comes from your organization's Azure AD policy, not from the app configuration.

## Solution: Grant Admin Consent (One-Time)

Admin consent needs to be granted **once** by someone with admin privileges. After that, all users can sign in without any consent prompts.

### Required Admin Roles

One of these roles is needed to grant consent:
- **Global Administrator**
- **Application Administrator**
- **Cloud Application Administrator**

If you don't have these roles, you need to contact your IT department.

## How to Grant Admin Consent

### Method 1: Direct Consent Link (Easiest)

Send this link to your IT administrator. They should click it while signed in with their admin account:

```
https://login.microsoftonline.com/f7b5ccec-02b7-4b66-8079-40f2e51e5346/adminconsent?client_id=bb0dad1f-b0d0-4fdb-b4a2-016846068b53
```

**What happens:**
1. Admin clicks the link
2. They see a consent screen showing what the app needs (just basic sign-in)
3. They click "Accept"
4. Done! All users can now sign in

### Method 2: Azure Portal

1. Sign in to [Azure Portal](https://portal.azure.com) with admin account
2. Navigate to **App registrations**
3. Search for and click `gbs-chatbot-webapp`
4. In the left menu, click **API permissions**
5. Click the button **Grant admin consent for [Your Organization]**
6. Click **Yes** to confirm

### Method 3: PowerShell Command

If the admin has Azure CLI installed:

```powershell
az ad app permission admin-consent --id bb0dad1f-b0d0-4fdb-b4a2-016846068b53
```

## Email Template for IT Department

Copy and send this to your IT admin:

---

**Subject:** Admin Consent Request for Internal Chatbot Application

Hi IT Team,

I need one-time admin consent for an internal application registration to enable Azure AD authentication for our chatbot web app.

**App Details:**
- **App Registration Name:** gbs-chatbot-webapp
- **Application ID:** bb0dad1f-b0d0-4fdb-b4a2-016846068b53
- **Tenant ID:** f7b5ccec-02b7-4b66-8079-40f2e51e5346
- **Purpose:** Internal employee chatbot with Azure AD single sign-on
- **Permissions Requested:** None (only basic sign-in)
- **Access:** Organization users only

**To grant consent, please use one of these methods:**

**Option A - Direct Link (Fastest):**
Click this link while signed in as admin:
```
https://login.microsoftonline.com/f7b5ccec-02b7-4b66-8079-40f2e51e5346/adminconsent?client_id=bb0dad1f-b0d0-4fdb-b4a2-016846068b53
```

**Option B - Azure Portal:**
1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to App registrations
3. Find "gbs-chatbot-webapp"
4. Click "API permissions"
5. Click "Grant admin consent for [Organization]"
6. Click "Yes"

**Option C - PowerShell:**
```powershell
az ad app permission admin-consent --id bb0dad1f-b0d0-4fdb-b4a2-016846068b53
```

This is a **one-time action**. After consent is granted, all organization users can sign in to the chatbot without further admin intervention or consent prompts.

**Application URL:** https://gbs-chatbot-webapp.azurewebsites.net

Thank you!

---

## After Admin Consent is Granted

Once admin consent is granted:

1. **Test immediately** - Users should be able to sign in right away
2. **No more consent prompts** - Users will be redirected directly to the app
3. **Works for all users** - Every user in your organization can access the app

### Verify Consent Was Granted

Check the consent status:

```powershell
az ad app show --id bb0dad1f-b0d0-4fdb-b4a2-016846068b53 --query "requiredResourceAccess"
```

Or in Azure Portal:
1. Go to App registrations → gbs-chatbot-webapp
2. Click API permissions
3. Look for a green checkmark with "Granted for [Organization]"

## Temporary Workaround (Not Recommended)

If you need the app working immediately while waiting for admin consent, you can **temporarily disable authentication**:

```powershell
az webapp auth-classic update `
  --name gbs-chatbot-webapp `
  --resource-group gbs-chatbot-resource-group `
  --enabled false
```

⚠️ **WARNING:** This makes the app publicly accessible without any login requirement!

**To re-enable authentication after consent is granted:**

```powershell
.\enable-auth.ps1
```

## Troubleshooting

### "I'm an admin but can't grant consent"

You need one of these specific roles:
- Global Administrator
- Application Administrator
- Cloud Application Administrator

Regular admin roles (like User Administrator, Security Administrator) cannot grant app consent.

### "Consent was granted but users still see the prompt"

1. **Clear browser cache** - Users should clear cookies and cache
2. **Wait 5 minutes** - Changes can take a few minutes to propagate
3. **Check if correct app** - Verify the Application ID matches: bb0dad1f-b0d0-4fdb-b4a2-016846068b53

### "Can't find the app in App registrations"

Make sure you're looking in the correct tenant:
- **Tenant ID:** f7b5ccec-02b7-4b66-8079-40f2e51e5346
- Switch directories in Azure Portal if needed (top-right menu)

## Understanding the Consent Screen

When the admin grants consent, they'll see a screen showing:

**Permissions requested:**
- Sign you in and read your profile
- Maintain access to data you have given it access to

This is standard for Azure AD authentication and **does not** give the app access to any user data beyond basic profile information (name, email).

## Security Notes

✅ **App Registration is secure:**
- Only organization users can sign in (not external users)
- No special API permissions requested
- Uses Azure AD managed authentication
- All access is logged and auditable

✅ **After consent, the app can:**
- Verify user identity via Azure AD
- Read basic profile (name, email)
- Log who accessed the application

❌ **The app CANNOT:**
- Access user's OneDrive, SharePoint, or email
- Access other Microsoft 365 services
- Read or modify any user data
- Act on behalf of users in other apps

## Related Documentation

- [Authentication Setup Summary](./authentication_setup_summary.md) - Complete authentication configuration
- [Web App Deployment Guide](./webapp_deployment_guide.md) - Full deployment instructions
- [Azure App Service Auth Setup](./azure_app_service_auth_setup.md) - Detailed auth configuration

## Quick Reference

| Setting | Value |
|---------|-------|
| App Registration Name | gbs-chatbot-webapp |
| Application (Client) ID | bb0dad1f-b0d0-4fdb-b4a2-016846068b53 |
| Tenant ID | f7b5ccec-02b7-4b66-8079-40f2e51e5346 |
| Consent Link | https://login.microsoftonline.com/f7b5ccec-02b7-4b66-8079-40f2e51e5346/adminconsent?client_id=bb0dad1f-b0d0-4fdb-b4a2-016846068b53 |
| Required Admin Role | Global Administrator, Application Administrator, or Cloud Application Administrator |

## Summary

🔒 **The Issue:** Users see "Genehmigung erforderlich" when trying to sign in  
✅ **The Solution:** IT admin needs to grant consent once  
⏱️ **Time Required:** 2 minutes for admin to grant consent  
👥 **After Consent:** All organization users can sign in immediately  
🔐 **Security:** App only requests basic sign-in, no data access  

Once admin consent is granted, the GBS Chatbot will be fully accessible to all users in your organization! 🚀
