# Azure storage and data

[← Azure operations](../README.md)

## Storage accounts

### Security settings at a glance

```sh
az storage account list \
  --query "[].{name:name, rg:resourceGroup, tls:minimumTlsVersion, sharedKey:allowSharedKeyAccess, publicBlob:allowBlobPublicAccess, network:networkRuleSet.defaultAction, publicAccess:publicNetworkAccess}" -o table
```

Look for `sharedKey` not `false` (key-based access is a long-lived credential), `publicBlob` true, and `network` `Allow` (no firewall). Note that `null` for `sharedKey` means the platform default, which allows shared keys.

Tighten an account:

```sh
az storage account update --resource-group <rg> --name <account> \
  --allow-blob-public-access false --min-tls-version TLS1_2 --allow-shared-key-access false
az storage account network-rule add --resource-group <rg> --account-name <account> --ip-address 203.0.113.10
az storage account update --resource-group <rg> --name <account> --default-action Deny
```

Turning off shared keys breaks anything still using connection strings or account-key SAS tokens. Find those first: storage diagnostic logs show the authentication type of each request.

### Data access with Entra ID

`--auth-mode login` uses your Entra ID identity and needs a data role, such as Storage Blob Data Reader, on the account or container. Owner and Contributor aren't enough by themselves.

```sh
az storage container list --auth-mode login --account-name <account> --query "[].name" -o tsv
az storage blob list --auth-mode login --account-name <account> --container-name <container> --prefix reports/ \
  --query "[].{name:name, size:properties.contentLength, modified:properties.lastModified}" -o table
az storage blob download --auth-mode login --account-name <account> --container-name <container> --name reports/q3.csv --file q3.csv
az storage blob upload --auth-mode login --account-name <account> --container-name <container> --name reports/q3.csv --file q3.csv

# Time-limited link signed with your Entra ID credentials (user delegation SAS), not an account key
az storage blob generate-sas --auth-mode login --as-user --account-name <account> --container-name <container> \
  --name reports/q3.csv --permissions r --expiry 2026-10-13T00:00Z --https-only --full-uri -o tsv
```

