FROM alpine:3.4

LABEL build.publish.majorversion="3.4"
LABEL build.publish.imagebase="alpine"

ENV ENVELOPE_VERSION 0.3.3
ENV LANG en_US.UTF-8

# Install required packages
RUN apk add --no-cache \
    bash \
    curl \
    unzip \
    ca-certificates \
    gnupg \
    && mkdir -p /root/.gnupg \
    && echo "allow-loopback-pinentry" >> /root/.gnupg/gpg-agent.conf \
    && echo "pinentry-mode loopback" >> /root/.gnupg/gpg.conf \
    && curl -s -o /usr/local/share/ca-certificates/full360-root-ca.crt https://s3.amazonaws.com/full360-cloudformation-init/public/full360-root-ca.crt \
    && update-ca-certificates \
    && curl -s -o /tmp/envelope.zip https://releases-full360.s3.amazonaws.com/public/envelope/${ENVELOPE_VERSION}/envelope_${ENVELOPE_VERSION}_linux_amd64.zip \
    && unzip /tmp/envelope.zip -d /usr/local/bin/ \
    && rm /tmp/envelope.zip
