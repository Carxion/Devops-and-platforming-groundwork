# AWS security and incident response

[← AWS operations](../README.md)

## Findings

### GuardDuty

```sh
detector=$(aws guardduty list-detectors --query "DetectorIds[0]" --output text)

# High and critical findings (severity 7+), not archived
aws guardduty list-findings --detector-id "$detector" \
  --finding-criteria '{"Criterion": {"severity": {"Gte": 7}, "service.archived": {"Eq": ["false"]}}}' \
  --query "FindingIds" --output text

aws guardduty get-findings --detector-id "$detector" --finding-ids <finding id> \
  --query "Findings[].{type:Type, severity:Severity, resource:Resource.ResourceType, title:Title, updated:UpdatedAt}"
```

### Security Hub

```sh
aws securityhub get-findings --max-items 25 \
  --filters '{"SeverityLabel": [{"Value": "CRITICAL", "Comparison": "EQUALS"}], "RecordState": [{"Value": "ACTIVE", "Comparison": "EQUALS"}], "WorkflowStatus": [{"Value": "NEW", "Comparison": "EQUALS"}]}' \
  --query "Findings[].{title:Title, resource:Resources[0].Id, product:ProductName}" --output table

aws securityhub get-enabled-standards --query "StandardsSubscriptions[].{standard:StandardsArn, status:StandardsStatus}"
```

### Inspector

```sh
aws inspector2 list-coverage --query "coveredResources[].{type:resourceType, id:resourceId, status:scanStatus.statusCode}" --output table

aws inspector2 list-findings --max-results 25 \
  --filter-criteria '{"severity": [{"comparison": "EQUALS", "value": "CRITICAL"}], "findingStatus": [{"comparison": "EQUALS", "value": "ACTIVE"}]}' \
  --query "findings[].{title:title, resource:resources[0].id, fix:fixAvailable, exploit:exploitAvailable}" --output table
```

Prioritize findings where `exploitAvailable` is `YES`, and anything in CISA's Known Exploited Vulnerabilities catalog, over CVSS score alone ([guide section 7.4](../../README.md#74-vulnerability-management)).

---

## Incident runbooks

These are first-response steps that limit damage and preserve evidence. Follow your program's incident response plan and notification requirements; regulated programs often have reporting deadlines measured in hours.

General rules:

- **Contain, don't destroy.** Disable, isolate, and snapshot. Deleting resources destroys evidence.
- **Write down every action with its UTC time.** CloudTrail records API calls, but not your reasoning.
- **Work from a known-clean identity**, not the possibly compromised one.

### Leaked access key

Someone found an `AKIA...` key in a repository, a log, or a paste site.

```sh
key=<AKIA...>

# 1. Whose is it?
aws iam list-users --query "Users[].UserName" --output text | tr '\t' '\n' | while read u; do
  aws iam list-access-keys --user-name "$u" --query "AccessKeyMetadata[?AccessKeyId=='$key'].UserName" --output text
done

# 2. Disable it now (reversible)
aws iam update-access-key --user-name <user> --access-key-id "$key" --status Inactive

# 3. What did it do? Check every region it might have used.
aws cloudtrail lookup-events --lookup-attributes AttributeKey=AccessKeyId,AttributeValue="$key" \
  --query "Events[].{time:EventTime, event:EventName, source:EventSource}" --output table

# 4. Look for persistence: new users, keys, roles, and trust changes
for e in CreateUser CreateAccessKey CreateRole UpdateAssumeRolePolicy AttachRolePolicy PutRolePolicy CreateLoginProfile; do
  aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=$e --start-time <time of leak> \
    --query "Events[].{time:EventTime, who:Username, event:EventName}" --output table
done

# 5. Look for new compute in every region (crypto-mining is the common payload)
for r in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do
  aws ec2 describe-instances --region "$r" --filters Name=instance-state-name,Values=running \
    --query "Reservations[].Instances[].{region:Placement.AvailabilityZone, id:InstanceId, type:InstanceType, launched:LaunchTime}" --output table
done
```

Then delete the key, remove whatever the attacker created, and rotate anything the key could read (secrets, other keys). Finally, fix how the key leaked. The lasting fix is removing long-lived keys entirely: use roles and OIDC.

### Compromised EC2 instance

```sh
i=<i-id>

# 1. Keep it from being terminated or replaced, so the evidence survives
aws ec2 modify-instance-attribute --instance-id "$i" --disable-api-termination
aws autoscaling detach-instances --instance-ids "$i" --auto-scaling-group-name <asg> --no-should-decrement-desired-capacity

# 2. Isolate: a security group with no rules allows nothing in or out
vpc=$(aws ec2 describe-instances --instance-ids "$i" --query "Reservations[0].Instances[0].VpcId" --output text)
sg=$(aws ec2 create-security-group --group-name "isolation-$i" --description "Isolation for incident" --vpc-id "$vpc" --query GroupId --output text)
aws ec2 revoke-security-group-egress --group-id "$sg" --ip-permissions '[{"IpProtocol": "-1", "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}]'
aws ec2 modify-instance-attribute --instance-id "$i" --groups "$sg"

# 3. Cut off its credentials: detach the instance profile
assoc=$(aws ec2 describe-iam-instance-profile-associations --filters Name=instance-id,Values="$i" --query "IamInstanceProfileAssociations[0].AssociationId" --output text)
aws ec2 disassociate-iam-instance-profile --association-id "$assoc"

# 4. Preserve the disks
for v in $(aws ec2 describe-instances --instance-ids "$i" --query "Reservations[0].Instances[0].BlockDeviceMappings[].Ebs.VolumeId" --output text); do
  aws ec2 create-snapshot --volume-id "$v" --description "Forensic snapshot $i INC-<number>" \
    --tag-specifications 'ResourceType=snapshot,Tags=[{Key=Incident,Value=INC-<number>}]'
done

# 5. Tag it so nobody "cleans it up"
aws ec2 create-tags --resources "$i" --tags Key=Incident,Value=INC-<number> Key=DoNotTerminate,Value=true
```

Changing security groups doesn't always cut connections that are already established. For a hard cut, also add a deny-all network ACL to the instance's subnet, if nothing else in that subnet needs to keep working. Credentials the instance already handed out stay valid until they expire, so also revoke the role's sessions (next runbook).

### Compromised role session

Temporary credentials can't be deleted, but you can deny every session issued before now. This is what the console's "Revoke active sessions" button does:

```sh
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
aws iam put-role-policy --role-name <role> --policy-name AWSRevokeOlderSessions --policy-document "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{
    \"Effect\": \"Deny\",
    \"Action\": \"*\",
    \"Resource\": \"*\",
    \"Condition\": {\"DateLessThan\": {\"aws:TokenIssueTime\": \"$now\"}}
  }]
}"
```

Legitimate users and services simply get new sessions. Then find out how the session was obtained: look up `AssumeRole` and `AssumeRoleWithWebIdentity` events for the role in CloudTrail.

### Bucket exposed publicly

```sh
aws s3api put-public-access-block --bucket <bucket> \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Then establish what was read while it was exposed. That needs S3 server access logs or CloudTrail data events, which only exist if they were on beforehand. That's a good reason to turn them on for sensitive buckets now.
