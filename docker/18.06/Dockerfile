FROM docker:18.06.3-ce 

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
