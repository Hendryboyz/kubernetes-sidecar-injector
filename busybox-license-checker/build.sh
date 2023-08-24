#!/bin/bash
USERNAME=hendryboyz
docker build -t $USERNAME/busybox-license-checker:latest . || exit 1
docker push $USERNAME/busybox-license-checker:latest