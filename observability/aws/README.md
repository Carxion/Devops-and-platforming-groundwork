# Observability on AWS

[← Observability](../README.md)

How to instrument, collect, alert on, and look at telemetry for workloads on AWS, using the native services (CloudWatch, X-Ray) and the managed open-source ones (Amazon Managed Service for Prometheus, Amazon Managed Grafana). For investigating an account you've inherited, with commands for "who did this" and "what's broken", see [aws/guides/logging-and-monitoring.md](../../aws/guides/logging-and-monitoring.md).

| Section | What it covers |
|---|---|
| [The services](#the-services) | Which service does what |
| [Alarms for the serverless API](#alarms-for-the-serverless-api) | Deploying [api-alarms.yaml](cloudformation/api-alarms.yaml) |
| [Metrics](#metrics) | Built-in metrics, custom metrics, Embedded Metric Format |
| [Logs](#logs) | Structured logging, retention, Logs Insights, metric filters |
| [Traces](#traces) | X-Ray, OpenTelemetry, Application Signals |
| [Alarms](#alarms) | Thresholds, metric math, composite alarms, testing notifications |
| [Containers and EKS](#containers-and-eks) | Container Insights, the CloudWatch add-on |
| [Prometheus and Grafana on AWS](#prometheus-and-grafana-on-aws) | Managed Prometheus, managed Grafana |
| [Cost](#cost) | What drives the CloudWatch bill |

---

## The services

| Need | AWS service | Notes |
|---|---|---|
| Metrics | CloudWatch Metrics | Every AWS service publishes metrics for free at 1- or 5-minute resolution. Custom metrics cost per metric per month. |
| Logs | CloudWatch Logs | Lambda, API Gateway, ECS, and VPC Flow Logs write here. Query with Logs Insights. |
| Traces | AWS X-Ray, with CloudWatch Application Signals on top | Instrument with OpenTelemetry (the AWS Distro for OpenTelemetry, ADOT) or the X-Ray SDKs. |
| Alarms | CloudWatch Alarms | Thresholds, metric math, anomaly detection, composite alarms. Notify through SNS. |
| Dashboards | CloudWatch Dashboards, or Amazon Managed Grafana | |
| Prometheus metrics | Amazon Managed Service for Prometheus (AMP) | Prometheus-compatible; for Kubernetes and anything instrumented with Prometheus clients |
| Synthetic checks | CloudWatch Synthetics canaries | See [api-testing/aws.md](../../api-testing/aws.md#synthetic-monitoring-with-cloudwatch-synthetics) |
| Audit | CloudTrail | Who called which API. Not observability of your app, but the first stop in many investigations. |

---

## Alarms for the serverless API

[cloudformation/api-alarms.yaml](cloudformation/api-alarms.yaml) adds alarms and a dashboard to the [serverless-api stack](../../terraform/aws/serverless-api/):

- Component alarms on API 5xx rate (metric math: errors divided by requests), p95 latency, Lambda error rate, Lambda throttles, and DynamoDB throttles. None of them notify on their own.
- Two **composite alarms** that do: **user impact** (errors or latency) and **capacity** (throttling). One incident, one notification, instead of five alarms going off together.
- An encrypted SNS topic for notifications, and a CloudWatch dashboard with the same signals plus recent 5xx lines from the access log.

```sh
NAME=$(terraform -chdir=terraform/aws/serverless-api output -raw function_name)
TABLE=$(terraform -chdir=terraform/aws/serverless-api output -raw table_name)
API_ID=$(aws apigatewayv2 get-apis --query "Items[?Name=='$NAME'].ApiId | [0]" --output text)

aws cloudformation deploy --stack-name "$NAME-alarms" \
  --template-file observability/aws/cloudformation/api-alarms.yaml \
  --parameter-overrides ApiId="$API_ID" FunctionName="$NAME" TableName="$TABLE" AlarmEmail=platform-team@example.com

aws cloudformation describe-stacks --stack-name "$NAME-alarms" --query "Stacks[0].Outputs" --output table
```

Confirm the SNS email subscription from the message AWS sends, then [test the notification path](#test-that-notifications-arrive). In a team setting, subscribe your paging and chat tools to the topic (PagerDuty, Opsgenie, and Amazon Q Developer in chat applications for Slack or Microsoft Teams all accept SNS) instead of email. Run the [k6 load test](../../api-testing/k6/load.js) with `PROFILE=stress` against a test environment to watch the alarms fire for real.

This template is CloudFormation so it can be added to any account. In a Terraform-managed program, the same resources are `aws_cloudwatch_metric_alarm`, `aws_cloudwatch_composite_alarm`, and `aws_cloudwatch_dashboard` in the stack itself.

---

## Metrics

Every AWS service publishes metrics to CloudWatch without setup. The ones that matter most for the reference stacks:

| Service | Metrics to watch |
|---|---|
| API Gateway (HTTP API) | `Count`, `4xx`, `5xx`, `Latency`, `IntegrationLatency` |
| Lambda | `Invocations`, `Errors`, `Throttles`, `Duration`, `ConcurrentExecutions` |
| DynamoDB | `ConsumedReadCapacityUnits`, `ConsumedWriteCapacityUnits`, `ReadThrottleEvents`, `WriteThrottleEvents`, `SuccessfulRequestLatency` |
| Application Load Balancer | `RequestCount`, `HTTPCode_Target_5XX_Count`, `TargetResponseTime`, `UnHealthyHostCount` |
| ECS | `CPUUtilization`, `MemoryUtilization` (per service; per task with Container Insights) |
| RDS | `CPUUtilization`, `DatabaseConnections`, `FreeStorageSpace`, `ReadLatency`, `WriteLatency` |
| SQS | `ApproximateAgeOfOldestMessage` (the one that says consumers are falling behind), `ApproximateNumberOfMessagesVisible` |

```sh
aws cloudwatch list-metrics --namespace AWS/Lambda --dimensions Name=FunctionName,Value=<function> \
  --query "Metrics[].MetricName" --output text

aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name Duration \
  --dimensions Name=FunctionName,Value=<function> \
  --start-time $(date -u -d '-1 hour' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --period 300 --extended-statistics p95 p99 --output table
```

### Custom metrics with the Embedded Metric Format

Don't call `PutMetricData` from request-handling code: it adds latency and an extra failure mode. Write metrics as structured log lines in the [Embedded Metric Format](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Embedded_Metric_Format.html) (EMF), and CloudWatch extracts them asynchronously:

```json
{
  "_aws": {
    "Timestamp": 1760000000000,
    "CloudWatchMetrics": [
      { "Namespace": "ItemsApi", "Dimensions": [["Operation"]], "Metrics": [{ "Name": "ItemSizeBytes", "Unit": "Bytes" }] }
    ]
  },
  "Operation": "putItem",
  "ItemSizeBytes": 412,
  "requestId": "c1d2e3"
}
```

[Powertools for AWS Lambda](https://docs.powertools.aws.dev/lambda/python/latest/) (Python, TypeScript, Java, .NET) writes EMF for you, along with structured logs and traces. **Watch dimensions:** every distinct dimension value is a separate billed metric, so never use IDs, users, or URLs as dimensions. Put those in the log fields instead, where Logs Insights can still query them.

---

## Logs

### Write logs that can be queried

- **Structured JSON, one event per line,** with consistent field names: `timestamp`, `level`, `message`, `service`, `requestId`, `traceId`. Logs Insights discovers JSON fields automatically.
- **Include the trace ID** in every line, so you can move between a trace and its logs. Powertools and the OpenTelemetry SDKs do this.
- **Never log secrets, tokens, or personal data.** Data protection policies on log groups can detect and mask some sensitive data, but treat that as a safety net, not a design.
- **Log at INFO in production,** and make the level changeable without a deployment (an environment variable is enough for Lambda).

### Retention

Log groups keep data forever by default, and storage is billed. Set retention on every group, and find the ones without it:

```sh
aws logs describe-log-groups --query "logGroups[?!retentionInDays].logGroupName" --output text
aws logs put-retention-policy --log-group-name /aws/lambda/<function> --retention-in-days 30
```

The Terraform stacks set `retention_in_days` on every log group they create. Groups created automatically (by a Lambda function that ran before its group existed, for example) don't get it.

### Logs Insights

```sh
QUERY='fields @timestamp, @message | filter level = "ERROR" | sort @timestamp desc | limit 20'
id=$(aws logs start-query --log-group-names /aws/lambda/<function> \
  --start-time $(date -d '-1 hour' +%s) --end-time $(date +%s) --query-string "$QUERY" --query queryId --output text)
sleep 5; aws logs get-query-results --query-id "$id"
```

Queries worth saving (Logs Insights, then Save):

```text
# Slowest Lambda invocations, with cold starts
filter @type = "REPORT"
| fields @requestId, @duration, @initDuration
| sort @duration desc | limit 20

# Cold starts per hour
filter @type = "REPORT" and ispresent(@initDuration)
| stats count() as coldStarts, avg(@initDuration) as avgInitMs by bin(1h)

# API errors by route, from the access log
filter status >= 500 | stats count() as errors by routeKey | sort errors desc
```

### Metric filters

A metric filter turns matching log lines into a CloudWatch metric you can alarm on, for signals that only exist in logs:

```sh
aws logs put-metric-filter --log-group-name /aws/lambda/<function> --filter-name timeouts \
  --filter-pattern '"Task timed out"' \
  --metric-transformations metricName=Timeouts,metricNamespace=ItemsApi,metricValue=1,defaultValue=0
```

---

## Traces

A trace follows one request through every service it touches. On AWS:

- **Instrument with OpenTelemetry.** The [AWS Distro for OpenTelemetry](https://aws-otel.github.io/) (ADOT) packages the OpenTelemetry SDKs and collector with AWS integrations: an ADOT Lambda layer for functions, and the ADOT collector or CloudWatch agent for containers and instances. The X-Ray SDKs and daemon have been in maintenance mode since February 25, 2026, receiving security fixes only ([support timeline](https://docs.aws.amazon.com/xray/latest/devguide/xray-sdk-daemon-timeline.html)), so new work should use OpenTelemetry and existing X-Ray SDK code needs a migration plan.
- **Lambda** can emit X-Ray segments with one setting (API Gateway REST APIs can too, but HTTP APIs, like the serverless-api stack's, can't; the trace starts at the function):

  ```sh
  aws lambda update-function-configuration --function-name <function> --tracing-config Mode=Active
  ```

- **CloudWatch Application Signals** builds on these traces: it discovers services, shows request rate, errors, and latency per operation, draws a service map, and lets you define SLOs with error budgets and burn-rate alarms, all in the CloudWatch console.

Find traces from the command line:

```sh
aws xray get-trace-summaries --start-time $(date -d '-30 min' +%s) --end-time $(date +%s) \
  --filter-expression 'responsetime > 1 OR fault = true' \
  --query "TraceSummaries[].{id:Id, duration:Duration, fault:HasFault, url:Http.HttpURL}" --output table

aws xray batch-get-traces --trace-ids <trace id> --query "Traces[0].Segments[].Document" --output text
```

---

## Alarms

- **Alarm on symptoms users feel** (error rate, latency, availability), not on causes (CPU at 80%). Causes go on dashboards for diagnosis.
- **Use metric math for ratios.** "5xx above 10 a minute" pages at 3 a.m. for 10 errors out of a million requests, and stays quiet when traffic is low and every request fails. "5xx above 1% of requests" doesn't. The template shows the pattern, with `IF(requests > 0, ...)` to handle no traffic.
- **M out of N data points** (`DatapointsToAlarm: 3`, `EvaluationPeriods: 5`) filters single-minute blips.
- **`TreatMissingData`:** `notBreaching` for request metrics, which are missing when there's no traffic; `breaching` for heartbeats, where missing data is the problem.
- **Composite alarms** combine component alarms with AND, OR, and NOT, and can suppress notifications while another alarm (a planned maintenance flag, or an upstream outage) is in ALARM.
- **Anomaly detection** alarms learn a metric's normal daily and weekly pattern and alarm outside a band. Useful for traffic drops, which fixed thresholds can't catch.
- For SLO-style burn-rate alerting, use Application Signals SLOs, or the Prometheus rules in [observability/prometheus](../prometheus/README.md#alert-on-slos-not-on-every-metric) with Amazon Managed Service for Prometheus.

```sh
aws cloudwatch describe-alarms --state-value ALARM \
  --query "MetricAlarms[].{name:AlarmName, reason:StateReason, since:StateUpdatedTimestamp}" --output table
aws cloudwatch describe-alarms --alarm-types CompositeAlarm \
  --query "CompositeAlarms[].{name:AlarmName, state:StateValue, rule:AlarmRule}" --output table
aws cloudwatch describe-alarm-history --alarm-name <alarm> --history-item-type StateUpdate --max-items 10 \
  --query "AlarmHistoryItems[].{time:Timestamp, summary:HistorySummary}" --output table
```

### Test that notifications arrive

An alarm that has never notified anyone might not be able to. Force one into ALARM and check the message arrives where it should; it returns to its real state at the next evaluation:

```sh
aws cloudwatch set-alarm-state --alarm-name "<function>-user-impact" \
  --state-value ALARM --state-reason "Testing the notification path"
```

Do it after any change to the topic, its subscriptions, or the paging integration, and tell the on-call person first.

---

## Containers and EKS

- **ECS:** turn on Container Insights per cluster for task-level CPU, memory, network, and storage metrics, and send container logs with the `awslogs` log driver or FireLens.
- **EKS:** the **Amazon CloudWatch Observability** add-on installs the CloudWatch agent and Fluent Bit, for Container Insights metrics, container logs in CloudWatch Logs, and Application Signals:

  ```sh
  aws eks create-addon --cluster-name <cluster> --addon-name amazon-cloudwatch-observability
  aws eks describe-addon --cluster-name <cluster> --addon-name amazon-cloudwatch-observability --query "addon.{status:status, version:addonVersion}"
  ```

  The add-on's agent needs IAM permissions (the `CloudWatchAgentServerPolicy` managed policy) through EKS Pod Identity or IRSA, the same way as the [eks-pod-identity component](../../kubernetes/components/eks-pod-identity/).

- **Or use Prometheus** for Kubernetes metrics, which most Kubernetes tooling expects: the [SLO rules](../prometheus/rules/web-app-slo.yaml), community dashboards, and the HPA's custom metrics. See below.

---

## Prometheus and Grafana on AWS

**Amazon Managed Service for Prometheus** stores Prometheus metrics and answers PromQL, without servers to run. It takes this repository's rule files as they are:

```sh
aws amp create-workspace --alias web-app
WS=$(aws amp list-workspaces --alias web-app --query "workspaces[0].workspaceId" --output text)

aws amp create-rule-groups-namespace --workspace-id "$WS" --name web-app-slo \
  --data fileb://observability/prometheus/rules/web-app-slo.yaml
aws amp list-rule-groups-namespaces --workspace-id "$WS" --query "ruleGroupsNamespaces[].{name:name, status:status.statusCode}"
```

- **Collect** with the AMP managed scraper for EKS (no agent to run in the cluster), the ADOT collector, or an existing Prometheus with `remote_write` signed with SigV4.
- **Alertmanager** is built in. Upload a configuration with `aws amp create-alert-manager-definition`; its receivers must be SNS topics, so route from there to paging and chat.
- **Query** from Grafana with the Prometheus data source and SigV4 authentication.

**Amazon Managed Grafana** runs Grafana with sign-in through IAM Identity Center or SAML, and data sources that authenticate with IAM roles:

```sh
aws grafana create-workspace --workspace-name observability \
  --account-access-type CURRENT_ACCOUNT --authentication-providers AWS_SSO \
  --permission-type SERVICE_MANAGED --workspace-data-sources CLOUDWATCH PROMETHEUS XRAY
aws grafana list-workspaces --query "workspaces[].{name:name, status:status, url:endpoint}" --output table
```

Then import the dashboards in [observability/grafana/dashboards](../grafana/dashboards/), pointing the Prometheus data source `uid` at the AMP workspace. The [Grafana 101](../grafana/README.md#amazon-cloudwatch) covers the CloudWatch data source.

---

## Cost

CloudWatch bills mostly for data in and queries, so a few habits keep it in check:

| Driver | Control it with |
|---|---|
| Log ingestion (per GB) | Log at INFO, not DEBUG, in production. Drop health-check and noisy access logs at the source. Use the Infrequent Access log class for logs you rarely query. |
| Log storage | Retention on every log group. Export to S3 for long-term, cheaper storage when required. |
| Custom metrics (per metric) | Few dimensions, never IDs. Remove metrics nobody uses. |
| Logs Insights (per GB scanned) | Query narrow time ranges and specific log groups. |
| Dashboards and API calls | Dashboards that refresh every 10 seconds, and Grafana panels on CloudWatch, call the API constantly. |
| X-Ray traces | Sample: record a fixed rate of requests, plus all errors, rather than every request. |

The [AWS cost guide](../../aws/guides/cost.md) shows how to find which of these is growing.
