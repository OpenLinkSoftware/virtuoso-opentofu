#!/usr/bin/env bash
set -euo pipefail

INTERVAL_MINUTES="${1:-1440}"
EVENT_NAME="${EVENT_NAME:-OpenLink-Virtuoso-Online-Backup}"
REGION="$(tofu output -raw region 2>/dev/null || true)"
if [ -z "$REGION" ]; then REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"; fi
CLUSTER="$(tofu output -raw ecs_cluster_name)"
SERVICE="$(tofu output -raw ecs_service_name)"
DB_PATH="$(tofu output -raw virtuoso_database_path)"
CONTAINER="virtuoso"

echo "Waiting for a running ECS task for service $SERVICE..."
aws ecs wait services-stable --region "$REGION" --cluster "$CLUSTER" --services "$SERVICE"
TASK_ARN=""
for attempt in $(seq 1 12); do
  TASK_ARN="$(aws ecs list-tasks --region "$REGION" --cluster "$CLUSTER" --service-name "$SERVICE" --desired-status RUNNING --query 'taskArns[0]' --output text)"
  if [ -n "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
    break
  fi
  echo "No running task yet (attempt $attempt/12); retrying in 10 seconds..."
  sleep 10
done
if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" = "None" ]; then
  echo "No running ECS task found for service $SERVICE after waiting for service stability" >&2
  exit 1
fi

INNER_SCRIPT="$(mktemp)"
cat > "$INNER_SCRIPT" <<'EOF'
set -euo pipefail
EVENT_NAME="__EVENT_NAME__"
INTERVAL_MINUTES="__INTERVAL_MINUTES__"
DB_PATH="__DB_PATH__"
BACKUP_DIR="$DB_PATH/backup"
ISQL="${VIRTUOSO_HOME:-}/bin/isql"
if [ ! -x "$ISQL" ]; then ISQL="$(command -v isql || command -v isql-v || true)"; fi
if [ -z "$ISQL" ] || [ ! -x "$ISQL" ]; then echo "Virtuoso isql binary not found"; exit 1; fi
if [ -z "${DBA_PASSWORD:-}" ]; then echo "DBA_PASSWORD is not available in container environment"; exit 1; fi
mkdir -p "$BACKUP_DIR"
DB_OWNER="$(stat -c '%u:%g' "$DB_PATH" 2>/dev/null || true)"
if [ -n "$DB_OWNER" ]; then chown "$DB_OWNER" "$BACKUP_DIR" 2>/dev/null || true; fi
chmod 775 "$BACKUP_DIR" 2>/dev/null || true
SQL="delete from DB.DBA.SYS_BACKUP_DIRS;
insert into DB.DBA.SYS_BACKUP_DIRS (bd_id, bd_dir) values (1, '$BACKUP_DIR');
delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = '$EVENT_NAME';
delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = DB.DBA.BACKUP_SCHED_NAME();
insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_INTERVAL, SE_SQL) values (DB.DBA.BACKUP_SCHED_NAME(), dateadd('minute', 5, now()), $INTERVAL_MINUTES, 'backup_online (''virtuoso_#'', 10000, 0, vector (''$BACKUP_DIR''))');
select * from DB.DBA.SYS_BACKUP_DIRS;
select SE_NAME, SE_START, SE_SQL, SE_INTERVAL, SE_DISABLED from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = DB.DBA.BACKUP_SCHED_NAME();"
printf "%s\n" "$SQL" | "$ISQL" 1112 dba "$DBA_PASSWORD" -E
EOF
sed -i.bak "s#__EVENT_NAME__#$EVENT_NAME#g; s#__INTERVAL_MINUTES__#$INTERVAL_MINUTES#g; s#__DB_PATH__#$DB_PATH#g" "$INNER_SCRIPT"
rm -f "$INNER_SCRIPT.bak"
ENCODED_SCRIPT="$(base64 < "$INNER_SCRIPT" | tr -d '\n')"
rm -f "$INNER_SCRIPT"

aws ecs execute-command \
  --region "$REGION" \
  --cluster "$CLUSTER" \
  --task "$TASK_ARN" \
  --container "$CONTAINER" \
  --interactive \
  --command "/bin/bash -lc 'echo $ENCODED_SCRIPT | base64 -d > /tmp/setup-scheduled-backup.sh && chmod +x /tmp/setup-scheduled-backup.sh && /tmp/setup-scheduled-backup.sh'"
