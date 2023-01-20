[CmdletBinding()]
param(
    [Parameter(Mandatory=$True, HelpMessage='Tenant ID where the subscription ID is located')]
    [string] $tenantId,
    [Parameter(Mandatory=$True, HelpMessage='Subscription ID used to pay for the new tenant ')]
    [string] $subscriptionId,
    [Parameter(Mandatory=$False, HelpMessage='Resource Group Name')]
    [string] $resourceGroupName,
    [Parameter(Mandatory=$False, HelpMessage='Prefix for Tenant (Default: "ciamtest" + 5 digit random string)')]
    [string] $tenantPrefix,
    [Parameter(Mandatory=$False, HelpMessage='Location for Resource Group if it is created (Default: "northeurope")')]
    [string] $resourceGroupLocation,
    [Parameter(Mandatory=$False, HelpMessage='Display Name for application (Default: "CIAM Test App")')]
    [string] $applicationName,
    [Parameter(Mandatory=$False, HelpMessage='Graph environment to use while running the script (Default: "Global")')]
    [string] $environmentName
)

# $ErrorActionPreference = "Stop"


Function InstallModule{
    if ((Get-Module -ListAvailable -Name 'Az.Accounts') -eq $null) {
        write-host "Installing Az.Accounts module"
        Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
    }
    
    if ((Get-Module -ListAvailable -Name 'Microsoft.Graph') -eq $null) {
        write-host "Installing Microsoft.Graph module"
        Install-Module Microsoft.Graph -Scope CurrentUser
    }
    
    write-host "Set execution policy-RemoteSigned; scope-CurrentUser "
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Unblock-File *.ps1
}

Function SetContext{
    write-host "Clear context"
    Clear-AzContext -Scope CurrentUser -Force
    write-host "Set context"
    $temp = Connect-AzAccount -TenantId $tenantId
    $temp = Set-AzContext -Subscription $subscriptionId
    write-host "Show context"
    Get-AzContext
}

if (!$resourceGroupName) {
    $resourceGroupName = "ciamtest"
}
if (!$tenantPrefix) {
    $tenantPrefix = "ciamtest" + (Get-Random -Minimum 10000 -Maximum 99999)
}
if (!$resourceGroupLocation) {
    $resourceGroupLocation = "northeurope"
}
if (!$environmentName)
{
    $environmentName = "Global"
}
if (!$applicationName) {
    $applicationName = "CIAM Test App"
}

Function CreateTenant
{
    $group = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    if ($group -eq $null) {
        write-host "Creating resource group $resourceGroupName"
        New-AzResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
    }else{
        write-host "Resource group $resourceGroupName exists. Skip creation."
    }

    $tenantName = $tenantPrefix + ".onmicrosoft.com"
    write-host "Checking tenant existence $tenantName"
    $tenant = Get-AzTenant -Tenant $tenantName

    if($tenant -eq $null){
        write-host "Creating Tenant ($tenantPrefix) in Resource Group ($resourceGroupName)"
        $params = @{
            displayName = $tenantPrefix
        }
        $out=New-AzResourceGroupDeployment `
            -ResourceGroupName $resourceGroupName `
            -TemplateFile create-ciam-tenant.bicep `
            -TemplateParameterObject $params `

        if ($out.ProvisioningState -eq 'Succeeded') {
            write-host "Tenant created successfully"
            write-host "    Tenant ID   : $($out.Outputs.tenantId.value)"
            write-host "    Tenant Name : $($out.Outputs.tenantName.value)"
            return $newTenantId
        } else {
            write-host "Tenant creation failed. Exiting..."
            exit
        }
    }else{
        write-host "Tenant $tenantName exists."
            return
    }
}


