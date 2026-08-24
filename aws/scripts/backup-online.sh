#!/usr/bin/env bash
set -euo pipefail

REGION="$(tofu output -raw region 2>/dev/null || true)"
if [ -z "${REGION}" ]; then
  REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required. Install jq and retry." >&2
  exit 1
fi
CLUSTER="$(tofu output -raw ecs_cluster_name)"
SERVICE="$(tofu output -raw ecs_service_name)"
DB_PATH="$(tofu output -raw virtuoso_database_path)"
BACKUP_TASK_DEF="$(tofu output -raw backup_sync_task_definition_arn)"
BACKUP_URI="$(tofu output -raw backup_s3_uri)"
CONTAINER="virtuoso"

PRIVATE_SUBNETS="$(tofu output -json private_subnet_ids | jq -r 'join(",")')"
SECURITY_GROUP="$(tofu output -raw security_group_id)"

TASK_ARN="$(aws ecs list-tasks \
  --region "$REGION" \
  --cluster "$CLUSTER" \
  --service-name "$SERVICE" \
  --desired-status RUNNING \
  --query 'taskArns[0]' \
  --output text)"

if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
  echo "No running ECS task found for service $SERVICE" >&2
  exit 1
fi

INNER_SCRIPT="$(mktemp)"
cat > "$INNER_SCRIPT" <<EOF
set -euo pipefail
DB_PATH="$DB_PATH"
BACKUP_DIR="\$DB_PATH/backup"
BACKUP_PREFIX="virtuoso_"
ISQL="\${VIRTUOSO_HOME:-}/bin/isql"
if [ ! -x "\$ISQL" ]; then ISQL="\$(command -v isql || command -v isql-v || true)"; fi
if [ -z "\$ISQL" ] || [ ! -x "\$ISQL" ]; then echo "Virtuoso isql binary not found"; exit 1; fi
if [ -z "\${DBA_PASSWORD:-}" ]; then echo "DBA_PASSWORD is not available in container environment"; exit 1; fi
mkdir -p "\$BACKUP_DIR"
DB_OWNER="\$(stat -c '%u:%g' "\$DB_PATH" 2>/dev/null || true)"
if [ -n "\$DB_OWNER" ]; then chown "\$DB_OWNER" "\$BACKUP_DIR" 2>/dev/null || true; fi
chmod 775 "\$BACKUP_DIR" 2>/dev/null || true
BACKUP_SQL="
delete from DB.DBA.SYS_BACKUP_DIRS;
insert into DB.DBA.SYS_BACKUP_DIRS (bd_id, bd_dir) values (1, '\$BACKUP_DIR');
DB.DBA.BACKUP_MAKE('virtuoso_', 10000, 1);
"
BACKUP_LOG="/tmp/virtuoso-online-backup.out"
printf "%s\n" "\$BACKUP_SQL" | "\$ISQL" 1111 dba "\$DBA_PASSWORD" 2>&1 | tee "\$BACKUP_LOG"
if grep -Eq '^\\*\\*\\* Error|^Error ' "\$BACKUP_LOG"; then
  echo "Virtuoso online backup failed" >&2
  exit 1
fi
ls -lh "\$BACKUP_DIR" | tail -20
EOF

ENCODED_SCRIPT="$(base64 < "$INNER_SCRIPT" | tr -d '\n')"
rm -f "$INNER_SCRIPT"

echo "Starting Virtuoso online backup in ECS task $TASK_ARN"
aws ecs execute-command \
  --region "$REGION" \
  --cluster "$CLUSTER" \
  --task "$TASK_ARN" \
  --container "$CONTAINER" \
  --interactive \
  --command "/bin/bash -lc 'echo $ENCODED_SCRIPT | base64 -d > /tmp/virtuoso-online-backup.sh && chmod +x /tmp/virtuoso-online-backup.sh && /tmp/virtuoso-online-backup.sh'"

echo "Syncing backup files to $BACKUP_URI"
SYNC_TASK_ARN="$(aws ecs run-task \
  --region "$REGION" \
  --cluster "$CLUSTER" \
  --launch-type FARGATE \
  --task-definition "$BACKUP_TASK_DEF" \
  --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
  --query 'tasks[0].taskArn' \
  --output text)"

if [ -z "$SYNC_TASK_ARN" ] || [ "$SYNC_TASK_ARN" = "None" ]; then
  echo "Failed to start backup sync task" >&2
  exit 1
fi

aws ecs wait tasks-stopped --region "$REGION" --cluster "$CLUSTER" --tasks "$SYNC_TASK_ARN"
EXIT_CODE="$(aws ecs describe-tasks \
  --region "$REGION" \
  --cluster "$CLUSTER" \
  --tasks "$SYNC_TASK_ARN" \
  --query 'tasks[0].containers[0].exitCode' \
  --output text)"

if [ "$EXIT_CODE" != "0" ]; then
  echo "Backup sync task failed with exit code: $EXIT_CODE" >&2
  exit 1
fi

echo "Backup synced to $BACKUP_URI"
