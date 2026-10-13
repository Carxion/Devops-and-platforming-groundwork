# AWS logging and monitoring

[← AWS operations](../README.md)

## CloudTrail: who did this?

`lookup-events` searches the last 90 days of management events in the current region. Global services such as IAM log to `us-east-1`.

```sh
# Who deleted it?
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=DeleteSecurityGroup \
  --start-time 2026-10-11T00:00:00Z --max-results 20 \
  --query "Events[].{time:EventTime, who:Username, resource:Resources[0].ResourceName}" --output table

# Everything a principal did
aws cloudtrail lookup-events --lookup-attributes AttributeKey=Username,AttributeValue=<user or role session name> --max-results 50

# Everything done to one resource
aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=<sg-id, bucket, instance id> --max-results 50

# Everything done with one access key (leaked-key investigations)
aws cloudtrail lookup-events --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=<AKIA...> --max-results 50

# The full event, including source IP, user agent, and request parameters
aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventId,AttributeValue=<event id> \
  --query "Events[0].CloudTrailEvent" --output text | jq .
```

For data events, older events, or other regions in bulk, query the trail's S3 logs with Athena, or use CloudTrail Lake.

### Is the trail healthy?

```sh
aws cloudtrail describe-trails --query "trailList[].{name:Name, multiRegion:IsMultiRegionTrail, validation:LogFileValidationEnabled, bucket:S3BucketName, kms:KmsKeyId}" --output table
aws cloudtrail get-trail-status --name <trail> --query "{logging:IsLogging, lastDelivery:LatestDeliveryTime, lastError:LatestDeliveryError}"

# Prove log files weren't modified (needs log file validation on)
aws cloudtrail validate-logs --trail-arn <trail arn> --start-time 2026-10-01T00:00:00Z
```

## CloudWatch Logs

```sh
aws logs describe-log-groups --query "logGroups[].{name:logGroupName, retentionDays:retentionInDays, storedBytes:storedBytes}" --output table

aws logs tail <log group> --follow --since 30m
aws logs tail <log group> --since 1h --filter-pattern '"ERROR"'
aws logs tail <log group> --since 1h --filter-pattern '{ $.level = "error" }'      # JSON logs

# Log groups that keep data forever (cost, and usually a retention requirement miss)
aws logs describe-log-groups --query "logGroups[?!retentionInDays].logGroupName" --output text
aws logs put-retention-policy --log-group-name <log group> --retention-in-days 365
```

### Logs Insights

Run a query from the CLI. The times are epoch seconds:

```sh
qid=$(aws logs start-query --log-group-name <log group> \
  --start-time $(date -d '-1 hour' +%s) --end-time $(date +%s) \
  --query-string 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 50' \
  --query queryId --output text)

sleep 5
aws logs get-query-results --query-id "$qid" --query "results[].[*][].value" --output text
```

On macOS, use `date -v-1H +%s` instead of `date -d '-1 hour' +%s`.

Useful queries:

```text
# Lambda: slowest invocations and memory use
filter @type = "REPORT"
| stats max(@duration) as maxMs, avg(@duration) as avgMs, max(@maxMemoryUsed / 1000000) as maxMemMB by bin(5m)

# API Gateway access logs (the serverless-api stack's format): errors by route
filter status >= 500
| stats count(*) as errors by routeKey
| sort errors desc

# Errors by message, for JSON application logs
filter level = "error"
| stats count(*) as n by msg
| sort n desc
| limit 20
```

## Metrics and alarms

```sh
aws cloudwatch describe-alarms --state-value ALARM \
  --query "MetricAlarms[].{name:AlarmName, metric:MetricName, reason:StateReason}" --output table

aws cloudwatch describe-alarm-history --alarm-name <alarm> --history-item-type StateUpdate --max-items 10 \
  --query "AlarmHistoryItems[].[Timestamp, HistorySummary]" --output text

# Alarms that can't evaluate (no data, often a renamed resource)
aws cloudwatch describe-alarms --state-value INSUFFICIENT_DATA --query "MetricAlarms[].AlarmName" --output text

# ALB 5xx count per 5 minutes over the last hour
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name HTTPCode_Target_5XX_Count \
  --dimensions Name=LoadBalancer,Value=app/<alb name>/<id> \
  --start-time $(date -u -d '-1 hour' +%Y-%m-%dT%H:%M:%SZ) --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 --statistics Sum --output table
```

Test that an alarm actually reaches someone, without waiting for an incident:

```sh
aws cloudwatch set-alarm-state --alarm-name <alarm> --state-value ALARM --state-reason "Notification path test"
```

The alarm returns to its real state at the next evaluation.

## AWS Config

```sh
aws configservice describe-configuration-recorder-status \
  --query "ConfigurationRecordersStatus[].{name:name, recording:recording, lastStatus:lastStatus}"

aws configservice describe-compliance-by-config-rule --compliance-types NON_COMPLIANT \
  --query "ComplianceByConfigRules[].ConfigRuleName" --output text

aws configservice get-compliance-details-by-config-rule --config-rule-name <rule> --compliance-types NON_COMPLIANT \
  --query "EvaluationResults[].EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId" --output text

# What did this security group look like last week, and who changed it?
aws configservice get-resource-config-history --resource-type AWS::EC2::SecurityGroup --resource-id <sg-id> --limit 5 \
  --query "configurationItems[].{captured:configurationItemCaptureTime, status:configurationItemStatus}"
```

## Service health

```sh
# Needs a Business or Enterprise support plan; the Health API endpoint is in us-east-1
aws health describe-events --region us-east-1 --filter eventStatusCodes=open \
  --query "events[].{service:service, type:eventTypeCode, region:region, start:startTime}" --output table
```

Without that support plan, use the AWS Health Dashboard in the console.
