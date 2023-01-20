---

title: Customer Identity Access Management (CIAM) in Azure Active Directory | Microsoft Docs
description: Customer Identity Access Management (CIAM) in Azure Active Directory allows you to publish apps to people outside your organization. 

services: active-directory
ms.service: active-directory
ms.subservice: CIAM
ms.topic: overview
ms.date: 06/30/2022
ms.author: godonnell
author: garrodonnell
manager: celestedg

ms.collection: M365-identity-device-management
---

# Quick Start: Creating a CIAM Tenant and registering a sample app


Azure Active Directory (Azure AD) now offers a customer identity access management (CIAM) solution that lets you create secure, customized sign-in experiences for your customer-facing apps and services. With these built-in CIAM features, Azure AD can serve as the identity provider and access management service for your customer scenarios:

This sample comes with 5 PowerShell scripts and 1 bicep file, which automate the creation of the Azure Active Directory tenant, and the configuration of the code for this sample. Once you run them, you can build a sample app and test.

In this article you will complete the following work by script:
- Create a CIAM tenant.
- Create the app registration with offline_access and open_id permission under admin grant.
- Create a service principal for the app.
- Create a user flow as the default one.
- Create a customized localization branding as the default one.

 
## Pre-requisites
- [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.2). 
-  [PowerShellGet](https://learn.microsoft.com/en-us/powershell/scripting/gallery/installing-psget?view=powershell-7.2).
- [Bicep tool](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install).
- [Node.js](https://nodejs.org/en/).
- [CIAM Tenant Creation Scripts](media\Scripts.rar).

## Run the creation script
1. Open the [Azure portal](https://portal.azure.com)
1. Navigate to the **Directories +subscriptions page** page.
![Screenshot of the Azure portal highlighting the Directories and Subscriptions filter icon](media\directories-subscription-filter-icon.png)
1. Copy and save the **Directory ID** for your **Default Directory** somewhere for later use.
![Screenshot of the Azure portal Directories and Subscriptions page with the Directory ID highlighted](media\copy-tenant-id.png)
1. Open the [Azure portal](https://portal.azure.com). Search for and navigate to the 'Subscription' page. Copy and save the **Subsription ID** you wish to use somewhere for later use.*
![Screenshot of the Azure portal Subscriptions page with the Subscription ID highlighted.](media\copy-subsription-id.png)
1. Open PowerShell.
1. Navigate to the root directory of the downloaded sample.
1. Go to the `Scripts` folder and run the script with the following command.

   ```PowerShell
   cd .\Scripts\
   .\1-authentication.ps1

1. Enter the parameters recorded earlier when prompted *(tenantId - Directory ID ; subscriptionId - Subsription ID)*. During this process, two pop-ups will appear asking you to enter your identity information and provide consent for Microsoft Graph for PowerShell on your tenant.

1. After finishing running the creation script, open the [Azure portal](https://portal.azure.com), search for and navigate to the **Directories + subscriptions** page. 

1. Switch to the tenant newly created by the script.

1. Copy the link from the PowerShell interface and paste it into your browser (If you did not switch to the correct tenant in the previous step this step will not work). Copy **Application (client) ID** and **Directory (tenant) ID** which are used in later steps.
![Screenshot of the newly created CIAM Test App  information page in the Azure Portal](media\ciam-test-app.png)

1. You can now use [Javascript sample appliation](https://github.com/Azure-Samples/ms-identity-javascript-tutorial/) to test functionality. 

1. Clone or download the app to your local machine. 
1. Under **ms-identity-javascript-tutorial\1-Authentication\1-sign-in\App**, open **authConfig.js** to replace the **Application (client) ID** and **Directory (tenant) ID**.
![Screenshot showing authconfig.js with red boxes highlighting parameters that need to be changed](media\sample-update-clientid.png)

1. In PowerShell move to the directory where you have cloned / downloaded the sample app and run the following command to start the app.

   ```PowerShell
   cd \1-Authentication\1-sign-in\App
   npm install
   npm start
   ```

1. Open your browser and visit **http://localhost:3000/**. (Recommend using Edge private view mode).

1. Click **Sign-in** at the top right corner to start the authentication flow. If you choose **Can't access your account?**, you will jump into sign-up flow.

1. After filling in your email, one time passcode and new password, you complete the whole sign-up flow. The page will show your newly created information.

1. Click the **Sign-out** at the right-up corner to sign-out.

## Next steps
- [Customize the end-user experience](2-Customize-the-experience.md)
