#!/usr/bin/env bash

set -e

usage() {
  echo "Usage: $0 [ -d docker-compose file path] [ -e ecs-params file path ] [ -s flag to stop the application (only valid value is YES) ]" 1>&2
}

exit_abnormal() {
  usage
  exit 1
}

while getopts d:e:s: option
do
  case "${option}"
    in
    d) DOCKER_OPTION=${OPTARG};;
    e) ECS_PARAMS_OPTION=${OPTARG};;
    s) STOP_SERVICE=${OPTARG}
      if [[ $STOP_SERVICE != "YES" ]]; then
        exit_abnormal
        fi;;
      :) exit_abnormal;;
      *) exit_abnormal;;
    esac
  done

  DOCKER_COMPOSE_PATH=${DOCKER_OPTION:-./docker-compose.yml}
  ECS_PARAMS_PATH=${ECS_PARAMS_OPTION:-./ecs-params.yml}

  echo "using $DOCKER_COMPOSE_PATH compose file"
  echo "using $ECS_PARAMS_PATH ecs params file"

  load_variables (){
    echo "Loading variables"
    if [[ -z "${ENV}" ]];          then echo "missing ENV";          exit_abnormal; fi
    if [[ -z "${SERVICE_NAME}" ]]; then echo "missing SERVICE_NAME"; exit_abnormal; fi
    if [[ -z "${REVISION}" ]];     then echo "missing REVISION";     exit_abnormal; fi
    if [[ -z "${CLIENT}" ]];       then echo "missing CLIENT";     exit_abnormal; fi
    export TYPE=${TYPE:-SERVICE}
    if [ $TYPE == "SERVICE" ]; then
      if [[ -z "${SERVICE_PORT}" ]]; then echo "missing SERVICE_PORT"; exit_abnormal; fi
      export SCHEDULE=${SCHEDULE:-"cron(0 0 * * ? *)"}
      export SERVICE_COUNT=${SERVICE_COUNT:-2}
      VISIBILITY=${VISIBILITY:-"PUBLIC"}
    else
      if [[ -z "${SCHEDULE}" ]]; then echo "missing SCHEDULE"; exit_abnormal; fi
      export SERVICE_COUNT=${SERVICE_COUNT:-1}
    fi
    export REGION=${REGION:-"ap-southeast-2"}
    export AWS_DEFAULT_REGION=$REGION
    export APP_NAME=$ENV"-"$SERVICE_NAME
    export HEALTH_CHECK_GRACE_PERIOD=${HEALTH_CHECK_GRACE_PERIOD:-180}
    export HEALTH_CHECK_PATH=${HEALTH_CHECK_PATH:-/$SERVICE_NAME/health}
    export VPC_ID=$(get_param_from_ssm "/$ENV/$CLIENT/vpc_id")
    export VPC_NAME=$(aws ec2 describe-vpcs \
      --vpc-ids ${VPC_ID} \
      | jq -cr '.Vpcs[].Tags[] | select(.Key=="Name") | .Value'
    )
    export SUBNET_TYPE=${SUBNET_TYPE:-private}
    export SUBNET_NAME=${SUBNET_NAME:-${VPC_NAME}-${SUBNET_TYPE}*}
    export SUBNET_IDS=$(aws ec2 describe-subnets \
      --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Name,Values=${SUBNET_NAME}" \
      | jq -cr '[.Subnets[].SubnetId] | join(",")'
    )
    export SECURITY_GROUP=$(get_param_from_ssm "/$ENV/$CLIENT/orchestrator/$CLUSTER_NAME/security_group")
    export EXECUTION_ROLE_ARN=$(get_param_from_ssm "/$ENV/$CLIENT/orchestrator/$CLUSTER_NAME/execution_role_arn")
    export LISTENER_ARN=$(get_param_from_ssm "/$ENV/$CLIENT/orchestrator/$CLUSTER_NAME/listener_arn")
    export DNS_NAMESPACE_ID=$(get_param_from_ssm "/$ENV/$CLIENT/service_discovery/dns_namespace_id")
    export CLUSTER_NAME=$(get_param_from_ssm "/$ENV/$CLIENT/orchestrator/$CLUSTER_NAME")
    echo "Running pipeline for $REVISION"
    echo "Variables loaded"
  }

get_param_from_ssm() {
  echo $(aws ssm get-parameter \
    --name $1 \
    --with-decryption \
    | jq -cr '.Parameter.Value'
  )
}

