FROM ubuntu:focal

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y systemd-sysv mariadb-server