For large or recursive copies, use [AzCopy](https://learn.microsoft.com/azure/storage/common/storage-use-azcopy-v10) with `azcopy login`.

### Recover deleted or overwritten data

```sh
# Versions and soft-deleted blobs
az storage blob list --auth-mode login --account-name <account> --container-name <container> --prefix reports/q3.csv \
  --include dv --query "[].{name:name, version:versionId, current:isCurrentVersion, deleted:deleted}" -o table

# Undelete a soft-deleted blob
az storage blob undelete --auth-mode login --account-name <account> --container-name <container> --name reports/q3.csv

# Restore an older version: download it, then upload it as the current blob
az storage blob download --auth-mode login --account-name <account> --container-name <container> \
  --name reports/q3.csv --version-id <version id> --file q3-restored.csv

# Restore a deleted container (needs container soft delete)
az storage container list --auth-mode login --account-name <account> --include-deleted \
  --query "[?deleted].{name:name, version:version}" -o table
az storage container restore --auth-mode login --account-name <account> --name <container> --deleted-version <version>
```

## Azure Database for PostgreSQL (flexible server)

```sh
az postgres flexible-server list --query "[].{name:name, rg:resourceGroup, version:version, sku:sku.name, state:state, ha:highAvailability.mode}" -o table
az postgres flexible-server show --resource-group <rg> --name <server> \
  --query "{publicAccess:network.publicNetworkAccess, entra:authConfig.activeDirectoryAuth, password:authConfig.passwordAuth, backupDays:backup.backupRetentionDays, earliestRestore:backup.earliestRestoreDate}"
az postgres flexible-server microsoft-entra-admin list --resource-group <rg> --server-name <server> -o table
az postgres flexible-server parameter show --resource-group <rg> --server-name <server> --name log_connections --query value
```

Connect with an Entra ID token instead of a password (the token is the password, and it expires in about an hour):

```sh
export PGPASSWORD=$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)
psql "host=<server>.postgres.database.azure.com dbname=<db> user=<your upn or group name> sslmode=require"
```

Point-in-time restore creates a **new** server; the original is untouched:

```sh
az postgres flexible-server restore --resource-group <rg> --name <server>-restored \
  --source-server <server> --restore-time 2026-10-12T13:10:00Z
```

A server with private (VNet) access restores into the same delegated subnet by default. Point the application at the restored server only after verifying the data.

## Azure SQL Database

```sh
az sql server list --query "[].{name:name, rg:resourceGroup, public:publicNetworkAccess, minTls:minimalTlsVersion}" -o table
az sql db list --resource-group <rg> --server <server> --query "[].{name:name, sku:currentSku.name, status:status, earliestRestore:earliestRestoreDate}" -o table

az sql db restore --resource-group <rg> --server <server> --name <db> \
  --dest-name <db>-restored --time 2026-10-12T13:10:00Z
```

## Cosmos DB

```sh
az cosmosdb list --query "[].{name:name, rg:resourceGroup, localAuthDisabled:disableLocalAuth, public:publicNetworkAccess, backup:backupPolicy.type}" -o table

# Continuous backup: restore to a new account at a point in time
az cosmosdb restorable-database-account list --account-name <account> --query "[].{id:name, created:creationTime, deleted:deletionTime}" -o table
az cosmosdb restore --resource-group <rg> --account-name <account> --target-database-account-name <account>-restored \
  --restore-timestamp 2026-10-12T13:10:00Z --location eastus2
```

`disableLocalAuth: true` means only Entra ID (RBAC) access works; account keys are rejected. That's the goal ([functions-api](../../terraform/azure/functions-api/) sets it).

## Key Vault

```sh
az keyvault list --query "[].{name:name, rg:resourceGroup}" -o table
az keyvault show --name <vault> \
  --query "properties.{rbac:enableRbacAuthorization, purgeProtection:enablePurgeProtection, softDeleteDays:softDeleteRetentionInDays, public:publicNetworkAccess, firewall:networkAcls.defaultAction}"

az keyvault secret list --vault-name <vault> --query "[].{name:name, enabled:attributes.enabled, expires:attributes.expires, updated:attributes.updated}" -o table
az keyvault certificate list --vault-name <vault> --query "[].{name:name, expires:attributes.expires}" -o table
```

Set a secret from a file, so the value doesn't land in your shell history:

```sh
az keyvault secret set --vault-name <vault> --name db-password --file ./secret.txt --expires 2027-04-01T00:00:00Z
```

### Recover deleted vaults and secrets

```sh
az keyvault secret list-deleted --vault-name <vault> --query "[].{name:name, deleted:deletedDate, purgeDate:scheduledPurgeDate}" -o table
az keyvault secret recover --vault-name <vault> --name <secret>

az keyvault list-deleted --query "[].{name:name, location:properties.location, purgeDate:properties.scheduledPurgeDate}" -o table
az keyvault recover --name <vault>
```

With purge protection on (the [Bicep template](../bicep/security/key-vault.bicep) and Terraform stacks turn it on), deleted items can't be purged before the retention period ends, so a mistake or a malicious delete is always recoverable in that window.

## Azure Backup

```sh
az backup vault list --query "[].{name:name, rg:resourceGroup}" -o table
az backup item list --resource-group <rg> --vault-name <vault> \
  --query "[].{item:properties.friendlyName, type:properties.workloadType, lastBackup:properties.lastBackupTime, status:properties.lastBackupStatus}" -o table
az backup job list --resource-group <rg> --vault-name <vault> --status Failed \
  --query "[].{item:properties.entityFriendlyName, op:properties.operation, start:properties.startTime}" -o table
```

Restore a VM, disk, or file from a recovery point at least once on a schedule. A backup you've never restored is a hope, not a backup ([guide section 3.5](../../README.md#35-resilience-and-cost)).
