// Key Vault with secure defaults: Azure RBAC for data access (no access
// policies), soft delete and purge protection, public network access
// restricted to listed IPs (or off), and audit logs to Log Analytics.
//
// Deploy: az deployment group create --resource-group <rg> --template-file key-vault.bicep \
//           --parameters vaultName=<globally unique name> logAnalyticsWorkspaceId=<id>
targetScope = 'resourceGroup'

@description('Globally unique name, 3-24 characters.')
@minLength(3)
@maxLength(24)
param vaultName string

param location string = resourceGroup().location

@description('Public IPs or CIDRs allowed through the vault firewall. Empty with publicNetworkAccess Enabled still denies all public traffic except trusted Azure services.')
param allowedIpRanges array = []

@description('Disabled means private endpoint access only.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Days a deleted vault or secret can be recovered (7-90).')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 90

@description('Log Analytics workspace for audit logs. Empty disables diagnostics.')
param logAnalyticsWorkspaceId string = ''

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  properties: {
    tenantId: tenant().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    // Can't be turned off once on: deleted secrets can't be purged early.
    enablePurgeProtection: true
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: [for ip in allowedIpRanges: {
        value: ip
      }]
    }
  }
}

// Prevents deleting the vault (and losing every secret) by accident.
resource lock 'Microsoft.Authorization/locks@2020-05-01' = {
  name: 'do-not-delete'
  scope: vault
  properties: {
    level: 'CanNotDelete'
    notes: 'Holds secrets in use. Remove the lock through a reviewed change first.'
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'to-log-analytics'
  scope: vault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
      }
    ]
  }
}

output vaultId string = vault.id
output vaultUri string = vault.properties.vaultUri
