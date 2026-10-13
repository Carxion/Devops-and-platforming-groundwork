# AWS cost

[← AWS operations](../README.md)

Cost Explorer's API (`ce`) charges a small fee per request. Fine for investigations, but don't put it in a tight loop.

## Where is the money going?

```sh
# Last month, by service
aws ce get-cost-and-usage --time-period Start=2026-09-01,End=2026-10-01 \
  --granularity MONTHLY --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query "ResultsByTime[0].Groups[].[Keys[0], Metrics.UnblendedCost.Amount]" --output text | sort -t$'\t' -k2 -rn | head -15

# Month to date, by account (from the management account)
aws ce get-cost-and-usage --time-period Start=2026-10-01,End=2026-10-12 \
  --granularity MONTHLY --metrics UnblendedCost --group-by Type=DIMENSION,Key=LINKED_ACCOUNT

# By tag. The tag must be activated as a cost allocation tag in Billing first.
aws ce get-cost-and-usage --time-period Start=2026-09-01,End=2026-10-01 \
  --granularity MONTHLY --metrics UnblendedCost --group-by Type=TAG,Key=Project

# Daily trend for one service, to spot when a jump started
aws ce get-cost-and-usage --time-period Start=2026-09-12,End=2026-10-12 --granularity DAILY --metrics UnblendedCost \
  --filter '{"Dimensions": {"Key": "SERVICE", "Values": ["Amazon Elastic Compute Cloud - Compute"]}}' \
  --query "ResultsByTime[].[TimePeriod.Start, Total.UnblendedCost.Amount]" --output text
```

Costs with no tag show up under an empty tag value. That's the share nobody owns ([guide section 3.5](../../README.md#35-resilience-and-cost)).

## Forecasts, budgets, and anomalies

```sh
aws ce get-cost-forecast --time-period Start=2026-10-12,End=2026-11-01 --metric UNBLENDED_COST --granularity MONTHLY \
  --query "Total.Amount" --output text

aws budgets describe-budgets --account-id <account id> \
  --query "Budgets[].{name:BudgetName, limit:BudgetLimit.Amount, actual:CalculatedSpend.ActualSpend.Amount, forecast:CalculatedSpend.ForecastedSpend.Amount}" --output table

aws ce get-anomalies --date-interval StartDate=2026-09-12,EndDate=2026-10-12 \
  --query "Anomalies[].{start:AnomalyStartDate, impact:Impact.TotalImpact, service:RootCauses[0].Service, account:RootCauses[0].LinkedAccount}" --output table
```

No budget yet? See [budget.yaml](../cloudformation/cost/budget.yaml).

## Idle and orphaned resources

Each of these costs money every month while doing nothing.

```sh
# Unattached EBS volumes
aws ec2 describe-volumes --filters Name=status,Values=available \
  --query "Volumes[].{id:VolumeId, sizeGb:Size, type:VolumeType, created:CreateTime}" --output table

# Snapshots older than a date
aws ec2 describe-snapshots --owner-ids self \
  --query "Snapshots[?StartTime<'2026-04-01'].{id:SnapshotId, sizeGb:VolumeSize, started:StartTime, desc:Description}" --output table

# Elastic IPs not attached to anything (billed hourly)
aws ec2 describe-addresses --query "Addresses[?!AssociationId].{ip:PublicIp, allocation:AllocationId}" --output table

# Stopped instances (EBS still billed)
aws ec2 describe-instances --filters Name=instance-state-name,Values=stopped \
  --query "Reservations[].Instances[].{id:InstanceId, type:InstanceType, name:Tags[?Key=='Name']|[0].Value}" --output table

# Load balancers with no registered targets
for tg in $(aws elbv2 describe-target-groups --query "TargetGroups[].TargetGroupArn" --output text); do
  n=$(aws elbv2 describe-target-health --target-group-arn "$tg" --query "length(TargetHealthDescriptions)")
  [ "$n" = "0" ] && echo "empty: $tg"
done

# gp2 volumes (gp3 is cheaper and faster at the same size)
aws ec2 describe-volumes --filters Name=volume-type,Values=gp2 --query "Volumes[].VolumeId" --output text
aws ec2 modify-volume --volume-id <vol-id> --volume-type gp3      # online, no downtime

# Log groups without retention
aws logs describe-log-groups --query "logGroups[?!retentionInDays].{name:logGroupName, bytes:storedBytes}" --output table
```

Before deleting anything, check its tags and CloudTrail history for an owner, and snapshot volumes you aren't sure about.

## Rightsizing and commitments

```sh
# Needs Compute Optimizer turned on (free); recommendations from 14 days of metrics
aws compute-optimizer get-ec2-instance-recommendations \
  --query "instanceRecommendations[].{id:instanceArn, finding:finding, current:currentInstanceType, suggested:recommendationOptions[0].instanceType}" --output table

aws ce get-savings-plans-purchase-recommendation --savings-plans-type COMPUTE_SP \
  --term-in-years ONE_YEAR --payment-option NO_UPFRONT --lookback-period-in-days THIRTY_DAYS \
  --query "SavingsPlansPurchaseRecommendation.SavingsPlansPurchaseRecommendationSummary"
```

Rightsize first, then commit. A Savings Plan bought on oversized instances locks in the waste.

## Untagged resources

```sh
aws resourcegroupstaggingapi get-resources \
  --query "ResourceTagMappingList[?!Tags[?Key=='Owner']].ResourceARN" --output text | tr '\t' '\n' | head -50
```

This API only lists resources that support tagging and have had tags at some point, so it undercounts. For enforcement, use an AWS Config `required-tags` rule or a tag policy in AWS Organizations.
