FROM alpine:3.12

LABEL build.publish.minorversion="1.19"
LABEL build.publish.patchversion="1.19.1"
LABEL build.publish.imagebase="alpine"

ENV ECS_CLI_VERSION v1.20.0

RUN apk add --no-cache \
  make \
  curl \
  wget \
  docker \
  docker-compose \
  git \
  jq \
  bash \
  aws-cli \
  && curl -fsSL https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-${ECS_CLI_VERSION} \
    -o /usr/local/bin/ecs-cli \
  && chmod 755 /usr/local/bin/ecs-cli

COPY deploy_script.sh environment.sh /usr/local/bin/