Function CreateApplication($tenantName)
{
    $userFlowName="SISU"
    $redirectUris="http://localhost:3000"
    
    $scopes = @(
         "Application.ReadWrite.All",
         "IdentityUserFlow.ReadWrite.All",
         "Organization.ReadWrite.All",
         "User.Read.All"
    )

    $tenantName = $tenantPrefix + ".onmicrosoft.com"
    $tenantId = (Get-AzTenant -Tenant $tenantName).Id

    Connect-Graph -TenantId $tenantId -Scopes $scopes -Environment $environmentName


    $tenant = Get-MgOrganization
    $tenantName = ($tenant.VerifiedDomains | Where { $_.IsDefault -eq $True }).Name

    # TODO(JC): Why isn't there a standard command to do this?  Surely it's common operation?  Check with Kris
    # Get the user running the script to add the user as the app owner
    # $user = Invoke-MgGraphRequest -Method GET https://graph.microsoft.com/v1.0/me
    $user = Get-MgUser

    # 1. Create the app registration with offline_access and open_id permission
    # NOTE: We check for uniqueness of App by DisplayName as there is no key other than Id, which we can't know
    #       until after we create the app
    $resAcc = New-Object -TypeName Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphRequiredResourceAccess
    $resAcc.ResourceAppId = "00000003-0000-0000-c000-000000000000"

    $res1 = New-Object -TypeName Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphResourceAccess
    $res1.Id = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182"
    $res1.Type = "Scope"

    $res2 = New-Object -TypeName Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphResourceAccess
    $res2.Id = "37f7f235-527c-4136-accd-4a02d197296e"
    $res2.Type = "Scope"
    $resAcc.ResourceAccess = $res1,$res2

    $app = Get-MgApplication | Where-Object {$_.displayName -eq $applicationName} |Select-Object -first 1
    if ($app -eq $null) {
        write-host "Creating Single Page Application..."
        # JC: Changed SignIn Audience to AzureADandPersonalMicrosoftAccount for CIAM tenant as in docs
        $app = New-MgApplication `
            -displayName $applicationName ` `
            -SignInAudience "AzureADandPersonalMicrosoftAccount" `
            -Spa @{ RedirectUris = $redirectUris } `
            -RequiredResourceAccess $resAcc

        if ($app -eq $null) {
            write-host "  Application creation failed. Exiting..."
            exit
        } else {
            write-host "  Application created: $($app.Id)"
        }
    } else {
        write-host "  Application already exists: $($app.Id) ($($app.DisplayName))"
    }

    # 2. Create a service principal for the app
    $sp = (Get-MgServicePrincipal -Filter "DisplayName eq '$applicationName'") |Select-Object -first 1
    if ($sp -eq $null) {
        write-host "Creating Service Principal..."

        # Tags come from the JS SPA example script
        $sp = New-MgServicePrincipal `
            -AppId $app.AppId `
            -Tags {WindowsAzureActiveDirectoryIntegratedApp}
        if ($sp -eq $null) {
            write-host "  Service Principal creation failed. Exiting..."
            exit
        } else {
            write-host "  Service Principal created: $($sp.Id)"
        }
    } else {
        write-host "  Service Principal already exists: $($sp.Id)"
    }

    # 3. Create a user flow
    # TODO(JC): No native Graph commands for the UserFlow API yet.  Rewrite once it is published
    
    $userFlow = Invoke-MgGraphRequest -Method GET https://graph.microsoft.com/beta/identity/AuthenticationEventsFlows?`$filter="displayName eq '$userFlowName'"

    if ($userFlow.value.count -eq 0) {
        write-host "Creating User Flow ($userFlowName)..."
        $params = @"
        {
            "@odata.type": "#microsoft.graph.externalUsersSelfServiceSignUpEventsFlow",
            "priority": 50,
            "conditions": {
                "applications": {
                }
            },
            "displayName": "SISU",
            "onInteractiveAuthFlowStart": {
                "@odata.type": "#microsoft.graph.onInteractiveAuthFlowStartExternalUsersSelfServiceSignUp",
                "isSignUpAllowed": true
            },
            "onAuthenticationMethodLoadStart": {
                "@odata.type": "#microsoft.graph.onAuthenticationMethodLoadStartExternalUsersSelfServiceSignUp",
                "identityProviders": [
                    {
                        "id": "AADSignup-OAUTH"
                    },
                    {
                        "id": "EmailPassword-OAUTH"
                    }
                ]
            },
            "onAttributeCollection": {
                "@odata.type": "#microsoft.graph.onAttributeCollectionExternalUsersSelfServiceSignUp",
                "attributes": [
                    {
                        "@odata.type": "#microsoft.graph.identityUserFlowAttribute",
                        "id": "email",
                        "displayName": "Email Address"
                    },
                    {
                        "@odata.type": "#microsoft.graph.identityUserFlowAttribute",
                        "id": "displayName"
                    }
                ],
                "attributeCollectionPage": {
                    "views": [
                        {
                            "inputs": [
                                {
                                    "attribute": "email",
                                    "label": "Email Address",
                                    "inputType": "Text",
                                    "hidden": true,
                                    "editable": false,
                                    "writeToDirectory": true,
                                    "required": true,
                                    "validationRegEx": "^[a-zA-Z0-9.!#$%&amp;&#8217;'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:.[a-zA-Z0-9-]+)*$"
                                },
                                {
                                    "attribute": "displayName",
                                    "label": "Display Name",
                                    "inputType": "text",
                                    "hidden": false,
                                    "editable": true,
                                    "writeToDirectory": true,
                                    "required": false,
                                    "validationRegEx": "^[a-zA-Z_][0-9a-zA-Z_ ]*[0-9a-zA-Z_]+$"
                                }
                            ]
                        }
                    ]
                },
                "accessPackages": []
            },
            "onUserCreateStart": {
                "@odata.type": "#microsoft.graph.onUserCreateStartExternalUsersSelfServiceSignUp",
                "accessPackages": [],
                "userTypeToCreate": "member"
            }
        }
"@
        $userFlowPost = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/identity/AuthenticationEventsFlows" -Body $params

    } else {
        write-host "  User Flow already exists: $($userFlow.id) ($userFlowName)"
    }

     # TODO(JC): We seem to need a sleep here for first time app is created
     write-host "  Waiting for app to be created..."
     Start-Sleep -Seconds 10


    $userFlow = Invoke-MgGraphRequest -Method GET https://graph.microsoft.com/beta/identity/AuthenticationEventsFlows?`$filter="displayName eq '$userFlowName'"

     if ($userFlow.value.id) {
        write-host "Adding User Flow to application..."
        $params = @"
        {
            "@odata.type": "#microsoft.graph.authenticationConditionApplication",
            "appId": "$($app.AppId)"
        }
"@
        $uri = "https://graph.microsoft.com/beta/identity/AuthenticationEventsFlows/$($userFlow.value.id)/conditions/applications/includeApplications"
        $result = $null
        do{
            $result = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $params
        }until($result)
     }

    
     # 4. Customize-the-experience
    $params = @{
        SignInPageText = "Default"
        UsernameHintText = "DefaultHint"
    }
    $defaultBranding = Get-MgOrganizationBrandingLocalization -OrganizationId  $tenantId
    if ($defaultBranding.count -eq 0)
    {
        write-host "Creating Default Branding..."
        
        $defaultBranding = New-MgOrganizationBrandingLocalization -OrganizationId  $tenantId -BodyParameter $params
        if ($defaultBranding -eq $null) {
            write-host "  Default Branding creation failed. Exiting..."
            exit
        } else {
            write-host "  Default Branding created: $($defaultBranding.id)"
        }

    }else{
        write-host "  Default Branding already exists: $($defaultBranding.id)"
    }
    

    # Output some useful info
    $spaPortalUrl = "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Overview/appId/"+$app.AppId+"/objectId/"+$app.Id+"/isMSAApp/"
    write-host
    write-host
    write-host "Configuration Details"
    write-host "  Tenant Name:  ", $tenantName
    write-host "  Tenant Id:    ", $newTenantId
    write-host "  Authority:    ", "https://login.microsoftonline.com/$newTenantId"
    write-host "  Client Id:    ", $app.AppId
    write-host "  RedirectUri:  ", $app.spa.RedirectUris
    write-host
    write-host
    write-host "You can see you app in the portal here: $spaPortalUrl"
}


write-host "1.Setting up environment"
write-host "_____________________________________________"
InstallModule
SetContext
write-host "_____________________________________________"
write-host "---Setting up environment Done---"

write-host "2.Creating tenant"
write-host "_____________________________________________"
CreateTenant($resourceGroupName, $resourceGroupLocation, $tenantPrefix)
write-host "_____________________________________________"
write-host "---Creating tenant environment Done---"

write-host "3.Configuring SPA application"
write-host "_____________________________________________"
CreateApplication($tenantPrefix)
write-host "_____________________________________________"
write-host "---Configuring SPA application Done---"