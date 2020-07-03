FROM alpine:3.12

LABEL build.publish.minorversion="0.5"
LABEL build.publish.patchversion="0.5.6"
LABEL build.publish.imagebase="alpine"

ENV NOMAD_VERSION 0.5.6
ENV NOMAD_SHA256 3f5210f0bcddf04e2cc04b14a866df1614b71028863fe17bcdc8585488f8cb0c
ENV NOMAD_ADDR http://nomad.service.qantas-loyalty-sydney.soa.ebi:4646

# Install required packages
RUN set -ex && \
    apk add --no-cache \
    ca-certificates \
    make \
    bash \
    openssl \
    git \
    unzip \
    && update-ca-certificates \
    && wget -O nomad.zip "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip" \
    && echo "${NOMAD_SHA256} *nomad.zip" | sha256sum -c - \
    && unzip nomad.zip -d /usr/local/bin/ \
    && rm nomad.zip \
    && wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub \
    && wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.29-r0/glibc-2.29-r0.apk \
    && apk add glibc-2.29-r0.apk

COPY nomad-helper.sh environment.sh /usr/local/bin/
