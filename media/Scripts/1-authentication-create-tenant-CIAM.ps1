#
# Create a new CIAM tenant through bicep
#
[CmdletBinding()]
param(
    [Parameter(Mandatory=$False, HelpMessage='Resource Group Name')]
    [string] $resourceGroupName,
    [Parameter(Mandatory=$False, HelpMessage='Prefix for Tenant (Default: "ciamtest" + 5 digit random string)')]
    [string] $tenantPrefix,
    [Parameter(Mandatory=$False, HelpMessage='Location for Resource Group if it is created (Default: "northeurope")')]
    [string] $resourceGroupLocation
)

Function CreateTenant
{
    if (!$resourceGroupName) {
        $resourceGroupName = "ciamtest"
    }
    if (!$tenantPrefix) {
        $tenantPrefix = "ciamtest" + (Get-Random -Minimum 10000 -Maximum 99999)
    }
    if (!$resourceGroupLocation) {
        $resourceGroupLocation = "northeurope"
    }

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
        } else {
            write-host "Tenant creation failed. Exiting..."
            exit
        }
    }else{
        write-host "Tenant $tenantName exists. Exiting..."
            exit
    }
}

write-host "2.Creating tenant"
write-host "_____________________________________________"
CreateTenant
write-host "_____________________________________________"
write-host "---Creating tenant environment Done---"