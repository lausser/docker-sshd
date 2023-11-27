FROM alpine:3.18.4
LABEL org.opencontainers.image.authors="Gerhard Lausser"
LABEL description="Run a ssh daemon in a container"

USER root
RUN apk update
RUN apk add --no-cache curl
RUN mkdir -p /git-hashes
WORKDIR /root
ENTRYPOINT ["/root/run.py"]
ADD run.sh /root
RUN chmod 755 /root/run.sh
ADD VERSION /root
ENTRYPOINT /root/run.sh
