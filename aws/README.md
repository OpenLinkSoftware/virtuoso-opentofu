# Virtuoso Self-managed Service on AWS ECS Fargate

Deploy OpenLink Virtuoso Universal Server on AWS using ECS Fargate with persistent EFS storage and secure password management via AWS Secrets Manager.

Supports both **Virtuoso Open Source 7** and **Virtuoso Commercial 8** editions.

## Architecture

```
                    ┌─────────────────────────────────────────────────────────┐
                    │                         VPC                             │
                    │  ┌─────────────────────────────────────────────────┐   │
                    │  │              Public Subnets (2 AZs)              │   │
                    │  │  ┌─────────────────────────────────────────┐    │   │
Internet ──────────►│  │  │       Network Load Balancer (NLB)       │    │   │
  (HTTP/HTTPS/SQL)  │  │  │   Port 80 → 8890 (HTTP)                 │    │   │
                    │  │  │   Port 443 → 8891 (HTTPS)               │    │   │
                    │  │  │   Port 1112 → 1112 (secure SQL/ODBC/JDBC)      │    │   │
                    │  │  └─────────────────────────────────────────┘    │   │
                    │  └─────────────────────────────────────────────────┘   │
                    │                         │                               │
                    │  ┌─────────────────────────────────────────────────┐   │
                    │  │             Private Subnets (2 AZs)             │   │
                    │  │  ┌─────────────────────────────────────────┐    │   │
                    │  │  │         ECS Fargate Task (Virtuoso)     │    │   │
                    │  │  │                    │                    │    │   │
                    │  │  │              EFS Mount (/database)      │    │   │
                    │  │  └─────────────────────────────────────────┘    │   │
                    │  │                      │                          │   │
                    │  │  ┌─────────────────────────────────────────┐    │   │
                    │  │  │           EFS (Persistent Storage)      │    │   │
                    │  │  └─────────────────────────────────────────┘    │   │
                    │  └─────────────────────────────────────────────────┘   │
                    └─────────────────────────────────────────────────────────┘
```

## Project Structure

```
virtuoso-opentofu/aws/
├── README.md                  # This documentation file
├── deploy.sh                  # Interactive deployment script
├── versions.tf                # OpenTofu/Terraform and provider version constraints
├── variables.tf               # Input variable definitions
├── terraform.tfvars           # Your configuration values (create from example)
├── terraform.tfvars.example   # Example configuration template
├── data.tf                    # Data sources (availability zones)
├── networking.tf              # VPC, subnets, gateways, route tables, security groups
├── efs.tf                     # EFS file system and mount targets
├── iam.tf                     # IAM roles and policies for ECS
├── secrets.tf                 # Secrets Manager and password generation
├── ecs.tf                     # ECS cluster, task definition, and service
├── nlb.tf                     # Network Load Balancer (HTTP, HTTPS, SQL)
├── outputs.tf                 # Output values (URLs, ARNs, IDs)
├── .terraform/                # OpenTofu providers and modules (generated)
├── .terraform.lock.hcl        # Provider version lock file (generated)
└── terraform.tfstate          # State file (generated, or remote)
```

### File Descriptions

| File | Purpose |
|------|---------|
| `deploy.sh` | Interactive script for configuring and deploying Virtuoso |
| `versions.tf` | Specifies required OpenTofu version (>=1.5.0) and AWS/random providers |
| `variables.tf` | Defines all configurable inputs with types and descriptions |
| `terraform.tfvars` | Your actual configuration values (not committed to git) |
| `terraform.tfvars.example` | Template showing all available options with examples |
| `data.tf` | Fetches available AWS availability zones and EFS KMS key for encryption |
| `networking.tf` | Creates VPC infrastructure or references existing VPC; includes ECS security group for ports 8890, 8891, 1112, 2049 |
| `efs.tf` | Creates encrypted EFS file system with mount targets in each private subnet |
| `iam.tf` | Creates ECS execution role (pulls images, reads secrets, KMS for EFS) and task role (ECS Exec via SSM) |
| `secrets.tf` | Generates random 20-char password and stores in AWS Secrets Manager |
| `ecs.tf` | Defines Fargate task (container config, EFS mount) and service (load balancer integration) |
| `nlb.tf` | Creates internet-facing NLB with listeners for HTTP (80), HTTPS (443), and secure SQL (1112) |
| `outputs.tf` | Exports useful values like NLB DNS name, URLs, secret ARN, cluster/service names |

