FROM alpine:3.11

LABEL build.publish.minorversion="1.15"
LABEL build.publish.patchversion="1.15.1"
LABEL build.publish.imagebase="alpine"

RUN apk add --no-cache curl docker docker-compose git jq wget groff less python py-pip make bash \
  && pip install awscli \
  && apk --purge -v del py-pip \
  && curl -o /usr/local/bin/ecs-cli https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-latest \
  && chmod 777 /usr/local/bin/ecs-cli

COPY deploy_script.sh environment.sh /usr/local/bin/
