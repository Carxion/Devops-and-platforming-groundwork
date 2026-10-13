// Custom role for operators who restart and resize VMs but can't create,
// delete, or reconfigure networking. A template for least-privilege roles:
// start from the actions a job actually needs, not from Contributor.
//
// Deploy: az deployment sub create --location <region> --template-file custom-role.bicep
targetScope = 'subscription'

@description('Display name of the role.')
param roleName string = 'Virtual Machine Operator'

@description('Description shown in the portal.')
param roleDescription string = 'Start, stop, restart, and deallocate VMs, and view their state. Cannot create, delete, or change networking.'

@description('Actions the role allows. Keep this list as short as the job allows.')
param actions array = [
  'Microsoft.Compute/virtualMachines/read'
  'Microsoft.Compute/virtualMachines/instanceView/read'
  'Microsoft.Compute/virtualMachines/start/action'
  'Microsoft.Compute/virtualMachines/powerOff/action'
  'Microsoft.Compute/virtualMachines/restart/action'
  'Microsoft.Compute/virtualMachines/deallocate/action'
  'Microsoft.Resources/subscriptions/resourceGroups/read'
  'Microsoft.Insights/metrics/read'
]

resource role 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  // Deterministic name, so redeploying updates the role instead of duplicating it.
  name: guid(subscription().id, roleName)
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'CustomRole'
    permissions: [
      {
        actions: actions
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

output roleDefinitionId string = role.id
