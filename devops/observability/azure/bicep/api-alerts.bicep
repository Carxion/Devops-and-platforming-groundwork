// Alerts for the functions-api stack (devops/terraform/azure/functions-api): an
// availability test from several Azure regions, and log search alerts on the
// error ratio and p95 latency of the function's requests in Application
// Insights. Everything notifies one action group.
//
// Deploy into the stack's resource group:
//   az deployment group create --resource-group <rg> --template-file api-alerts.bicep \
//     --parameters appInsightsName=<appi name> apiBaseUrl=<api_base_url output> \
//                  alertEmails='["platform-team@example.com"]'

@description('Name of the Application Insights component the function app sends telemetry to.')
param appInsightsName string

@description('The API base URL, ending in /api (functions-api output api_base_url).')
param apiBaseUrl string

@description('Addresses notified by the action group. Use a team list, not one person; add paging and chat integrations in the portal or with more receivers.')
param alertEmails array = []

@description('Alert when more than this share of requests fail with 5xx errors over 15 minutes.')
param errorRatioThreshold string = '0.01'

@description('Alert when p95 request duration exceeds this many milliseconds over 15 minutes.')
@minValue(1)
param latencyP95Ms int = 1000

param location string = resourceGroup().location

var tags = {
  ManagedBy: 'bicep'
  Stack: 'functions-api-alerts'
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-${appInsightsName}'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: take('api-alerts', 12)
    enabled: true
    emailReceivers: [
      for (email, i) in alertEmails: {
        name: 'email-${i}'
        emailAddress: email
        useCommonAlertSchema: true
      }
    ]
  }
}

// Standard availability test: GET an item that never exists, from five
// regions every five minutes. A 404 proves the whole path works (front end,
// function host, code, Cosmos DB read) without any test data to maintain.
// If the stack's Entra ID authentication is on, the test gets 401 instead:
// add an Authorization header from a long-lived test credential, or test a
// public health endpoint.
resource availabilityTest 'Microsoft.Insights/webtests@2022-06-15' = {
  name: 'avail-${appInsightsName}'
  location: location
  kind: 'standard'
  tags: union(tags, {
    // Required: links the test to its Application Insights component.
    'hidden-link:${appInsights.id}': 'Resource'
  })
  properties: {
    SyntheticMonitorId: 'avail-${appInsightsName}'
    Name: 'Items API availability'
    Description: 'GET a missing item; expects 404 from the function.'
    Enabled: true
    Kind: 'standard'
    Frequency: 300
    Timeout: 30
    RetryEnabled: true
    Locations: [
      { Id: 'us-va-ash-azr' } // East US
      { Id: 'us-ca-sjc-azr' } // West US
      { Id: 'us-il-ch1-azr' } // North Central US
      { Id: 'emea-nl-ams-azr' } // West Europe
      { Id: 'apac-sg-sin-azr' } // Southeast Asia
    ]
    Request: {
      RequestUrl: '${apiBaseUrl}/items/availability-probe-never-exists'
      HttpVerb: 'GET'
      ParseDependentRequests: false
    }
    ValidationRules: {
      ExpectedHttpStatusCode: 404
      SSLCheck: true
      SSLCertRemainingLifetimeCheck: 14
    }
  }
}

// Fires when the test fails from 3 or more of the 5 regions (Microsoft's guidance:
// test locations minus 2), which filters
// out one or two regions' network trouble.
resource availabilityAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-${appInsightsName}-availability'
  location: 'global'
  tags: tags
  properties: {
    description: 'The Items API is failing its availability test from 3 or more regions.'
    severity: 1
    enabled: true
    scopes: [
      availabilityTest.id
      appInsights.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.WebtestLocationAvailabilityCriteria'
      webTestId: availabilityTest.id
      componentId: appInsights.id
      failedLocationCount: 3
    }
    autoMitigate: true
    actions: [
      { actionGroupId: actionGroup.id }
    ]
  }
}

// Log search alerts query the requests table, so they can express ratios and
// percentiles that metric alerts can't.
resource errorRatioAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: 'alert-${appInsightsName}-error-ratio'
  location: location
  tags: tags
  properties: {
    displayName: 'Items API 5xx error ratio'
    description: 'More than ${errorRatioThreshold} of requests failed with 5xx errors over 15 minutes. Start with the failures query in software/api-testing/azure.md.'
    severity: 1
    enabled: true
    scopes: [appInsights.id]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: '''
            requests
            | summarize total = count(), failed = countif(toint(resultCode) >= 500)
            | where total > 0
            | extend errorRatio = todouble(failed) / total
          '''
          timeAggregation: 'Maximum'
          metricMeasureColumn: 'errorRatio'
          operator: 'GreaterThan'
          threshold: json(errorRatioThreshold)
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    actions: {
      actionGroups: [actionGroup.id]
    }
  }
}

resource latencyAlert 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = {
  name: 'alert-${appInsightsName}-latency-p95'
  location: location
  tags: tags
  properties: {
    displayName: 'Items API p95 latency'
    description: 'p95 request duration is above ${latencyP95Ms} ms over 15 minutes.'
    severity: 2
    enabled: true
    scopes: [appInsights.id]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      allOf: [
        {
          query: '''
            requests
            | summarize p95Ms = percentile(duration, 95), total = count()
            | where total >= 20
          '''
          timeAggregation: 'Maximum'
          metricMeasureColumn: 'p95Ms'
          operator: 'GreaterThan'
          threshold: latencyP95Ms
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    autoMitigate: true
    actions: {
      actionGroups: [actionGroup.id]
    }
  }
}

output actionGroupId string = actionGroup.id
output availabilityTestId string = availabilityTest.id
