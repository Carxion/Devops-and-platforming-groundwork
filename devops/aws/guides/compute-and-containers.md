# AWS compute and containers

[← AWS operations](../README.md)

## EC2

```sh
aws ec2 describe-instances --filters Name=instance-state-name,Values=running,stopped \
  --query "Reservations[].Instances[].{id:InstanceId, type:InstanceType, state:State.Name, ip:PrivateIpAddress, az:Placement.AvailabilityZone, name:Tags[?Key=='Name']|[0].Value}" \
  --output table

aws ec2 describe-instance-status --instance-ids <i-id> --include-all-instances \
  --query "InstanceStatuses[].{state:InstanceState.Name, system:SystemStatus.Status, instance:InstanceStatus.Status}"

aws ec2 get-console-output --instance-id <i-id> --latest --output text    # boot log, for instances that won't come up

aws ec2 stop-instances --instance-ids <i-id> --dry-run     # check permissions first
aws ec2 stop-instances --instance-ids <i-id>
aws ec2 start-instances --instance-ids <i-id>
aws ec2 reboot-instances --instance-ids <i-id>
```

### Shell access without SSH

Session Manager gives a shell over the SSM agent, with no inbound port, no SSH keys, and every session logged:

```sh
aws ssm describe-instance-information \
  --query "InstanceInformationList[].{id:InstanceId, ping:PingStatus, agent:AgentVersion, os:PlatformName}" --output table

aws ssm start-session --target <i-id>

# Forward a port, for example to reach a database through the instance
aws ssm start-session --target <i-id> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters host=db.internal.example.com,portNumber=5432,localPortNumber=15432
```

An instance missing from `describe-instance-information` usually lacks the SSM agent, the `AmazonSSMManagedInstanceCore` permission on its instance role, or a network path to the SSM endpoints (NAT or VPC endpoints for `ssm`, `ssmmessages`, and `ec2messages`).

### Run a command on many instances

```sh
cmd=$(aws ssm send-command --document-name AWS-RunShellScript \
  --targets Key=tag:Role,Values=web \
  --parameters 'commands=["uptime","df -h /"]' \
  --comment "disk check for INC-1234" \
  --query Command.CommandId --output text)

aws ssm list-command-invocations --command-id "$cmd" --details \
  --query "CommandInvocations[].{instance:InstanceId, status:Status, output:CommandPlugins[0].Output}"
```

### Patching and hardening checks

```sh
aws ssm describe-instance-patch-states --instance-ids <i-id> \
  --query "InstancePatchStates[].{missing:MissingCount, failed:FailedCount, installed:InstalledCount, lastScan:OperationEndTime}"

# Instances still allowing IMDSv1 (credential theft risk through SSRF)
aws ec2 describe-instances --query "Reservations[].Instances[?MetadataOptions.HttpTokens=='optional'].InstanceId" --output text
aws ec2 modify-instance-metadata-options --instance-id <i-id> --http-tokens required --http-endpoint enabled
```

### Auto Scaling groups

```sh
aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[].{name:AutoScalingGroupName, min:MinSize, desired:DesiredCapacity, max:MaxSize, instances:length(Instances)}" --output table
aws autoscaling describe-scaling-activities --auto-scaling-group-name <asg> --max-items 10 \
  --query "Activities[].{time:StartTime, status:StatusCode, cause:Cause}"
aws autoscaling start-instance-refresh --auto-scaling-group-name <asg>      # roll instances onto a new launch template
aws autoscaling describe-instance-refreshes --auto-scaling-group-name <asg>
```

## ECS

```sh
aws ecs list-clusters
aws ecs list-services --cluster <cluster>

aws ecs describe-services --cluster <cluster> --services <service> \
  --query "services[].{desired:desiredCount, running:runningCount, pending:pendingCount, taskDef:taskDefinition, deployments:deployments[].{status:status, rollout:rolloutState, running:runningCount, reason:rolloutStateReason}}"

# Recent service events: placement failures, health check failures, steady state
aws ecs describe-services --cluster <cluster> --services <service> --query "services[0].events[:10].[createdAt, message]" --output text
```

### Why did tasks stop?

