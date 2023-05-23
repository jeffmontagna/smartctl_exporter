FROM alpine:3
ARG BIN_DIR
LABEL maintainer="The Prometheus Authors <prometheus-developers@googlegroups.com>"

RUN apk add smartmontools

COPY ${BIN_DIR}/smartctl_exporter /bin/smartctl_exporter
EXPOSE      9633
USER        nobody
ENTRYPOINT  [ "/bin/smartctl_exporter" ]
