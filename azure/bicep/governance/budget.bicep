// Monthly cost budget for the subscription with alerts at 80% of actual spend
// and 100% of forecasted spend, so overruns surface mid-month (guide
// section 3.5).
//
// Deploy: az deployment sub create --location <region> --template-file budget.bicep \
//           --parameters monthlyAmount=5000 contactEmails='["platform-team@example.com"]' startDate=2026-11-01
targetScope = 'subscription'

param budgetName string = 'monthly-subscription-budget'

@description('Expected monthly spend, in the billing currency.')
@minValue(1)
param monthlyAmount int

@description('Addresses that receive alerts. Use a team distribution list, not one person.')
@minLength(1)
param contactEmails array

@description('First day of the month the budget starts, as YYYY-MM-01. Must not be in the past.')
param startDate string

resource budget 'Microsoft.Consumption/budgets@2023-11-01' = {
  name: budgetName
  properties: {
    category: 'Cost'
    amount: monthlyAmount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
    }
    notifications: {
      actual80: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: contactEmails
      }
      forecast100: {
        enabled: true
        operator: 'GreaterThan'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: contactEmails
      }
    }
  }
}
