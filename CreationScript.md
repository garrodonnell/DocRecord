# Registering the sample apps with the Microsoft identity platform and updating the configuration files using PowerShell

## Quick summary
1. Download [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.2), [PowerShellGet](https://learn.microsoft.com/en-us/powershell/scripting/gallery/installing-psget?view=powershell-7.2) and [Bicep tool](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)

1. Run PowerShell navigate to the directory

1. Run the script to create your Azure AD tenant and configure the code of the sample application accordingly.

   ```PowerShell
   cd .\Scripts\
   .\1-authentication.ps1
   ```

### More details

The following paragraphs:
  - [Goal of the provided scripts](#goal-of-the-provided-scripts)
    - [Presentation of the scripts](#presentation-of-the-scripts)
    - [Usage pattern for tests and DevOps scenarios](#usage-pattern-for-tests-and-DevOps-scenarios)
  - [How to use the app creation scripts?](#how-to-use-the-app-creation-scripts)
    - [Pre-requisites](#pre-requisites)
    - [Run the script and start running](#run-the-script-and-start-running)

## Goal of the provided scripts

### Presentation of the scripts

This sample comes with 5 PowerShell scripts and 1 bicep file, which automate the creation of the Azure Active Directory tenant, and the configuration of the code for this sample. Once you run them, you will only need to build the solution and you are good to test.

These scripts are:
- `1-authentication.ps1` which is a overall script combining the following scripts together except from `1-authentication-cleanup-except-last-CIAM.ps1`

- `1-authentication-setup-context-CIAM.ps1` which:
  - check and install the required modules.
  - set the policy and unblock the scripts to run.
  - set the account context to run the AzAccount PowerShell lines.

- `1-authentication-create-tenant-CIAM.ps1` which use [New-AzResourceGroupDeployment](https://learn.microsoft.com/en-us/powershell/module/az.resources/new-azresourcegroupdeployment?view=azps-9.1.0) with bicep file to deploy tenant. A tenant will be created in a resrouce group.

- `1-authentication-configurate-app-CIAM.ps1` which:
  - create the app registration
  - create a service principal for the app
  - create a user flow
  - customize the branding
  - creates a summary containing:
    - the identifier of the application
    - the AppId of the application
    - the url of its registration in the [Azure portal](https://portal.azure.com).

- `1-authentication-cleanup-except-last-CIAM.ps1` which cleans-up the Azure AD objects created by `1-authentication.ps1`. Note that this script delete applications, service principals, user flows and elevate the role but does not delete tenant. It prepare for the last delete click in the portal.

### Usage pattern

The `1-authentication.ps1` contain resource existence checking logic. It will skip the creation step for an existing resource and exit if the creation fails or an error occurs. So you can re-run the script.

## How to use the scripts?

### Pre-requisites
1. Download [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.2), [PowerShellGet](https://learn.microsoft.com/en-us/powershell/scripting/gallery/installing-psget?view=powershell-7.2) and [Bicep tool](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install)
1. Open PowerShell (On Windows, press  `Windows-R` and type `PowerShell` in the search window)
1. Navigate to the root directory of the project.

### Run the script and start running

1. Go to the `Scripts` folder. From the folder where you cloned the repo,
    ```PowerShell
    cd Scripts
    ```
1. open the [Azure portal](https://portal.azure.com). Copy the subcription ID and tenant ID (which subscritpion is under).
1. Run the scripts. Input the subscritpion ID and tenant ID accrording to the promot notice. During the running process, when window poping up, login in or grant access.
    ```PowerShell
    .\1-authentication.ps1
    ```


You're done. this just works!