delete_load_balancer(){
  echo $1
  local currentTGARN=$(echo $1 | jq -r -c '. | select(.TargetGroupName =="'$APP_NAME'") | .TargetGroupArn')
  echo "currentTGARN $currentTGARN"
  local currentRuleARN=$(aws elbv2 describe-rules --listener-arn $LISTENER_ARN | jq -r -c '.Rules[] | select(.Actions[].TargetGroupArn=="'$currentTGARN'") | .RuleArn')
  echo "currentRuleARN $currentRuleARN"
  aws elbv2 delete-rule --rule-arn $currentRuleARN
  aws elbv2 delete-target-group --target-group-arn $currentTGARN
}

create_load_balancer(){
  echo "Creating load balancer resources..."
  echo "Checking if tagrget group exists"

  local tgDetails=$(aws elbv2 describe-target-groups | jq -c '.TargetGroups[] | select(.TargetGroupName =="'$APP_NAME'")')
  if [ $(echo $tgDetails | jq -c -r '. | select(.TargetGroupName =="'$APP_NAME'")|  select (.Port!='$SERVICE_PORT')' | wc -l) -ge 1 ]; then
    echo "A target group named $APP_NAME with port $SERVICE_PORT exists, deleting..."
    delete_load_balancer $tgDetails
    echo "Existing target group deleted"
  fi

  local tgDetails=$(aws elbv2 describe-target-groups | jq -c '.TargetGroups[] | select(.TargetGroupName =="'$APP_NAME'")')
  if [ $(echo $tgDetails | jq -c -r '. | select(.TargetGroupName =="'$APP_NAME'")' | wc -l) -eq 0 ]; then
    echo "target group $APP_NAME doesn't exists, creating..."
    local tgCreated=$(aws elbv2 create-target-group \
      --name $APP_NAME \
      --protocol HTTP \
      --port $SERVICE_PORT \
      --vpc-id $VPC_ID \
      --health-check-path $HEALTH_CHECK_PATH \
      --matcher HttpCode=200 \
      --target-type ip)

    export TG_ARN=$(echo $tgCreated | jq -r '.TargetGroups[].TargetGroupArn')
    local currentMaxRulePriority=$(aws elbv2 describe-rules --listener-arn $LISTENER_ARN | jq -r -c '[.Rules[] | select (.Priority != "default")] | max_by(.Priority | tonumber) | .Priority')
    local newMaxRulePriority=$(($currentMaxRulePriority+1))

    aws elbv2 create-rule \
      --listener-arn $LISTENER_ARN \
      --priority $newMaxRulePriority \
      --conditions Field=path-pattern,Values='/'"$SERVICE_NAME"'/*' \
      --actions Type=forward,TargetGroupArn=$TG_ARN

    echo "Finished creating load balancer resources"
  else
    echo "target group $APP_NAME already exists"
    export TG_ARN=$(echo $tgDetails | jq -r -c '. | select(.TargetGroupName =="'$APP_NAME'") | .TargetGroupArn')
    echo " TARGET_GROUP_ARN $TG_ARN "
  fi
}

load_variables

# Configure defaults
ecs-cli configure --cluster $CLUSTER_NAME --region $REGION --config-name default

if [ "$STOP_SERVICE" == "YES" ]; then
  echo "Starting process to delete service $SERVICE_NAME..."
  tgDetails=$(aws elbv2 describe-target-groups | jq -c '.TargetGroups[] | select(.TargetGroupName =="'$APP_NAME'")')

  if [ $(echo $tgDetails | jq -c -r '. | select(.TargetGroupName =="'$APP_NAME'")' | wc -l) -ge 1 ]; then
    echo "Deleting load balancer resources..."
    delete_load_balancer $tgDetails
    echo "Load balancer resources deleted"
  fi

  echo "Deleting service..."
  ecs-cli compose --project-name $APP_NAME --ecs-params $ECS_PARAMS_PATH --file $DOCKER_COMPOSE_PATH service delete
  echo "Service deleted"
  exit 0
fi

