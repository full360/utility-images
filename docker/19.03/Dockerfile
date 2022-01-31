FROM docker:19.03

LABEL build.publish.majorversion="19.03"
LABEL build.publish.imagebase="docker"

# Install required packages
RUN apk add --no-cache \
    make \
    git \
    wget \
    curl \
    bash \
    tar \
    aws-cli
