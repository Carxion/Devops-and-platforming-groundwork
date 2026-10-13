# AWS storage and data

[← AWS operations](../README.md)

## S3

### Is anything public?

```sh
# Account-wide guardrail (should be all true)
aws s3control get-public-access-block --account-id <account id>

# Per bucket
for b in $(aws s3api list-buckets --query "Buckets[].Name" --output text); do
  printf "%-60s " "$b"
  aws s3api get-bucket-policy-status --bucket "$b" --query PolicyStatus.IsPublic --output text 2>/dev/null || echo "no policy"
done

aws s3api get-public-access-block --bucket <bucket>
aws s3api get-bucket-policy --bucket <bucket> --query Policy --output text | jq .
```

Turn on the account-wide block (it overrides any bucket that tries to go public):

```sh
aws s3control put-public-access-block --account-id <account id> \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### Bucket settings at a glance

```sh
aws s3api get-bucket-encryption --bucket <bucket>
aws s3api get-bucket-versioning --bucket <bucket>
aws s3api get-bucket-ownership-controls --bucket <bucket>
aws s3api get-bucket-lifecycle-configuration --bucket <bucket>
aws s3api get-bucket-logging --bucket <bucket>
```

### Recover a deleted or overwritten object

With versioning on, a delete only adds a delete marker. Remove the marker to restore the object:

```sh
aws s3api list-object-versions --bucket <bucket> --prefix reports/q3.csv \
  --query "{versions:Versions[].{id:VersionId, modified:LastModified, latest:IsLatest}, deleteMarkers:DeleteMarkers[].{id:VersionId, modified:LastModified}}"

# Undelete: remove the delete marker
aws s3api delete-object --bucket <bucket> --key reports/q3.csv --version-id <delete marker version id>

# Roll back an overwrite: copy the old version over the current one
aws s3api copy-object --bucket <bucket> --key reports/q3.csv --copy-source "<bucket>/reports/q3.csv?versionId=<old version id>"
```

### Everyday transfers

```sh
aws s3 ls s3://<bucket>/reports/ --human-readable --summarize
aws s3 sync ./build s3://<bucket>/site/ --delete --dryrun     # preview, then run without --dryrun
aws s3 cp large.tar s3://<bucket>/backups/ --sse aws:kms
aws s3 presign s3://<bucket>/reports/q3.csv --expires-in 900  # time-limited download link, 15 minutes
```

## RDS and Aurora

```sh
aws rds describe-db-instances \
  --query "DBInstances[].{id:DBInstanceIdentifier, engine:Engine, version:EngineVersion, class:DBInstanceClass, status:DBInstanceStatus, multiAz:MultiAZ, encrypted:StorageEncrypted, public:PubliclyAccessible, backups:BackupRetentionPeriod}" \
  --output table

aws rds describe-events --source-type db-instance --source-identifier <db> --duration 1440 \
  --query "Events[].[Date, Message]" --output text         # last 24 hours: failovers, restarts, maintenance

aws rds describe-pending-maintenance-actions
aws rds describe-db-log-files --db-instance-identifier <db>
```

### Snapshots and point-in-time restore

Restores always create a **new** instance; the original is untouched. Point the application at the new endpoint once it's verified.

```sh
aws rds create-db-snapshot --db-instance-identifier <db> --db-snapshot-identifier <db>-before-change-$(date +%Y%m%d)
aws rds describe-db-snapshots --db-instance-identifier <db> --query "DBSnapshots[].{id:DBSnapshotIdentifier, created:SnapshotCreateTime, type:SnapshotType}" --output table

aws rds describe-db-instances --db-instance-identifier <db> --query "DBInstances[0].LatestRestorableTime"

aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier <db> \
  --target-db-instance-identifier <db>-restored \
  --restore-time 2026-10-12T13:10:00Z \
  --db-subnet-group-name <subnet group> \
  --vpc-security-group-ids <sg-id> \
  --no-publicly-accessible

aws rds wait db-instance-available --db-instance-identifier <db>-restored
```

For Aurora, the equivalents are `aws rds describe-db-clusters` and `aws rds restore-db-cluster-to-point-in-time`, followed by `aws rds create-db-instance` to add an instance to the restored cluster.

Test a Multi-AZ failover (expect a short outage):

```sh
aws rds reboot-db-instance --db-instance-identifier <db> --force-failover
```

## DynamoDB

```sh
aws dynamodb list-tables
aws dynamodb describe-table --table-name <table> --query "Table.{status:TableStatus, items:ItemCount, sizeBytes:TableSizeBytes, billing:BillingModeSummary.BillingMode, deletionProtection:DeletionProtectionEnabled}"
aws dynamodb describe-continuous-backups --table-name <table> --query "ContinuousBackupsDescription.PointInTimeRecoveryDescription"

# Restore to a new table at a point in time
aws dynamodb restore-table-to-point-in-time --source-table-name <table> --target-table-name <table>-restored \
  --restore-date-time 2026-10-12T13:10:00Z

aws dynamodb create-backup --table-name <table> --backup-name <table>-before-migration
```

Avoid `scan` on large tables in production. It reads and bills every item. `aws dynamodb get-item` and `query` read only what you ask for.

## AWS Backup

```sh
aws backup list-backup-plans --query "BackupPlansList[].{name:BackupPlanName, id:BackupPlanId}" --output table
aws backup list-backup-jobs --by-state FAILED --query "BackupJobs[].{resource:ResourceArn, created:CreationDate, message:StatusMessage}" --output table
aws backup list-recovery-points-by-backup-vault --backup-vault-name <vault> --max-items 20 \
  --query "RecoveryPoints[].{resource:ResourceArn, created:CreationDate, status:Status}" --output table
```

A backup you've never restored is a hope, not a backup ([guide section 3.5](../../README.md#35-resilience-and-cost)). Restores have resource-specific options, so run them from the console or `aws backup start-restore-job` with the metadata from `aws backup get-recovery-point-restore-metadata`. Do one on a schedule.

## Secrets Manager

```sh
aws secretsmanager list-secrets --query "SecretList[].{name:Name, rotation:RotationEnabled, lastRotated:LastRotatedDate, lastAccessed:LastAccessedDate}" --output table
aws secretsmanager describe-secret --secret-id <secret>
aws secretsmanager rotate-secret --secret-id <secret>                       # rotate now (needs a rotation function)
aws secretsmanager restore-secret --secret-id <secret>                      # undo a scheduled deletion
```

`get-secret-value` prints the secret in plain text to your terminal and shell history. Use it only when you must, and never in shared screens or CI logs.

## KMS

```sh
aws kms list-aliases --query "Aliases[?!starts_with(AliasName, 'alias/aws/')].{alias:AliasName, key:TargetKeyId}" --output table
aws kms describe-key --key-id <key id or alias> --query "KeyMetadata.{state:KeyState, manager:KeyManager, created:CreationDate, deletion:DeletionDate}"
aws kms get-key-rotation-status --key-id <key id>
aws kms get-key-policy --key-id <key id> --policy-name default --output text | jq .

# Deleting a key makes everything encrypted with it unreadable. Disable first, wait, then schedule.
aws kms disable-key --key-id <key id>
aws kms schedule-key-deletion --key-id <key id> --pending-window-in-days 30
aws kms cancel-key-deletion --key-id <key id>
```
