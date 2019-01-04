#!/bin/bash

while true; do
  ID=$(docker ps | grep lightstep/collector | head -n 1 | cut -d ' ' -f 1 )
  if [ -n "$ID" ]; then
    echo "Removing docker container $ID"
    docker kill "$ID"
    docker rm "$ID"
  else
    break
  fi
done
