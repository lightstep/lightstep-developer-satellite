#!/bin/bash

IMAGE=lightstep/developer-satellite
IMAGE_VERSION=${IMAGE}:latest

docker > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "This version of the LightStep Satellite requires docker.  Please install docker before proceeding."
  exit 1
fi

ID=$(docker ps | grep ${IMAGE} | head -n 1 | cut -d ' ' -f 1 )
if [ -n "$ID" ]; then
  echo "There is already a lightstep collector running.  You can stop it by"
  echo "running stop-lightstep-collector.sh"
  exit 1
fi

if [ -z "$LIGHTSTEP_USER" ]; then 
  echo "LIGHTSTEP_USER is not set.  This is the e-mail address you use for sign-in."
  echo "Please enter your user name:"
  read -r LIGHTSTEP_USER
  echo "Thank you. In the future you may set LIGHTSTEP_USER to skip this step."
fi

if [ -z "$LIGHTSTEP_PROJECT" ]; then 
  echo "LIGHTSTEP_PROJECT is not set.  This is the e-mail address you use for sign-in."
  echo "Please enter your user name:"
  read -r LIGHTSTEP_PROJECT
  echo "Thank you. In the future you may set LIGHTSTEP_PROJECT to skip this step."
fi

if [ -z "$LIGHTSTEP_API_KEY" ]; then 
  echo "LIGHTSTEP_API_KEY is not set.  You can retrieve an API key from"
  echo "http://app.lightstep.com/${LIGHTSTEP_PROJECT}/developer-mode"
  echo "Please enter an API key:"
  read -r LIGHTSTEP_API_KEY
  echo "Thank you. In the future you may set LIGHTSTEP_API_KEY to skip this step."
fi

## Set env vars to be passed to docker if not set in current environment.
COLLECTOR_API_KEY="${LIGHTSTEP_API_KEY}"
# Developer-mode specifics
: "${COLLECTOR_POOL:=${LIGHTSTEP_USER}_${LIGHTSTEP_PROJECT}_developer}"
: "${COLLECTOR_PROJECT_NAME:=${LIGHTSTEP_PROJECT}}"
: "${COLLECTOR_INGESTION_TAGS:=lightstep.developer:${LIGHTSTEP_USER}}"
: "${COLLECTOR_DISABLE_ACCESS_TOKEN_CHECKING:=true}"
# Set default ports
: "${COLLECTOR_GRPC_PLAIN_PORT:=8360}"
: "${COLLECTOR_ADMIN_PLAIN_PORT:=8361}"
# Disable unused ports
: "${COLLECTOR_HTTP_PLAIN_PORT:=0}"
: "${COLLECTOR_PLAIN_PORT:=0}"
: "${COLLECTOR_BABYSITTER_PORT:=0}"
: "${COLLECTOR_ADMIN_SECURE_PORT:=0}"
# Default of 100MB
: "${COLLECTOR_REPORTER_BYTES_PER_PROJECT:=100000000}"


# Pull down the latest version of the collector from docker hub
# (Note, this does not happen automatically with docker run)
docker pull ${IMAGE_VERSION}


function map_port {
    local port=$1
    if [[ "$port" = "0" ]]; then
        echo
    else
        echo "-p" "$port:$port"
    fi
}

VARS="
 COLLECTOR_ADMIN_PLAIN_PORT
 COLLECTOR_ADMIN_SECURE_PORT
 COLLECTOR_API_KEY 
 COLLECTOR_BABYSITTER_PORT
 COLLECTOR_DISABLE_ACCESS_TOKEN_CHECKING
 COLLECTOR_GRPC_PLAIN_PORT
 COLLECTOR_HTTP_PLAIN_PORT
 COLLECTOR_INGESTION_TAGS
 COLLECTOR_LIGHTSTEP_COLLECTOR_HOST
 COLLECTOR_LIGHTSTEP_COLLECTOR_PLAINTEXT
 COLLECTOR_LIGHTSTEP_COLLECTOR_PORT
 COLLECTOR_LIGHTSTEP_USE_HTTP
 COLLECTOR_LIGHTSTEP_VERBOSE
 COLLECTOR_LOGGING_STDERR_CONFIG_ENABLED
 COLLECTOR_PLAIN_PORT 
 COLLECTOR_POOL 
 COLLECTOR_PROJECT_NAME
 COLLECTOR_RAINBOW_GRPC_HOST
 COLLECTOR_RAINBOW_GRPC_PLAINTEXT
 COLLECTOR_RAINBOW_GRPC_PORT
 COLLECTOR_REPORTER_BYTES_PER_PROJECT
"

DARGS=""

for var in ${VARS}; do
    DARGS=${DARGS}" -e "${var}=${!var}
done

PARGS="
 $(map_port $COLLECTOR_ADMIN_PLAIN_PORT)
 $(map_port $COLLECTOR_ADMIN_SECURE_PORT)
 $(map_port $COLLECTOR_BABYSITTER_PORT)
 $(map_port $COLLECTOR_GRPC_PLAIN_PORT)
 $(map_port $COLLECTOR_HTTP_PLAIN_PORT)
 $(map_port $COLLECTOR_PLAIN_PORT)
"

container=lightstep_developer_satellite

docker kill ${container} 2> /dev/null
docker rm ${container} 2> /dev/null

docker run -d ${DARGS} ${PARGS} --name ${container} --restart always ${IMAGE}
