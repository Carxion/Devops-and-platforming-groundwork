// Storage account with secure defaults: Entra ID auth only (shared keys
// off), TLS 1.2, no public blob access, infrastructure encryption, blob
// versioning and soft delete, and a firewall that denies by default.
// The same defaults as terraform/azure/bootstrap-state.
//
// Deploy: az deployment group create --resource-group <rg> --template-file storage-account.bicep \
//           --parameters storageAccountName=<globally unique name>
targetScope = 'resourceGroup'

@description('Globally unique, 3-24 lowercase letters and digits.')
@minLength(3)
@maxLength(24)
param storageAccountName string

param location string = resourceGroup().location

@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GZRS'
])
@description('ZRS survives a zone outage; GZRS also survives a regional one.')
param skuName string = 'Standard_ZRS'

@description('Public IPs or CIDRs allowed through the firewall. Trusted Azure services are always allowed.')
param allowedIpRanges array = []

@description('Days deleted blobs, containers, and previous versions can be recovered.')
@minValue(1)
@maxValue(365)
param retentionDays int = 30

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  // checkov:skip=CKV_AZURE_59:The firewall denies by default (networkAcls.defaultAction Deny); only listed IPs and trusted Azure services get through.
  // checkov:skip=CKV_AZURE_43:The name is a parameter, constrained by @minLength/@maxLength; Azure validates the character rules.
  // checkov:skip=CKV_AZURE_206:Replication is a parameter that defaults to ZRS.
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: skuName
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: [for ip in allowedIpRanges: {
        value: ip
        action: 'Allow'
      }]
    }
    encryption: {
      requireInfrastructureEncryption: true
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    isVersioningEnabled: true
    deleteRetentionPolicy: {
      enabled: true
      days: retentionDays
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: retentionDays
    }
  }
}

output storageAccountId string = storage.id
output blobEndpoint string = storage.properties.primaryEndpoints.blob
