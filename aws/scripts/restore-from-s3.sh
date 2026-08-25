#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" != "--confirm" ]; then
  cat >&2 <<'EOF'
Refusing to run destructive restore without explicit confirmation.

This workflow scales the ECS service to zero, stages backup files from S3 into EFS,
runs a temporary restore task against the EFS database volume, and scales the
normal service back to one task after a successful restore.

Usage:
  ./scripts/restore-from-s3.sh --confirm [s3-uri]

Example:
  ./scripts/restore-from-s3.sh --confirm s3://bucket/online/
EOF
  exit 2
fi
shift

REGION="$(tofu output -raw region 2>/dev/null || true)"
if [ -z "$REGION" ]; then REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"; fi
if ! command -v jq >/dev/null 2>&1; then echo "jq is required. Install jq and retry." >&2; exit 1; fi
CLUSTER="$(tofu output -raw ecs_cluster_name)"
SERVICE="$(tofu output -raw ecs_service_name)"
RESTORE_TASK_DEF="$(tofu output -raw restore_task_definition_arn)"
BACKUP_URI="${1:-$(tofu output -raw backup_s3_uri)}"
PRIVATE_SUBNETS="$(tofu output -json private_subnet_ids | jq -r 'join(",")')"
SECURITY_GROUP="$(tofu output -raw security_group_id)"

echo "Scaling ECS service $SERVICE to zero"
aws ecs update-service --region "$REGION" --cluster "$CLUSTER" --service "$SERVICE" --desired-count 0 --output text >/dev/null
aws ecs wait services-stable --region "$REGION" --cluster "$CLUSTER" --services "$SERVICE"

"$(dirname "$0")/restore-stage-from-s3.sh" "$BACKUP_URI"

echo "Running restore task $RESTORE_TASK_DEF"
RESTORE_TASK_ARN="$(aws ecs run-task \
  --region "$REGION" \
  --cluster "$CLUSTER" \
  --launch-type FARGATE \
  --task-definition "$RESTORE_TASK_DEF" \
  --network-configuration "awsvpcConfiguration={subnets=[$PRIVATE_SUBNETS],securityGroups=[$SECURITY_GROUP],assignPublicIp=DISABLED}" \
  --query 'tasks[0].taskArn' \
  --output text)"

if [ -z "$RESTORE_TASK_ARN" ] || [ "$RESTORE_TASK_ARN" = "None" ]; then
  echo "Failed to start restore task. Leaving service scaled to zero for inspection." >&2
  exit 1
fi

aws ecs wait tasks-stopped --region "$REGION" --cluster "$CLUSTER" --tasks "$RESTORE_TASK_ARN"
EXIT_CODE="$(aws ecs describe-tasks --region "$REGION" --cluster "$CLUSTER" --tasks "$RESTORE_TASK_ARN" --query 'tasks[0].containers[0].exitCode' --output text)"
if [ "$EXIT_CODE" != "0" ]; then
  echo "Restore task failed with exit code $EXIT_CODE. Leaving service scaled to zero for inspection." >&2
  exit 1
fi

echo "Restore completed successfully. Scaling ECS service $SERVICE back to one task"
aws ecs update-service --region "$REGION" --cluster "$CLUSTER" --service "$SERVICE" --desired-count 1 --output text >/dev/null
aws ecs wait services-stable --region "$REGION" --cluster "$CLUSTER" --services "$SERVICE"
