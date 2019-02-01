#!/bin/bash

IMAGE=lightstep/developer-satellite

while true; do
  ID=$(docker ps | grep ${IMAGE} | head -n 1 | cut -d ' ' -f 1 )
  if [ -n "$ID" ]; then
    echo "Removing docker container $ID"
    docker kill "$ID"
    docker rm "$ID"
  else
    break
  fi
done
