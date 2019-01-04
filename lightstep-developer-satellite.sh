#!/bin/bash

docker > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "This version of the LightStep Satellite requires docker.  Please install docker before proceeding."
  exit 1
fi

ID=$(docker ps | grep lightstep/collector | head -n 1 | cut -d ' ' -f 1 )
if [ -n "$ID" ]; then
  echo "There is already a lightstep collector running.  You can stop it by"
  echo "running stop-lightstep-collector.sh"
  exit 1
fi

if [ -z "$LIGHTSTEP_API_KEY" ]; then 
  echo "LIGHTSTEP_API_KEY is not set.  You can retrieve an API key from"
  echo "http://app.lightstep.com/<your project>/account"
  echo "Please enter an API key:"
  read -r LIGHTSTEP_API_KEY
  echo "Thank you. In the future you may set LIGHTSTEP_API_KEY to skip this step."
fi

## Set env vars to be passed to docker if not set in current environment.
COLLECTOR_API_KEY="$LIGHTSTEP_API_KEY"
: "${COLLECTOR_POOL:=${USER}_developer_pool}"
# Set default ports
: "${COLLECTOR_BABYSITTER_PORT:=8000}"
: "${COLLECTOR_ADMIN_PLAIN_PORT:=8080}"
: "${COLLECTOR_HTTP_PLAIN_PORT:=8181}"
: "${COLLECTOR_GRPC_PLAIN_PORT:=8282}"
: "${COLLECTOR_PLAIN_PORT:=8383}"
# Default of 100MB
: "${COLLECTOR_REPORTER_BYTES_PER_PROJECT:=100000000}"


# Pull down the latest version of the collector from docker hub
# (Note, this does not happen automatically with docker run)
docker pull lightstep/collector

docker run \
  -d \
  -e COLLECTOR_API_KEY="$COLLECTOR_API_KEY" \
  -e COLLECTOR_POOL="$COLLECTOR_POOL" \
  -e COLLECTOR_BABYSITTER_PORT="$COLLECTOR_BABYSITTER_PORT"  -p "$COLLECTOR_BABYSITTER_PORT":"$COLLECTOR_BABYSITTER_PORT" \
  -e COLLECTOR_ADMIN_PLAIN_PORT="$COLLECTOR_ADMIN_PLAIN_PORT"  -p "$COLLECTOR_ADMIN_PLAIN_PORT":"$COLLECTOR_ADMIN_PLAIN_PORT" \
  -e COLLECTOR_HTTP_PLAIN_PORT="$COLLECTOR_HTTP_PLAIN_PORT"  -p "$COLLECTOR_HTTP_PLAIN_PORT":"$COLLECTOR_HTTP_PLAIN_PORT" \
  -e COLLECTOR_GRPC_PLAIN_PORT="$COLLECTOR_GRPC_PLAIN_PORT"  -p "$COLLECTOR_GRPC_PLAIN_PORT":"$COLLECTOR_GRPC_PLAIN_PORT" \
  -e COLLECTOR_PLAIN_PORT="$COLLECTOR_PLAIN_PORT"  -p "$COLLECTOR_PLAIN_PORT":"$COLLECTOR_PLAIN_PORT" \
  -e COLLECTOR_REPORTER_BYTES_PER_PROJECT="$COLLECTOR_REPORTER_BYTES_PER_PROJECT" \
  --restart always \
  lightstep/collector
