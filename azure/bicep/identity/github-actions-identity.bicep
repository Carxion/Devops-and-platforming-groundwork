// Short-lived Azure credentials for GitHub Actions without app registrations
// or secrets: two user-assigned managed identities with federated credentials.
//   plan:  trusted by pull requests; Reader on this resource group
//   apply: trusted only by jobs in a protected GitHub environment; Contributor
// Use with azure/login (client-id = the identity's clientId) or ARM_USE_OIDC.
// The Terraform equivalent, using Entra ID app registrations, is
// terraform/azure/github-oidc.
//
// Deploy: az deployment group create --resource-group <rg> --template-file github-actions-identity.bicep \
//           --parameters githubRepository=<owner>/<repo>
targetScope = 'resourceGroup'

@description('Repository allowed to use the identities, as owner/name.')
param githubRepository string

@description('GitHub environment whose jobs may use the apply identity. Protect it with required reviewers.')
param applyEnvironment string = 'production'

@description('Name prefix for the identities.')
param namePrefix string = 'github'

param location string = resourceGroup().location

var issuer = 'https://token.actions.githubusercontent.com'
var audiences = [
  'api://AzureADTokenExchange'
]

resource planIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${namePrefix}-plan'
  location: location
}

resource applyIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${namePrefix}-apply'
  location: location
}

resource planCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: planIdentity
  name: 'pull-requests'
  properties: {
    issuer: issuer
    subject: 'repo:${githubRepository}:pull_request'
    audiences: audiences
  }
}

resource applyCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: applyIdentity
  name: 'environment-${applyEnvironment}'
  properties: {
    issuer: issuer
    subject: 'repo:${githubRepository}:environment:${applyEnvironment}'
    audiences: audiences
  }
}

var readerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
var contributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

resource planReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, planIdentity.id, readerRoleId)
  properties: {
    principalId: planIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: readerRoleId
    description: 'GitHub Actions plan identity for ${githubRepository}'
  }
}

resource applyContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, applyIdentity.id, contributorRoleId)
  properties: {
    principalId: applyIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleId
    description: 'GitHub Actions apply identity for ${githubRepository} (environment ${applyEnvironment})'
  }
}

output tenantId string = tenant().tenantId
output subscriptionId string = subscription().subscriptionId
output planClientId string = planIdentity.properties.clientId
output applyClientId string = applyIdentity.properties.clientId
