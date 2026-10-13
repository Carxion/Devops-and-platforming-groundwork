// Sends the subscription activity log (who changed what, policy and security
// events, service health) to Log Analytics. Without this, Azure keeps it for
// only 90 days and it can't be queried alongside other logs (guide section 3.4).
//
// Deploy: az deployment sub create --location <region> --template-file activity-log-export.bicep \
//           --parameters logAnalyticsWorkspaceId=<workspace resource id>
targetScope = 'subscription'

@description('Resource ID of the Log Analytics workspace (for example network-hub-spoke output log_analytics_workspace_id).')
param logAnalyticsWorkspaceId string

var categories = [
  'Administrative'
  'Security'
  'ServiceHealth'
  'Alert'
  'Recommendation'
  'Policy'
  'Autoscale'
  'ResourceHealth'
]

resource activityLog 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'activity-log-to-log-analytics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [for category in categories: {
      category: category
      enabled: true
    }]
  }
}
