#!/bin/bash

NAME=lightstep_developer_satellite

while true; do
  ID=$(docker ps --all | grep ${NAME} | head -n 1 | cut -d ' ' -f 1 )
  if [ -n "$ID" ]; then
    echo "Removing docker container $ID"
    docker kill "$ID" || true
    docker rm "$ID" || true
  else
    break
  fi
done
