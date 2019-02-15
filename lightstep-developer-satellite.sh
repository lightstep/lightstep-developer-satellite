#!/bin/bash

# This script should be called with these variables set:
#   LIGHTSTEP_API_KEY
#   LIGHTSTEP_USER
#   LIGHTSTEP_PROJECT

IMAGE=lightstep/developer-satellite
IMAGE_VERSION=${IMAGE}:latest

docker > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "This version of the LightStep Satellite requires docker.  Please install docker before proceeding."
  exit 1
fi

ID=$(docker ps --all | grep "${IMAGE}" | head -n 1 | cut -d ' ' -f 1 )
if [ -n "$ID" ]; then
  echo "There is already a lightstep collector running.  You can stop it by running:"
  echo '  bash -c "$(curl -L https://raw.githubusercontent.com/lightstep/lightstep-developer-satellite/master/stop-developer-satellite.sh)"'

  ## Temporary fix for broken Makefile.
  exit 0
fi

if [ -z "$LIGHTSTEP_USER" ]; then 
  echo "LIGHTSTEP_USER is not set.  This is the e-mail address you use for sign-in."
  echo "Please enter your user name:"
  read -r LIGHTSTEP_USER
  echo "Thank you. In the future you may set LIGHTSTEP_USER to skip this step."
fi

if [ -z "$LIGHTSTEP_PROJECT" ]; then 
  echo "LIGHTSTEP_PROJECT is not set.  This is the name of your project on LightStep."
  echo "Please enter your project name:"
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

# For certain configuration parameters, we want to set defaults if
# they haven't been set in the environment.  Only the
# COLLECTOR_API_KEY is set unconditionally here.  All the other
# COLLECTOR_* environment variables will override the values derived
# here, including those derived from the LIGHTSTEP_* argument
# variables.

COLLECTOR_API_KEY="${LIGHTSTEP_API_KEY}"
# Developer-mode specifics
: "${COLLECTOR_POOL:=${LIGHTSTEP_USER}_${LIGHTSTEP_PROJECT}_developer}"
: "${COLLECTOR_PROJECT_NAME:=${LIGHTSTEP_PROJECT}}"
: "${COLLECTOR_INGESTION_TAGS:=lightstep.developer:${LIGHTSTEP_USER}}"
: "${COLLECTOR_DISABLE_ACCESS_TOKEN_CHECKING:=true}"
# Set default ports
: "${COLLECTOR_HTTP_PLAIN_PORT:=8360}"
: "${COLLECTOR_ADMIN_PLAIN_PORT:=8361}"
# Disable unused ports
: "${COLLECTOR_GRPC_PLAIN_PORT:=0}"
: "${COLLECTOR_PLAIN_PORT:=0}"
: "${COLLECTOR_BABYSITTER_PORT:=0}"
: "${COLLECTOR_ADMIN_SECURE_PORT:=0}"
# Default of 100MB
: "${COLLECTOR_REPORTER_BYTES_PER_PROJECT:=100000000}"
# Allow 16MB reports
: "${COLLECTOR_GRPC_MAX_MSG_SIZE_BYTES:=16777216}"

# Pull down the latest version of the collector from docker hub
# (Note, this does not happen automatically with docker run)
docker pull ${IMAGE_VERSION}

# These variables will pass through to the docker environment.
VARS="
 COLLECTOR_ADMIN_PLAIN_PORT
 COLLECTOR_ADMIN_SECURE_PORT
 COLLECTOR_API_KEY 
 COLLECTOR_BABYSITTER_PORT
 COLLECTOR_DISABLE_ACCESS_TOKEN_CHECKING
 COLLECTOR_GRPC_MAX_MSG_SIZE_BYTES
 COLLECTOR_GRPC_PLAIN_PORT
 COLLECTOR_HTTP_PLAIN_PORT
 COLLECTOR_INGESTION_TAGS
 COLLECTOR_FORWARDED_TAGS
 COLLECTOR_LIGHTSTEP_ACCESS_TOKEN
 COLLECTOR_LIGHTSTEP_COLLECTOR_HOST
 COLLECTOR_LIGHTSTEP_COLLECTOR_PLAINTEXT
 COLLECTOR_LIGHTSTEP_COLLECTOR_PORT
 COLLECTOR_LIGHTSTEP_USE_HTTP
 COLLECTOR_LIGHTSTEP_VERBOSE
 COLLECTOR_LOGGING_STDERR_CONFIG_ENABLED
 COLLECTOR_LOGGING_STDERR_CONFIG_FORMAT_HIDE_CALLSTACK
 COLLECTOR_LOGGING_VERBOSE
 COLLECTOR_PLAIN_PORT 
 COLLECTOR_POOL 
 COLLECTOR_PROJECT_NAME
 COLLECTOR_RAINBOW_GRPC_HOST
 COLLECTOR_RAINBOW_GRPC_PLAINTEXT
 COLLECTOR_RAINBOW_GRPC_PORT
 COLLECTOR_REPORTER_BYTES_PER_PROJECT
"

DARGS=""

# Helper function to compute a -e argument to docker when the environment is non-empty.
function map_env {
    local env=$1
    if [[ -z "${!env}" ]]; then
        echo
    else
        printf "%s" "-e ${env}=${!env}"
    fi
}

for var in ${VARS}; do
    DARGS="${DARGS} $(map_env ${var})"
done

# Helper function to compute a -p argument to docker when the port is non-zero.
function map_port {
    local port=$1
    if [[ "$port" = "0" ]]; then
        echo
    else
        echo "-p" "$port:$port"
    fi
}

# This exposes all the non-zero ports from the docker container.
PARGS="
 $(map_port $COLLECTOR_ADMIN_PLAIN_PORT)
 $(map_port $COLLECTOR_ADMIN_SECURE_PORT)
 $(map_port $COLLECTOR_BABYSITTER_PORT)
 $(map_port $COLLECTOR_GRPC_PLAIN_PORT)
 $(map_port $COLLECTOR_HTTP_PLAIN_PORT)
 $(map_port $COLLECTOR_PLAIN_PORT)
"

container=lightstep_developer_satellite

docker run -d ${DARGS} ${PARGS} --name ${container} --restart always ${IMAGE}
