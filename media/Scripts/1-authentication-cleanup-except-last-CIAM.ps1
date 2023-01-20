# Clear-AzContext -force

[CmdletBinding()]
param(    
    [Parameter(Mandatory=$True, HelpMessage='Tenant ID (This is a GUID which represents the "Directory ID" of the AzureAD tenant into which you want to create the apps')]
    [string] $tenantId,
    [Parameter(Mandatory=$False, HelpMessage='Graph environment to use while running the script (Default: "Global")')]
    [string] $environmentName,
    [Parameter(Mandatory=$False, HelpMessage='Resource Group Name')]
    [string] $resourceGroupName

)


# $ErrorActionPreference = "Stop"


$scopes = @(
     "Application.ReadWrite.All",
     "IdentityUserFlow.ReadWrite.All",
     "Organization.ReadWrite.All",
     "User.Read.All"
)


Function Cleanup
{
    if (!$environmentName)
    {
        $environmentName = "Global"
    }

    if (!$resourceGroupName)
    {
        $resourceGroupName = "yuxinciam005"
    }

    <#
    .Description
    This function removes the Azure AD applications for the sample. These applications were created by the Configure.ps1 script
    #>

    # $tenantId is the Active Directory Tenant. This is a GUID which represents the "Directory ID" of the AzureAD tenant 
    # into which you want to create the apps. Look it up in the Azure portal in the "Properties" of the Azure AD. 

    # Login to Azure PowerShell (interactive if credentials are not already provided:
    # you'll need to sign-in with creds enabling your to create apps in the tenant)

    if ($TenantId)
    {
        Connect-AzAccount -TenantId $tenantId
    }

    $tenant = Get-AzTenant -TenantId $tenantId
    $tenantName =  ($tenant).Name
    
    # Removes all applications
    Write-Host "Cleaning-up applications from tenant '$tenantName'"
    Get-AzADApplication | ForEach-Object {Remove-AzADApplication -ApplicationId $_.AppId }

    # also remove user flows
    Connect-Graph -TenantId $tenantId -Scopes $scopes -Environment $environmentName
    Write-Host "Cleaning-up user flows from tenant '$tenantName'"
    $userflowId = (Invoke-MgGraphRequest -Method GET "https://graph.microsoft.com/beta/identity/AuthenticationEventsFlows/").value.Id
    if ($userflowId){
        Invoke-MgGraphRequest -Method DELETE https://graph.microsoft.com/beta/identity/authenticationEventsFlows/$userflowId
    }

    # also remove service principals of this app
    Write-Host "Cleaning-up service principals from tenant '$tenantName'"
    Get-AzADServicePrincipal | ForEach-Object {Remove-AzADServicePrincipal -ObjectId $_.Id -Confirm:$false}
    
    # elevate role 
    Write-Host "Elevate role"
    $token =(Get-AzAccessToken).Token
    $headers = @{Authorization="Bearer $token"}
    $uri = 'https://management.azure.com/providers/Microsoft.Authorization/elevateAccess?api-version=2017-05-01'
    $secureToken = ConvertTo-SecureString $token -AsPlainText -force
    Invoke-RestMethod -Method POST -Headers $headers -Uri $uri

    # also remove resource group
    # Write-Host "Cleaning-up resource group from the default tenant"
    # Set-AzContext -TenantId "4f1a858c-3ba6-4c34-85d1-989d717b329f"
    # Get-AzResourceGroup -Name $resourceGroupName | Remove-AzResourceGroup -Force
    
    Disconnect-AzAccount
}

Cleanup