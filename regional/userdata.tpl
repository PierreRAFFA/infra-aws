#!/bin/bash

cat <<'EOF' >> /etc/ecs/ecs.config
ECS_CLUSTER=${cluster_name}
ECS_ENABLE_TASK_IAM_ROLE=true
ECS_CONTAINER_INSTANCE_TAGS={"environment": "${environment}"}
EOF