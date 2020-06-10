FROM docker:18.06.3-ce

LABEL build.publish.majorversion="18.06.3-ce"
LABEL build.publish.imagebase="docker"

ENV AWS_DEFAULT_REGION ap-southeast-2
ENV AWS_REGION ap-southeast-2

# Install required packages
RUN apk add --no-cache \
    make \
    git \
    wget \
    curl \
    bash \
    groff \
    less \
    python \
    py-pip \
    && pip install awscli
