FROM alpine:3.17.5

RUN apk add --no-cache \
  bash \
  curl \
  jq \
  perl-utils

COPY health.sh ./

RUN chmod a+x ./health.sh