## Features

- **ECS Fargate**: Serverless container orchestration (no EC2 instances to manage)
- **EFS Persistence**: Encrypted EFS storage with KMS; database survives container restarts
- **Secrets Manager**: Auto-generated secure DBA password
- **Network Load Balancer**: Single DNS name exposing HTTP (80), HTTPS (443), and secure SQL (1112) ports
- **Full Protocol Support**: HTTP, HTTPS (Virtuoso's built-in SSL), and SQL/ODBC/JDBC access
- **ECS Exec**: Shell access to running containers for debugging
- **Flexible VPC**: Create new VPC or use existing one
- **Interactive Deployment**: Guided setup via `deploy.sh` script
- **Dual Image Support**: Open Source 7 or Commercial 8 editions

## Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.5.0 (or Terraform >= 1.5.0)
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- AWS account with permissions for: ECS, EFS, NLB, VPC, IAM, Secrets Manager, CloudWatch
- For Commercial edition: Valid Virtuoso license file from OpenLink Software

## Quick Start

### Option A: Interactive Deployment (Recommended)

Run the interactive deployment script:

```bash
./deploy.sh
```

The script will guide you through:
1. Selecting AWS region and project name
2. Choosing Virtuoso edition (Open Source or Commercial)
3. Providing license file path (Commercial only)
4. Selecting container size (CPU/memory)
5. Deploying the infrastructure

### Option B: Manual Deployment

#### 1. Configure Variables

Copy the example configuration:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your settings:

```hcl
region       = "us-east-1"
project_name = "virtuoso"

# Virtuoso Image (choose one)
virtuoso_image     = "openlink/virtuoso-opensource-7"  # Free, open source
# virtuoso_image   = "openlink/virtuoso-closedsource-8"  # Commercial, requires license
virtuoso_image_tag = "latest"

# License file (required for Commercial edition only)
# virtuoso_license_file = "/path/to/virtuoso.lic"

# Container sizing (required - no defaults)
ecs_cpu       = "1024"
ecs_memory    = "2048"
```

#### 2. Deploy

```bash
# Initialize OpenTofu
tofu init

# Preview changes
tofu plan

# Deploy infrastructure
tofu apply
```

### Access Virtuoso

After deployment completes, the outputs will display:

```
virtuoso_dns_name    = "virtuoso-nlb-XXXXXXXXX.elb.us-east-1.amazonaws.com"
virtuoso_http_url    = "http://virtuoso-nlb-XXXXXXXXX.elb.us-east-1.amazonaws.com"
virtuoso_https_url   = "https://virtuoso-nlb-XXXXXXXXX.elb.us-east-1.amazonaws.com"
virtuoso_sql_endpoint = "virtuoso-nlb-XXXXXXXXX.elb.us-east-1.amazonaws.com:1112"
secret_name          = "virtuoso-test-dba-password"
secret_arn           = "arn:aws:secretsmanager:us-east-1:XXXXXXXXXXXX:secret:virtuoso-test-dba-password-XXXXXX"
```

**Retrieve the DBA password:**

```bash
aws secretsmanager get-secret-value   --region "$(tofu output -raw region)"   --secret-id "$(tofu output -raw secret_name)"   --query SecretString   --output text
```

**Access the Conductor UI (HTTP):**

Open `http://<virtuoso_dns_name>/conductor/` in your browser and login with:
- Username: `dba`
- Password: (retrieved from Secrets Manager above)

**Access the Conductor UI (HTTPS):**

Open `https://<virtuoso_dns_name>/conductor/` (uses Virtuoso's built-in SSL certificate, shared with secure SQL on port `1112`)

**SPARQL Endpoint:**

```
http://<virtuoso_dns_name>/sparql
https://<virtuoso_dns_name>/sparql
```

**SQL/ODBC/JDBC Connection (TLS):**

```
Host: <virtuoso_dns_name>
Port: 1112
Username: dba
Password: (from Secrets Manager)
```

`isql` example:

```bash
isql <virtuoso_dns_name>:1112 dba <DBA_PASSWORD> -E
```

When using the baseline deployment, `isql -E` will warn that the server certificate is self-signed, typically with a subject like `/CN=virtuoso.local`. This is expected for the generated default certificate and still confirms that the SQL session is encrypted.

## Virtuoso Editions

### Open Source 7 (Free)

```hcl
virtuoso_image     = "openlink/virtuoso-opensource-7"
virtuoso_image_tag = "latest"
```

- Free to use
- Community supported
- Database path: `/opt/virtuoso-opensource/database`

### Commercial 8 (Licensed)

```hcl
virtuoso_image        = "openlink/virtuoso-closedsource-8"
virtuoso_image_tag    = "latest"
virtuoso_license_file = "/path/to/virtuoso.lic"
```

- Requires license from [OpenLink Software](https://www.openlinksw.com)
- Enterprise features and support
- Database path: `/opt/virtuoso/database`

**License File Handling:**

When using the Commercial edition via `deploy.sh`:
1. The infrastructure is deployed first
2. The license file is copied to EFS storage
3. The service is restarted to apply the license

To copy a license file to an existing deployment:

```bash
./deploy.sh --copy-license /path/to/virtuoso.lic
```

## Configuration Reference

## Multiple Deployments In One AWS Account

You can run multiple self-managed Virtuoso deployments in the same AWS account. A separate AWS account is not required for each deployment.

The important constraint is OpenTofu state:

- One OpenTofu state file manages one deployment lifecycle.
- Re-running `tofu apply` in the same directory with the same state updates the existing deployment instead of creating a second one.
- To create multiple concurrent deployments, use separate state for each deployment and a distinct naming prefix.

Recommended pattern:

1. Use a different `project_name` for each deployment.
2. Keep each deployment in a separate working directory or separate backend/state key.
3. Destroy each deployment from the same state context that created it.

Example naming:

```hcl
project_name = "virtuoso-dev-1"
```

```hcl
project_name = "virtuoso-dev-2"
```

Simple approaches:

- Separate directories:

```bash
cp -R aws aws-dev-1
cp -R aws aws-dev-2
```

- Separate state files:

```bash
tofu apply -state=terraform-dev-1.tfstate
tofu apply -state=terraform-dev-2.tfstate
```

- Separate backend keys if using remote state.

Operational cautions:

- Watch AWS quotas for VPCs, subnets, EFS, NLBs, ECS services/tasks, Elastic IP-related resources, and CloudWatch artifacts.
- Keep `project_name` distinct so resource names remain readable and operationally separable.
- Do not try to manage two separate live deployments from one shared state file.

### Required Variables

These variables have no defaults and must be specified:

| Variable | Description |
|----------|-------------|
| `virtuoso_image` | Docker image (`openlink/virtuoso-opensource-7` or `openlink/virtuoso-closedsource-8`) |
| `virtuoso_image_tag` | Image tag (e.g., `latest`) |
| `ecs_cpu` | CPU units for the container |
| `ecs_memory` | Memory in MiB for the container |

### Variables with Defaults

| Variable | Description | Default |
|----------|-------------|---------|
| `region` | AWS region | `us-east-1` |
| `project_name` | Prefix for all resource names | `virtuoso` |
| `virtuoso_license_file` | Path to license file (Commercial only) | `""` |

### VPC Options

**Option A: Create New VPC (default)**

| Variable | Description | Default |
|----------|-------------|---------|
| `create_vpc` | Create new VPC | `true` |
| `vpc_cidr` | VPC CIDR block | `192.168.0.0/16` |
| `public_subnet_cidrs` | Public subnet CIDRs (min 2) | `["192.168.0.0/24", "192.168.1.0/24"]` |
| `private_subnet_cidrs` | Private subnet CIDRs (min 2) | `["192.168.128.0/24", "192.168.129.0/24"]` |
| `expose_sql_endpoint` | Expose public secure SQL/ODBC/JDBC port `1112` | `false` |
| `sql_allowed_cidrs` | CIDRs allowed to reach secure SQL when `expose_sql_endpoint = true` | `[]` |

If you enable public secure SQL exposure, set `sql_allowed_cidrs` to explicit client/admin networks. Examples:

```hcl
sql_allowed_cidrs = ["203.0.113.45/32"]
```

```hcl
sql_allowed_cidrs = ["203.0.113.45/32", "198.51.100.27/32"]
```

Use your current public IP with `/32` for single-user access. Avoid `0.0.0.0/0` unless this is a short-lived test, because it exposes secure SQL to the entire public internet.

**Option B: Use Existing VPC**

```hcl
create_vpc                  = false
existing_vpc_id             = "vpc-0123456789abcdef0"
existing_public_subnet_ids  = ["subnet-aaa", "subnet-bbb"]
existing_private_subnet_ids = ["subnet-ccc", "subnet-ddd"]
```

### Container Sizing

ECS Fargate requires specific CPU/memory pairings:

| CPU (units) | vCPU | Valid Memory (MiB) |
|-------------|------|-------------------|
| 256 | 0.25 | 512, 1024, 2048 |
| 512 | 0.5 | 1024, 2048, 3072, 4096 |
| 1024 | 1 | 2048, 3072, 4096, 5120, 6144, 7168, 8192 |
| 2048 | 2 | 4096 - 16384 (1 GB increments) |
| 4096 | 4 | 8192 - 30720 (1 GB increments) |
| 8192 | 8 | 16384 - 61440 (4 GB increments) |
| 16384 | 16 | 32768 - 122880 (8 GB increments) |

**Recommended configurations:**

| Use Case | `ecs_cpu` | `ecs_memory` | Description |
|----------|-----------|--------------|-------------|
| Development | `512` | `1024` | 0.5 vCPU, 1 GB RAM |
| Small Production | `1024` | `2048` | 1 vCPU, 2 GB RAM |
| Medium Production | `2048` | `4096` | 2 vCPU, 4 GB RAM |
| Large Production | `4096` | `8192` | 4 vCPU, 8 GB RAM |
| Heavy Workloads | `8192` | `16384` | 8 vCPU, 16 GB RAM |

### Other Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `virtuoso_number_of_buffers` | Virtuoso `NumberOfBuffers`; percentage values are resolved against Fargate task memory. | `60%` |
| `virtuoso_max_dirty_buffers` | Virtuoso `MaxDirtyBuffers`; percentage values are resolved against Fargate task memory. | `45%` |
| `efs_throughput_mode` | EFS throughput mode | `bursting` |
| `log_retention_days` | CloudWatch log retention | `7` |


## Backup And Recovery

The AWS deployment creates an encrypted private S3 bucket for durable copies of Virtuoso online backups and an on-demand ECS `backup-sync` task definition. For production, enable the provider-native EventBridge schedule through `deploy.sh` or `enable_backup_sync_schedule = true`.

Run an online backup and sync it to S3 from the `aws/` directory:

```bash
./scripts/backup-online.sh
```

List durable backup copies:

```bash
aws s3 ls "$(tofu output -raw backup_s3_uri)" --human-readable --summarize
```

Stage backup files from S3 back to EFS before a restore:

```bash
./scripts/restore-stage-from-s3.sh
```

See `../docs/SELF_MANAGED_BACKUP_RECOVERY.md` for the full runbook.

Configure daily online backup generation inside Virtuoso. This configures `DB.DBA.SYS_BACKUP_DIRS` and schedules `DB.DBA.BACKUP_MAKE()` so Conductor can show the backup directory and schedule state:

```bash
./scripts/setup-scheduled-backup.sh 1440
```

If post-deploy backup setup does not complete automatically for any reason, rerun the command above manually from the `aws/` directory after the ECS service is up. The script now waits for ECS task readiness before installing the internal Virtuoso backup schedule.

Enable provider-native S3 sync in `terraform.tfvars` for production:

```hcl
enable_backup_sync_schedule     = true
backup_sync_schedule_expression = "rate(1 day)"
```

The local cron installer is retained only as a fallback when EventBridge cannot be used:

```bash
./scripts/install-daily-backup-cron.sh "30 3 * * *"
```

Run a full restore only when you intend to replace the current database:

```bash
./scripts/restore-from-s3.sh --confirm
```

## Deploy.sh Usage

The `deploy.sh` script provides an interactive menu:

```bash
./deploy.sh              # Interactive menu
./deploy.sh --copy-license /path/to/file  # Copy license to running deployment
./deploy.sh --destroy    # Destroy the deployment
./deploy.sh --help       # Show help
```

**Menu Options:**

1. **Interactive Setup** - Configure and deploy with guided prompts
2. **Deploy with current settings** - Deploy using existing `terraform.tfvars`
3. **Copy license file** - Copy license to a running Commercial deployment
4. **Destroy deployment** - Tear down all infrastructure
5. **Exit**

## Operations

### Connect to Container Shell

```bash
# Get current task ID
TASK_ID=$(aws ecs list-tasks \
  --cluster virtuoso-cluster \
  --service-name virtuoso \
  --query 'taskArns[0]' \
  --output text | awk -F/ '{print $NF}')

# Connect via ECS Exec
aws ecs execute-command \
  --cluster virtuoso-cluster \
  --task $TASK_ID \
  --container virtuoso \
  --interactive \
  --command "/bin/bash"
```

### Run ISQL Commands

From inside the container:

```bash
# Connect to Virtuoso over secure SQL
isql localhost:1112 dba $DBA_PASSWORD -E

# Or run a query directly over secure SQL
isql localhost:1112 dba $DBA_PASSWORD -E exec="SELECT 1;"
```

### Check EFS Mount and Database Files

From inside the container:

```bash
# Verify EFS mount
mount | grep nfs4

# List database files (path varies by edition)
# Open Source: /opt/virtuoso-opensource/database/
# Commercial:  /opt/virtuoso/database/
ls -la /database/

# Check disk usage
df -h /database/
```

### Stop/Start Service

Use AWS CLI to stop and start the service. Note that `tofu apply` will always ensure the service is running (desired_count=1).

```bash
# Stop (scale to 0)
aws ecs update-service \
  --cluster virtuoso-cluster \
  --service virtuoso \
  --desired-count 0

# Start (scale to 1)
aws ecs update-service \
  --cluster virtuoso-cluster \
  --service virtuoso \
  --desired-count 1
```

**Note:** The infrastructure is hardcoded to run a single instance. Running `tofu apply` after manually stopping the service will restart it.

### View Logs

```bash
# Via AWS CLI
aws logs tail /ecs/virtuoso --follow

# Or in AWS Console: CloudWatch > Log groups > /ecs/virtuoso
```

## Verify Persistence

To confirm database persistence across restarts:

1. **Make a change** (e.g., change password via Conductor or create data)

2. **Restart the service:**
   ```bash
   # Stop
   aws ecs update-service --cluster virtuoso-cluster --service virtuoso --desired-count 0

   # Wait for task to stop
   aws ecs list-tasks --cluster virtuoso-cluster --service-name virtuoso

   # Start
   aws ecs update-service --cluster virtuoso-cluster --service virtuoso --desired-count 1
   ```

3. **Verify change persisted** after new task starts

## Destroy Infrastructure

```bash
# Via deploy.sh
./deploy.sh --destroy

# Or directly
tofu destroy
```

The secret is configured with `recovery_window_in_days = 0`, so it's immediately deleted without the 30-day pending period. You can redeploy immediately after destroy without conflicts.

## Troubleshooting

### Task Fails to Start - Lock File Issue

**Symptom:** Task fails with "Unable to lock file ../database/virtuoso.lck"

**Cause:** Previous task didn't shut down cleanly, or rolling deployment attempted while another instance is running.

**Solution:** Do a clean stop/start cycle:
```bash
aws ecs update-service --cluster virtuoso-cluster --service virtuoso --desired-count 0
# Wait 30 seconds for task to fully stop
aws ecs update-service --cluster virtuoso-cluster --service virtuoso --desired-count 1
```

### License Not Found (Commercial Edition)

**Symptom:** Log shows "License not found" and "Demo license enabled"

**Cause:** License file not present when Virtuoso starts, or license in wrong location.

**Solution:**
1. Ensure license file is specified in `terraform.tfvars`:
   ```hcl
   virtuoso_license_file = "/path/to/virtuoso.lic"
   ```
2. Copy license and restart:
   ```bash
   ./deploy.sh --copy-license /path/to/virtuoso.lic
   ```
3. Verify license file exists in container:
   ```bash
   # Connect to container and check
   ls -la /opt/virtuoso/database/virtuoso.lic
   ```

### Password Authentication Fails

**Symptom:** Can't login with Secrets Manager password

**Cause:** Password exceeds 20-character limit (Virtuoso Docker image limitation)

**Solution:** This project is pre-configured with 20-character passwords. If you modified `secrets.tf`, ensure `length <= 20`.

### ECS Exec Connection Failed

**Symptom:** `TargetNotConnectedException` when running `execute-command`

**Cause:** SSM agent not ready or IAM permissions missing.

**Solution:** Wait 1-2 minutes after task starts, then retry. The task role includes required SSM permissions.

### EFS Mount Timeout

**Symptom:** Task stuck in PROVISIONING with EFS mount errors

**Cause:** Security group missing NFS port (2049) access.

**Solution:** This project configures the security group correctly. If using existing VPC, ensure security groups allow port 2049 between ECS tasks and EFS mount targets.

## Important Notes

1. **Password Length Limit:** The Virtuoso Docker image has a 20-character limit for `+pwddba` command-line password setting. This project generates 20-character passwords.

2. **Single Instance Only:** This deployment runs exactly one Virtuoso instance. Virtuoso uses file-level locking on the database, so multiple instances cannot share the same EFS storage. Virtuoso clustering requires a different architecture with separate database directories per node.

3. **HTTPS Certificate:** The HTTPS endpoint uses Virtuoso's built-in self-signed SSL certificate. Your browser will show a security warning; this is expected. For production use with custom certificates, configure Virtuoso's SSL settings.

4. **Network Load Balancer:** Uses TCP passthrough (Layer 4), preserving client IP addresses. All three ports (80, 443, 1112) share the same DNS name.

5. **EFS Performance:** Uses "bursting" throughput mode. For high-performance workloads, consider "provisioned" mode.

6. **EFS Encryption:** EFS is encrypted at rest using the AWS-managed `aws/elasticfilesystem` KMS key. The ECS execution role includes KMS permissions to mount encrypted volumes.

7. **Secrets Rotation:** The auto-generated password is created once at deployment. Rotation requires manual intervention.

8. **Database Paths:** The EFS mount location varies by edition:
   - Open Source 7: `/opt/virtuoso-opensource/database`
   - Commercial 8: `/opt/virtuoso/database`

## Outputs

| Output | Description |
|--------|-------------|
| `virtuoso_dns_name` | NLB DNS name (same for all ports) |
| `virtuoso_http_url` | HTTP URL (`http://<virtuoso_dns_name>`) |
| `virtuoso_https_url` | HTTPS URL (`https://<virtuoso_dns_name>`) |
| `virtuoso_sql_endpoint` | SQL endpoint (`<virtuoso_dns_name>:1112`) |
| `ecs_cluster_name` | ECS cluster name |
| `ecs_service_name` | ECS service name |
| `vpc_id` | VPC ID (created or existing) |
| `secret_name` | Secrets Manager secret name for DBA password |
| `secret_arn` | Secrets Manager ARN for DBA password |
| `virtuoso_database_path` | Container path where database is stored |

## License

This OpenTofu/Terraform configuration is provided as-is. Virtuoso is licensed separately by OpenLink Software.
