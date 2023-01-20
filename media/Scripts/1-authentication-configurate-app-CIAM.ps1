#
# Create a new CIAM app registration and user flow
#
[CmdletBinding()]
param(
    [Parameter(Mandatory=$True, HelpMessage='Tenant ID newly created ')]
    [string] $tenantId,
    [Parameter(Mandatory=$False, HelpMessage='Display Name for application (Default: "CIAM Test App")')]
    [string] $applicationName,
    [Parameter(Mandatory=$False, HelpMessage='Graph environment to use while running the script (Default: "Global")')]
    [string] $environmentName
)

# Based on https://github.com/Azure-Samples/ms-identity-javascript-tutorial/blob/main/1-Authentication/1-sign-in/AppCreationScripts/Configure.ps1


# $ErrorActionPreference = "Stop"

$userFlowName="SISU"
$redirectUris="http://localhost:3000"

$scopes = @(
     "Application.ReadWrite.All",
     "IdentityUserFlow.ReadWrite.All",
     "Organization.ReadWrite.All",
     "User.Read.All"
)

#
# Idempotent App, Service Principal + User Flow creation
#
Function CreateApplication
{
    if (!$environmentName)
    {
        $environmentName = "Global"
    }

    if (!$applicationName) {
        $applicationName = "CIAM Test App"
    }

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

    $res.Id = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182"
    $res.Type = "Scope"

    $res2 = New-Object -TypeName Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphResourceAccess
    $res2.Id = "37f7f235-527c-4136-accd-4a02d197296e"
    $res2.Type = "Scope"
    $resAcc.ResourceAccess = $res,$res2

    $app = Get-MgApplication | Where-Object {$_.displayName -eq $applicationName} |Select-Object -first 1
    if ($app -eq $null) {
        write-host "Creating Single Page Application..."
        # JC: Changed SignIn Audience to AzureADandPersonalMicrosoftAccount for CIAM tenant as in docs
        $app = New-MgApplication `
            -displayName $applicationName `
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
        do {
            $result = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $params
        }while($result)
        
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
    write-host "  Tenant Id:    ", $tenantId
    write-host "  Authority:    ", "https://login.microsoftonline.com/$tenantId"
    write-host "  Client Id:    ", $app.AppId
    write-host "  RedirectUri:  ", $app.spa.RedirectUris
    write-host
    write-host
    write-host "You can see you app in the portal here: $spaPortalUrl"
}

write-host "3.Configuring SPA application"
write-host "_____________________________________________"
CreateApplication
write-host "_____________________________________________"
write-host "---Configuring SPA application Done---"