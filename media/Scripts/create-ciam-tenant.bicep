param location string = 'Europe'
param countryCode string = 'IE'

param displayName string = 'ciam'

resource ciam 'Microsoft.AzureActiveDirectory/ciamDirectories@2022-03-01-preview' = {
  name: '${displayName}.onmicrosoft.com'
  location: location
  sku: {
    name: 'Standard'
    tier: 'A0'
  }
  properties: {
    createTenantProperties: {
      displayName: '${displayName}.onmicrosoft.com'
      countryCode: countryCode
    }
  }
}

output tenantName string = ciam.name
output tenantId string = ciam.properties.tenantId
