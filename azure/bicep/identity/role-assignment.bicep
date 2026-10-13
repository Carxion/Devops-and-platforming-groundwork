// Assigns one role to one principal on this resource group. Prefer resource
// group (or resource) scope over subscription scope, and data-plane roles
// (Storage Blob Data Reader, Key Vault Secrets User) over Contributor.
//
// Deploy: az deployment group create --resource-group <rg> --template-file role-assignment.bicep \
//           --parameters principalId=<object id> role=KeyVaultSecretsUser
targetScope = 'resourceGroup'

@description('Object ID of the user, group, service principal, or managed identity.')
param principalId string

@description('Type of the principal. Setting it avoids replication-delay failures for new principals.')
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param principalType string = 'ServicePrincipal'

@description('Built-in role to assign. Add others from https://learn.microsoft.com/azure/role-based-access-control/built-in-roles.')
@allowed([
  'Reader'
  'Contributor'
  'StorageBlobDataReader'
  'KeyVaultSecretsUser'
  'AcrPull'
  'VirtualMachineContributor'
])
param role string

@description('Why this access exists. Shown on the assignment, so reviewers don\'t have to guess.')
param assignmentDescription string = ''

// Built-in role definition IDs (the same in every tenant).
var roleIds = {
  Reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  Contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  StorageBlobDataReader: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  KeyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  AcrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  VirtualMachineContributor: '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'
}

var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds[role])

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // Deterministic name: the same principal and role always map to the same assignment.
  name: guid(resourceGroup().id, principalId, roleDefinitionId)
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: roleDefinitionId
    description: assignmentDescription
  }
}

output roleAssignmentId string = assignment.id
