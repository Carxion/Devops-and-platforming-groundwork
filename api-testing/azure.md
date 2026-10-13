# Testing the API on Azure

[← API testing](README.md)

How to run the tests in this folder against the [functions-api stack](../terraform/azure/functions-api/) (Azure Functions on Flex Consumption, Cosmos DB), and how to see what the API did with each request. For the Azure CLI setup, see [azure/README.md](../azure/README.md#setup).

## Find the endpoint

```sh
BASE_URL=$(terraform -chdir=terraform/azure/functions-api output -raw api_base_url)
APP=$(terraform -chdir=terraform/azure/functions-api output -raw function_app_name)

# Or from the CLI
az functionapp show --resource-group <rg> --name "$APP" --query defaultHostName -o tsv
az functionapp function list --resource-group <rg> --name "$APP" --query "[].{name:name, url:invokeUrlTemplate}" -o table
```

Functions puts HTTP routes under `/api` by default, so the base URL ends in `/api` and requests go to `$BASE_URL/items/{id}`. If `function list` comes back empty, the infrastructure exists but the code hasn't been published yet (see the stack's `publish_command` output).

## Get a token

With `entra_client_id` unset, the API is open. With it set, App Service Authentication validates an Entra ID token before the function runs, and rejects requests without one with `401`.

```sh
# As yourself, for manual testing. The Azure CLI must be allowed to request tokens for the API:
# add it as an authorized client application on the API's app registration ("Expose an API").
TOKEN=$(az account get-access-token --scope "api://<entra_client_id>/.default" --query accessToken -o tsv)

k6 run -e BASE_URL="$BASE_URL" -e TOKEN="$TOKEN" api-testing/k6/smoke.js
```

For pipelines, sign the CI job in to Azure with workload identity federation (see the [github-oidc stack](../terraform/azure/github-oidc/)), then request a token for the API the same way. There's no client secret to store. The identity needs an app role on the API, granted through the API's enterprise application.

Test that unauthenticated requests are rejected:

```sh
curl -s -o /dev/null -w "%{http_code}\n" "$BASE_URL/items/test"                                         # expect 401
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer not-a-token" "$BASE_URL/items/test"     # expect 401
```

## See what happened to each request

The stack sends the function's telemetry to Application Insights, which stores every request, dependency call (Cosmos DB), and exception.

```sh
APPI=appi-<project>-<environment>-<api_name>     # the stack's Application Insights name

# Requests in the last 30 minutes, by operation and result
az monitor app-insights query --app "$APPI" --resource-group <rg> --offset 30m --analytics-query "
  requests
  | summarize requests = count(), p95_ms = percentile(duration, 95), failures = countif(success == false) by name, resultCode
  | order by requests desc" -o table

# Failures, with the exception that caused each one
az monitor app-insights query --app "$APPI" --resource-group <rg> --offset 1h --analytics-query "
  requests
  | where success == false
  | join kind=leftouter (exceptions | project operation_Id, problemId, outerMessage) on operation_Id
  | project timestamp, name, resultCode, duration, problemId, outerMessage
  | order by timestamp desc
  | take 20" -o table
```

Out of the box, a Python function records requests, logs, and exceptions, but not its calls to Cosmos DB. To see those as `dependencies`, with their own timings, add the Azure Monitor OpenTelemetry distro to the function ([observability/azure](../observability/azure/README.md#instrument-the-code)). Until then, compare the function's request duration with the Cosmos DB metrics.

Telemetry arrives a minute or two after the request. The Live Metrics view in the portal shows it within seconds, which is handier while a load test is running. The [Azure observability guide](../observability/azure/README.md) turns these queries into alerts.

Requests rejected by App Service Authentication (`401`) never reach the function, so they don't appear in `requests`. Use the function app's HTTP 4xx metric to see them.

## Scale and limits

Know where the API will start rejecting or queueing requests before you load test it:

```sh
az functionapp show --resource-group <rg> --name "$APP" \
  --query "functionAppConfig.scaleAndConcurrency.{maxInstances:maximumInstanceCount, memoryMb:instanceMemoryMB}"

az cosmosdb show --resource-group <rg> --name <cosmos account> --query "{capabilities:capabilities[].name, consistency:consistencyPolicy.defaultConsistencyLevel}"
```

- **Function instances** are capped by `maximum_instance_count` in the stack. At the cap, requests queue and latency rises.
- **Cosmos DB serverless** accounts have a per-container throughput ceiling. Above it, Cosmos DB returns `429`, the SDK retries, and latency rises; sustained overload ends in errors. Watch the account's Total Requests metric, split by status code.
- **Cold starts:** Flex Consumption scales to zero by default. The first requests after an idle period are slower; a ramp-up stage absorbs them, a spike test measures them.

## Synthetic monitoring with availability tests

Application Insights availability tests call the API from several Azure regions every few minutes and alert when it stops responding correctly. A *standard test* can send a custom method, headers, and body, and check the status code. Create them in the portal, with Bicep or Terraform (`azurerm_application_insights_standard_web_test`), then:

```sh
az monitor app-insights web-test list --resource-group <rg> -o table

az monitor app-insights query --app "$APPI" --resource-group <rg> --offset 24h --analytics-query "
  availabilityResults
  | summarize availability = round(100.0 * countif(success == true) / count(), 2), p95_ms = percentile(duration, 95) by name, location" -o table
```

Point the test at a read-only request, such as a GET for a known test item, so it never changes data.

## Load testing with Azure Load Testing

[Azure Load Testing](https://learn.microsoft.com/azure/app-testing/load-testing/overview-what-is-azure-load-testing) runs JMeter or Locust scripts at scale from Azure, and shows server-side metrics from Application Insights and Cosmos DB beside the client-side results. It doesn't run k6, so this folder has a Locust version of the same test in [locust/](locust/): [locustfile.py](locust/locustfile.py), its settings in [locust.conf](locust/locust.conf), and the pass/fail criteria in [azure-load-test.yaml](locust/azure-load-test.yaml).

```sh
az extension add --name load

# One-time: a load testing resource
az load create --name <resource> --resource-group <rg> --location <region>

# Create the test from the YAML (uploads the Locust script and settings), then run it
az load test create --load-test-resource <resource> --resource-group <rg> --test-id items-api-load \
  --load-test-config-file api-testing/locust/azure-load-test.yaml --env LOCUST_HOST="$BASE_URL"

RUN_ID="run-$(date +%Y%m%d%H%M%S)"
az load test-run create --load-test-resource <resource> --resource-group <rg> \
  --test-id items-api-load --test-run-id "$RUN_ID"

az load test-run list --load-test-resource <resource> --resource-group <rg> --test-id items-api-load \
  --query "[].{run:testRunId, status:status, result:testResult, started:startDateTime}" -o table
```

`test-run create` waits for the run to finish (add `--no-wait` to return at once). If any `failureCriteria` in the YAML is met, the run's result is `FAILED`. To use the run as a pipeline gate, read the result and fail the job on anything but `PASSED`:

```sh
result=$(az load test-run show --load-test-resource <resource> --resource-group <rg> --test-run-id "$RUN_ID" --query testResult -o tsv)
[ "$result" = "PASSED" ] || { echo "Load test result: $result"; exit 1; }
```

To pass a token, store it in Key Vault and reference it under `secrets` in the YAML, instead of putting it on the command line.

Read the [Microsoft Cloud penetration testing rules of engagement](https://www.microsoft.com/en-us/msrc/pentest-rules-of-engagement) before running security scans or very large load tests against Azure resources.
