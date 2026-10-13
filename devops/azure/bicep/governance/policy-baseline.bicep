// Subscription policy baseline using built-in definitions:
//   - resources and resource groups only in approved regions (deny)
//   - every resource group has an Owner tag (deny)
//   - resources inherit the Owner tag from their resource group (modify)
//   - Microsoft cloud security benchmark (audit), which feeds Defender for Cloud
// Test with enforcementMode DoNotEnforce first: assignments then report
// compliance without blocking anything.
//
// Deploy: az deployment sub create --location <region> --template-file policy-baseline.bicep \
//           --parameters allowedLocations='["eastus2","centralus"]'
targetScope = 'subscription'

@description('Regions where resources and resource groups may be created.')
param allowedLocations array

@description('Tag every resource group must have, and resources inherit.')
param ownerTagName string = 'Owner'

@description('Default enforces; DoNotEnforce evaluates and reports only.')
@allowed([
  'Default'
  'DoNotEnforce'
])
param enforcementMode string = 'Default'

@description('Region for the managed identity the tag-inheritance assignment needs.')
param location string = deployment().location

// Built-in policy definition IDs (verified against github.com/Azure/azure-policy).
var definitions = {
  allowedLocations: tenantResourceId('Microsoft.Authorization/policyDefinitions', 'e56962a6-4747-49cd-b67b-bf8b01975c4c')
  allowedLocationsForResourceGroups: tenantResourceId('Microsoft.Authorization/policyDefinitions', 'e765b5de-1225-4ba3-bd56-1ac6695af988')
  requireTagOnResourceGroups: tenantResourceId('Microsoft.Authorization/policyDefinitions', '96670d01-0a4d-4649-9c89-2d3abc0a5025')
  inheritTagFromResourceGroup: tenantResourceId('Microsoft.Authorization/policyDefinitions', 'cd3aa116-8754-49c9-a813-ad46512ece54')
  cloudSecurityBenchmark: tenantResourceId('Microsoft.Authorization/policySetDefinitions', '1f3afdf9-d0c9-4c3d-847f-89da613e70a8')
}

resource allowedLocationsAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'allowed-locations'
  properties: {
    displayName: 'Allowed locations'
    description: 'Resources may only be created in approved regions.'
    policyDefinitionId: definitions.allowedLocations
    enforcementMode: enforcementMode
    parameters: {
      listOfAllowedLocations: {
        value: allowedLocations
      }
    }
    nonComplianceMessages: [
      {
        message: 'This region is not approved. Allowed: ${join(allowedLocations, ', ')}.'
      }
    ]
  }
}

resource allowedRgLocationsAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'allowed-rg-locations'
  properties: {
    displayName: 'Allowed locations for resource groups'
    policyDefinitionId: definitions.allowedLocationsForResourceGroups
    enforcementMode: enforcementMode
    parameters: {
      listOfAllowedLocations: {
        value: allowedLocations
      }
    }
  }
}

resource requireOwnerTag 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'require-rg-owner-tag'
  properties: {
    displayName: 'Require ${ownerTagName} tag on resource groups'
    policyDefinitionId: definitions.requireTagOnResourceGroups
    enforcementMode: enforcementMode
    parameters: {
      tagName: {
        value: ownerTagName
      }
    }
    nonComplianceMessages: [
      {
        message: 'Resource groups need an ${ownerTagName} tag naming the accountable team.'
      }
    ]
  }
}

// Modify policies need an identity that can write tags.
resource inheritOwnerTag 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'inherit-owner-tag'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Inherit ${ownerTagName} tag from resource group'
    policyDefinitionId: definitions.inheritTagFromResourceGroup
    enforcementMode: enforcementMode
    parameters: {
      tagName: {
        value: ownerTagName
      }
    }
  }
}

// The definition declares Contributor for remediation, but writing tags is
// all it does, so the narrower Tag Contributor role is enough.
var tagContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4a9ae827-6dc8-4573-8ac7-8239d42aa03f')

resource inheritOwnerTagRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, inheritOwnerTag.id, tagContributorRoleId)
  properties: {
    principalId: inheritOwnerTag.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: tagContributorRoleId
    description: 'Lets the inherit-owner-tag policy remediate tags'
  }
}

resource securityBenchmark 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'cloud-security-benchmark'
  properties: {
    displayName: 'Microsoft cloud security benchmark'
    description: 'Audit-mode baseline that feeds Defender for Cloud recommendations.'
    policyDefinitionId: definitions.cloudSecurityBenchmark
    enforcementMode: enforcementMode
  }
}
