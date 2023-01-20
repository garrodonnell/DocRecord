
[CmdletBinding()]
param(
    [Parameter(Mandatory=$True, HelpMessage='Tenant ID where the subscription ID is located')]
    [string] $tenantId,
    [Parameter(Mandatory=$True, HelpMessage='Subscription ID used to pay for the new tenant')]
    [string] $subscriptionID
)


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
    Connect-AzAccount -TenantId $tenantId
    Set-AzContext -Subscription $subscriptionID
}



write-host "1.Setting up environment"
write-host "_____________________________________________"
InstallModule
SetContext
write-host "_____________________________________________"
write-host "---Setting up environment Done---"
