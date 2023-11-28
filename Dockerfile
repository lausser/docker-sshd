FROM alpine:3.18.4
LABEL org.opencontainers.image.authors="Gerhard Lausser"
LABEL description="Run a ssh daemon in a container"

USER root
RUN apk update
RUN apk add --no-cache curl bash openssh cracklib-words
RUN gzip -d /usr/share/cracklib/cracklib-words.gz
WORKDIR /root
ADD run.sh /root
RUN chmod 755 /root/run.sh
ADD VERSION /root
ENTRYPOINT /root/run.sh
