// Entra ID identity for one Kubernetes workload through AKS workload
// identity: a user-assigned managed identity, a federated credential that
// trusts exactly one service account, and one role on one Key Vault.
// Pairs with devops/kubernetes/components/aks-workload-identity (put the clientId
// output in that component's service account annotation).
//
// Deploy: az deployment group create --resource-group <rg> --template-file workload-identity.bicep \
//           --parameters oidcIssuerUrl=<aks oidc_issuer_url> keyVaultName=<vault>
targetScope = 'resourceGroup'

@description('Name of the workload, used for the identity name.')
param workloadName string = 'worker'

@description('AKS OIDC issuer URL (aks-cluster output oidc_issuer_url).')
param oidcIssuerUrl string

@description('Kubernetes namespace of the service account.')
param namespace string = 'sample-apps'

@description('Kubernetes service account name.')
param serviceAccountName string = 'worker'

@description('Key Vault in this resource group the workload reads secrets from. Empty grants nothing.')
param keyVaultName string = ''

param location string = resourceGroup().location

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${workloadName}'
  location: location
}

resource credential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: identity
  name: 'aks-${namespace}-${serviceAccountName}'
  properties: {
    issuer: oidcIssuerUrl
    subject: 'system:serviceaccount:${namespace}:${serviceAccountName}'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

resource vault 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (!empty(keyVaultName)) {
  name: keyVaultName
}

var secretsUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

// Scoped to one vault, not the resource group: the workload can read this
// vault's secrets and nothing else.
resource secretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(keyVaultName)) {
  name: guid(vault.id, identity.id, secretsUserRoleId)
  scope: vault
  properties: {
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: secretsUserRoleId
    description: 'Workload ${workloadName} (${namespace}/${serviceAccountName}) reads secrets'
  }
}

output clientId string = identity.properties.clientId
output principalId string = identity.properties.principalId