if [ $TYPE == "SERVICE" ]; then
  if [ $VISIBILITY == "PUBLIC" ]; then
    create_load_balancer
  fi

  aws ecs list-services --cluster $CLUSTER_NAME --launch-type FARGATE
  if [ $( aws ecs list-services --cluster $CLUSTER_NAME --launch-type FARGATE | grep $APP_NAME\" -c ) -gt 0 ];then
    echo "Service already running, updating..."
    if [ $VISIBILITY == "PUBLIC" ]; then
      echo "Public service"
      ecs-cli compose \
        --project-name $APP_NAME \
        --file $DOCKER_COMPOSE_PATH \
        --ecs-params $ECS_PARAMS_PATH \
        service up \
        --launch-type FARGATE \
        --target-group-arn $TG_ARN \
        --container-name $SERVICE_NAME \
        --container-port $SERVICE_PORT \
        --health-check-grace-period ${HEALTH_CHECK_GRACE_PERIOD} \
        --timeout 10
    else
      echo "Private service"
      ecs-cli compose \
        --project-name $APP_NAME \
        --file $DOCKER_COMPOSE_PATH \
        --ecs-params $ECS_PARAMS_PATH \
        service up \
        --launch-type FARGATE \
        --timeout 10
    fi

    currentInstancesCount=$(($(ecs-cli compose --project-name $APP_NAME --ecs-params $ECS_PARAMS_PATH --file $DOCKER_COMPOSE_PATH service list --desired-status RUNNING | wc -l)-1))
    if [ $(echo $currentInstancesCount) -ne $SERVICE_COUNT ];then
      echo "current instances count $currentInstancesCount... scaling to $SERVICE_COUNT"
      ecs-cli compose \
        --project-name $APP_NAME \
        --ecs-params $ECS_PARAMS_PATH \
        --file $DOCKER_COMPOSE_PATH \
        service scale $SERVICE_COUNT
    fi
  else
    echo "Service not found, creating..."
    echo "Starting service..."
    echo "$SERVICE_NAME"
    if [ $VISIBILITY == "PUBLIC" ]; then
      echo "Public service"
      ecs-cli compose \
        --project-name $APP_NAME \
        --verbose \
        --ecs-params $ECS_PARAMS_PATH \
        --file $DOCKER_COMPOSE_PATH \
        service up \
        --launch-type FARGATE \
        --enable-service-discovery \
        --target-group-arn $TG_ARN \
        --container-name $SERVICE_NAME \
        --container-port $SERVICE_PORT \
        --create-log-groups \
        --health-check-grace-period ${HEALTH_CHECK_GRACE_PERIOD} \
        --timeout 10
    else
      echo "Private service"
      ecs-cli compose \
        --project-name $APP_NAME \
        --verbose \
        --ecs-params $ECS_PARAMS_PATH \
        --file $DOCKER_COMPOSE_PATH \
        service up \
        --launch-type FARGATE \
        --create-log-groups \
        --timeout 10
    fi

    if [ $(echo $SERVICE_COUNT) -gt 1 ];then
      echo "scaling to $SERVICE_COUNT"
      ecs-cli compose \
        --project-name $APP_NAME \
        --ecs-params $ECS_PARAMS_PATH \
        --file $DOCKER_COMPOSE_PATH \
        service scale $SERVICE_COUNT \
        --timeout 10
    fi

    echo "Finished $APP_NAME service creation"
  fi
else
  echo "Creating batch job..."
  echo "schedule $SCHEDULE"
  ecs-cli compose \
    --project-name $APP_NAME \
    --ecs-params $ECS_PARAMS_PATH \
    --file $DOCKER_COMPOSE_PATH \
    create \
    --create-log-groups \
    --launch-type FARGATE

  taskDefinitionARN=$(aws ecs describe-task-definition --task-definition $APP_NAME | jq -r '.taskDefinition.taskDefinitionArn')
  clusterARN=$(aws ecs describe-clusters --cluster $CLUSTER_NAME | jq -r '.clusters[].clusterArn')

  aws events put-rule --schedule-expression "$SCHEDULE" --name $APP_NAME
  aws events put-targets --rule $APP_NAME \
    --targets "Id"="1","Arn"="$clusterARN","RoleArn"="$EXECUTION_ROLE_ARN","EcsParameters"="{"TaskDefinitionArn"= "$taskDefinitionARN","TaskCount"= $SERVICE_COUNT,"LaunchType"= "FARGATE","NetworkConfiguration"="{"awsvpcConfiguration"="{"Subnets"=[$SUBNET_IDS],"SecurityGroups"=[$SECURITY_GROUP],"AssignPublicIp"="ENABLED"}"}"}"
  echo "Batch job created"
fi
