# Testing the API on AWS

[← API testing](README.md)

How to run the tests in this folder against the [serverless-api stack](../terraform/aws/serverless-api/) (API Gateway HTTP API, Lambda, DynamoDB), and how to see what the API did with each request. For the AWS CLI setup, see [aws/README.md](../aws/README.md#setup).

## Find the endpoint

```sh
BASE_URL=$(terraform -chdir=terraform/aws/serverless-api output -raw api_endpoint)

# Or from the CLI, if you don't have the Terraform state
aws apigatewayv2 get-apis --query "Items[].{name:Name, id:ApiId, endpoint:ApiEndpoint}" --output table
aws apigatewayv2 get-routes --api-id <api id> --query "Items[].{route:RouteKey, auth:AuthorizationType}" --output table
```

The stack uses the `$default` stage, so the endpoint has no stage name in its path: requests go to `$BASE_URL/items/{id}`.

## Get a token

With `jwt_issuer` unset, the API is open and the tests need no token. With it set, API Gateway validates a JWT from that issuer before calling Lambda, and rejects requests without one with `401`.

For automated tests, use a dedicated test client in the identity provider with the OAuth client credentials grant, and the narrowest scopes the test needs:

```sh
# Generic OAuth 2.0 client credentials request; the token URL comes from your identity provider
TOKEN=$(curl -s -X POST "$TOKEN_URL" \
  -d grant_type=client_credentials -d scope="$SCOPE" \
  -u "$CLIENT_ID:$CLIENT_SECRET" | jq -r .access_token)

k6 run -e BASE_URL="$BASE_URL" -e TOKEN="$TOKEN" api-testing/k6/smoke.js
```

In CI, keep the client secret in the pipeline's secret store, or better, use an identity provider that accepts the CI system's own OIDC token so there's no secret at all. Remember that the API's `jwt_audience` must match the token's `aud` claim.

Test that authentication actually works, as well as that it lets you in:

```sh
curl -s -o /dev/null -w "%{http_code}\n" "$BASE_URL/items/test"                                      # expect 401
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer not-a-token" "$BASE_URL/items/test"  # expect 401
```

## Test the function without API Gateway

Invoking Lambda directly separates function bugs from API Gateway configuration (routes, authorizer, throttling). The event must be in the HTTP API payload format 2.0:

```json
{
  "version": "2.0",
  "routeKey": "GET /items/{id}",
  "rawPath": "/items/order-1001",
  "requestContext": { "http": { "method": "GET", "path": "/items/order-1001" } },
  "pathParameters": { "id": "order-1001" }
}
```

```sh
FUNCTION=$(terraform -chdir=terraform/aws/serverless-api output -raw function_name)

aws lambda invoke --function-name "$FUNCTION" \
  --cli-binary-format raw-in-base64-out --payload file://get-event.json response.json
cat response.json            # statusCode, headers, and body, as API Gateway would receive them
```

If the direct invoke works but the same request through the endpoint fails, the problem is in API Gateway: check the route, the authorizer, and the access log below.

## See what happened to each request

The stack writes two log groups: API Gateway access logs (one JSON line per request) and the function's own logs.

```sh
NAME=$(terraform -chdir=terraform/aws/serverless-api output -raw function_name)

aws logs tail "/aws/apigateway/$NAME" --since 15m --format short      # status, route, latency per request
aws logs tail "/aws/lambda/$NAME" --since 15m --follow                 # function output and errors
```

After a load test, summarize the access log with Logs Insights:

```sh
id=$(aws logs start-query --log-group-name "/aws/apigateway/$NAME" \
  --start-time $(date -d '-1 hour' +%s) --end-time $(date +%s) \
  --query-string 'stats count(*) as requests, avg(latency) as avg_ms, pct(latency, 95) as p95_ms by routeKey, status | sort requests desc' \
  --query queryId --output text)
sleep 5; aws logs get-query-results --query-id "$id" --output table
```

`latency` in these logs is the integration latency: time spent in Lambda, as seen by API Gateway. Compare it with k6's `http_req_duration` to see how much time is spent outside the function (network, TLS, API Gateway).

## Throttling and concurrency limits

Know where the API will start rejecting requests before you load test it:

```sh
aws apigatewayv2 get-stage --api-id <api id> --stage-name '$default' \
  --query "{rate:DefaultRouteSettings.ThrottlingRateLimit, burst:DefaultRouteSettings.ThrottlingBurstLimit}"

aws lambda get-function-concurrency --function-name "$FUNCTION"                # reserved concurrency, if set
aws lambda get-account-settings --query "{limit:AccountLimit.ConcurrentExecutions, unreserved:AccountLimit.UnreservedConcurrentExecutions}"
```

- API Gateway answers throttled requests with `429 Too Many Requests`; k6 counts them as failed requests.
- When Lambda runs out of concurrency, its invocations are throttled and API Gateway returns a 5xx error instead of the function's response. The Lambda `Throttles` metric shows it.
- DynamoDB on-demand tables scale automatically but can throttle on sudden large jumps beyond twice the previous peak. Ramp up rather than spike when testing capacity.

Raise `throttle_rate_limit`, `throttle_burst_limit`, and `lambda_reserved_concurrency` in the test environment's tfvars to test beyond the defaults.

## Watch metrics during a load test

```sh
aws cloudwatch get-metric-data --start-time $(date -u -d '-30 min' +%FT%TZ) --end-time $(date -u +%FT%TZ) \
  --metric-data-queries '[
    {"Id":"requests","MetricStat":{"Metric":{"Namespace":"AWS/ApiGateway","MetricName":"Count","Dimensions":[{"Name":"ApiId","Value":"<api id>"}]},"Period":60,"Stat":"Sum"}},
    {"Id":"errors5xx","MetricStat":{"Metric":{"Namespace":"AWS/ApiGateway","MetricName":"5xx","Dimensions":[{"Name":"ApiId","Value":"<api id>"}]},"Period":60,"Stat":"Sum"}},
    {"Id":"p95","MetricStat":{"Metric":{"Namespace":"AWS/ApiGateway","MetricName":"Latency","Dimensions":[{"Name":"ApiId","Value":"<api id>"}]},"Period":60,"Stat":"p95"}},
    {"Id":"throttles","MetricStat":{"Metric":{"Namespace":"AWS/Lambda","MetricName":"Throttles","Dimensions":[{"Name":"FunctionName","Value":"'"$FUNCTION"'"}]},"Period":60,"Stat":"Sum"}}
  ]' --query "MetricDataResults[].{id:Id, values:Values}"
```

The [AWS observability guide](../observability/aws/README.md) sets these up as alarms and a dashboard, which is easier to watch than polling.

## Synthetic monitoring with CloudWatch Synthetics

A canary runs a script on a schedule from AWS's side and alarms when the API stops answering correctly, between deployments and when nobody is testing. Canaries are created with the console's API canary blueprint, CloudFormation, or Terraform (`aws_synthetics_canary`). Once one exists:

```sh
aws synthetics describe-canaries --query "Canaries[].{name:Name, state:Status.State, schedule:Schedule.Expression}" --output table
aws synthetics get-canary-runs --name <canary> --max-results 10 \
  --query "CanaryRuns[].{time:Timeline.Started, status:Status.State, reason:Status.StateReason}" --output table
```

Keep the canary's request read-only, or have it clean up after itself, and give it its own test identity.

## Large-scale load testing

For load beyond what one machine running k6 can generate, run k6 from several machines or containers, or use [Distributed Load Testing on AWS](https://docs.aws.amazon.com/solutions/distributed-load-testing-on-aws/), an AWS solution that runs JMeter, k6, and Locust tests from Fargate tasks. Read the [AWS penetration testing policy](https://aws.amazon.com/security/penetration-testing/) first: it covers which tests need approval, and simulated denial-of-service tests have separate rules.
