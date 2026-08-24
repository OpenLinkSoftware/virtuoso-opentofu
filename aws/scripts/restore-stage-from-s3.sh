#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required. Install jq and retry." >&2
  exit 1
fi
CLUSTER="$(tofu output -raw ecs_cluster_name)"
BACKUP_TASK_DEF="$(tofu output -raw backup_sync_task_definition_arn)"
BACKUP_URI="${1:-$(tofu output -raw backup_s3_uri)}"
DB_PATH="$(tofu output -raw virtuoso_database_path)"
PRIVATE_SUBNETS="$(tofu output -json private_subnet_ids | jq -r 'join(",")')"
SECURITY_GROUP="$(tofu output -raw security_group_id)"

echo "Staging backup files from $BACKUP_URI to $DB_PATH/backup"
SYNC_TASK_ARN="$(aws ecs run-task \
  --region "$REGION" \
  --cluster "$CLUSTER" \
  --launch-type FARGATE \
  --task-definition "$BACKUP_TASK_DEF" \
  --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
  --overrides "{\"containerOverrides\":[{\"name\":\"backup-sync\",\"command\":[\"s3\",\"sync\",\"$BACKUP_URI\",\"$DB_PATH/backup/\"]}]}" \
  --query 'tasks[0].taskArn' \
  --output text)"

aws ecs wait tasks-stopped --region "$REGION" --cluster "$CLUSTER" --tasks "$SYNC_TASK_ARN"
EXIT_CODE="$(aws ecs describe-tasks \
  --region "$REGION" \
  --cluster "$CLUSTER" \
  --tasks "$SYNC_TASK_ARN" \
  --query 'tasks[0].containers[0].exitCode' \
  --output text)"

if [ "$EXIT_CODE" != "0" ]; then
  echo "Restore staging sync task failed with exit code: $EXIT_CODE" >&2
  exit 1
fi

cat <<EOF
Backup files are staged under $DB_PATH/backup in EFS.
Stop Virtuoso before performing a full database restore, then follow the Virtuoso backup recovery procedure for the staged .bp files.
EOF