```sh
aws ecs list-tasks --cluster <cluster> --service-name <service> --desired-status STOPPED --query "taskArns" --output text

aws ecs describe-tasks --cluster <cluster> --tasks <task arn> \
  --query "tasks[].{stopped:stoppedReason, code:stopCode, containers:containers[].{name:name, exit:exitCode, reason:reason}}"
```

| Stopped reason contains | Meaning |
|---|---|
| `CannotPullContainerError` | Image or digest not found, no ECR permission on the execution role, or no route to ECR |
| `ResourceInitializationError` | Couldn't fetch secrets or logs configuration; usually the execution role or networking |
| `Essential container in task exited` | The app exited; check its exit code and logs |
| `Task failed ELB health checks` | Running, but the target group marked it unhealthy; check the health check path and the security group |
| `OutOfMemoryError` / exit code 137 | Exceeded the task or container memory |

Stopped tasks are kept for only about an hour, so look soon.

### Deploy, scale, and get in

```sh
aws ecs update-service --cluster <cluster> --service <service> --force-new-deployment   # restart on the same task definition
aws ecs update-service --cluster <cluster> --service <service> --desired-count 0        # stop (autoscaling may scale back up)
aws ecs wait services-stable --cluster <cluster> --services <service>

aws logs tail /ecs/<service log group> --follow --since 15m

# Needs enableExecuteCommand on the service; the reference stack leaves it off.
aws ecs execute-command --cluster <cluster> --task <task id> --container <container> --interactive --command "/bin/sh"
```

## Lambda

```sh
aws lambda list-functions --query "Functions[].{name:FunctionName, runtime:Runtime, memory:MemorySize, timeout:Timeout, modified:LastModified}" --output table
aws lambda get-function-configuration --function-name <function>

aws lambda invoke --function-name <function> --cli-binary-format raw-in-base64-out \
  --payload '{"test": true}' response.json && cat response.json

aws logs tail /aws/lambda/<function> --follow --since 10m
```

Emergency stop: setting reserved concurrency to zero throttles every invocation, without deleting anything:

```sh
aws lambda put-function-concurrency --function-name <function> --reserved-concurrent-executions 0
aws lambda delete-function-concurrency --function-name <function>     # undo
```

Runtimes reach end of support. Find functions on old ones:

```sh
aws lambda list-functions --query "Functions[?starts_with(Runtime, 'python3.8') || starts_with(Runtime, 'nodejs16')].{name:FunctionName, runtime:Runtime}" --output table
```

## ECR

```sh
aws ecr describe-repositories --query "repositories[].{name:repositoryName, mutability:imageTagMutability, scanOnPush:imageScanningConfiguration.scanOnPush}" --output table

# Newest five images
aws ecr describe-images --repository-name <repo> \
  --query "sort_by(imageDetails, &imagePushedAt)[-5:].{digest:imageDigest, tags:imageTags, pushed:imagePushedAt}" --output table

# Vulnerability findings for one image
aws ecr describe-image-scan-findings --repository-name <repo> --image-id imageDigest=<sha256:...> \
  --query "imageScanFindings.findingSeverityCounts"

# Sign in Docker to the registry
aws ecr get-login-password | docker login --username AWS --password-stdin 111122223333.dkr.ecr.us-east-1.amazonaws.com
```

With enhanced scanning (Amazon Inspector) turned on, findings appear in Inspector too; see [Security](security-and-incident-response.md#inspector).

## EKS

Cluster-level commands are here; everything inside the cluster is in [devops/kubernetes/OPERATIONS.md](../../kubernetes/OPERATIONS.md).

```sh
aws eks list-clusters
aws eks update-kubeconfig --region us-east-1 --name <cluster>
aws eks describe-cluster --name <cluster> --query "cluster.{version:version, status:status, endpointPublic:resourcesVpcConfig.endpointPublicAccess}"
aws eks list-nodegroups --cluster-name <cluster>
aws eks describe-nodegroup --cluster-name <cluster> --nodegroup-name <nodegroup> --query "nodegroup.{status:status, version:version, health:health.issues}"
aws eks list-addons --cluster-name <cluster>
aws eks list-insights --cluster-name <cluster>       # upgrade readiness: deprecated APIs and version skew
```
