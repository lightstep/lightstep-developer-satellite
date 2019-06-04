#!/bin/bash

# This script should be called with these variables set:
#   LIGHTSTEP_API_KEY
#   LIGHTSTEP_USER
#   LIGHTSTEP_PROJECT

# To test an alternate image (e.g., the canary), modify IMAGE and/or IMAGE_TAG.
: "${IMAGE:=lightstep/developer-satellite}"
: "${IMAGE_TAG:=latest}"

IMAGE_VERSION="${IMAGE}:${IMAGE_TAG}"

PSNAME=lightstep_developer_satellite

STOP_CMD='  bash -c "$(curl -L https://raw.githubusercontent.com/lightstep/lightstep-developer-satellite/master/stop-developer-satellite.sh)"'

docker info > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "This version of the LightStep Satellite requires docker.  Please install docker before proceeding."
  exit 1
fi

ID=$(docker ps --all | grep "${PSNAME}" | head -n 1 | cut -d ' ' -f 1 )
if [ -n "$ID" ]; then
  echo "There is already a LightStep Satellite running.  Stopping it now."
  while true; do
    ID=$(docker ps --all | grep "${PSNAME}" | head -n 1 | cut -d ' ' -f 1 )
    if [ -n "$ID" ]; then
      echo "Removing docker container $ID"
      docker kill "$ID" > /dev/null 2>&1 || true
      docker rm "$ID" > /dev/null 2>&1 || true
    else
      break
    fi
  done
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
# they haven't been set in the environment.  Only the API key and
# forwarded metric tags are always set here.  The other COLLECTOR_*
# environment variables will override the values derived here,
# including those derived from the LIGHTSTEP_* argument variables.

COLLECTOR_API_KEY="${LIGHTSTEP_API_KEY}"
COLLECTOR_FORWARDED_TAGS="developer_satellite:true"

# Developer-mode specifics
: "${COLLECTOR_POOL:=developer-satellite}"
: "${COLLECTOR_PROJECT_NAME:=${LIGHTSTEP_PROJECT}}"
: "${COLLECTOR_ROUTING_TAGS:=developer_name:${LIGHTSTEP_USER},project_name:${LIGHTSTEP_PROJECT},developer_mode:true}"
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
# Disable meta reports
: "${COLLECTOR_ENABLE_META_EVENTS:=false}"
# Log to stderr
: "${COLLECTOR_LOGGING_STDERR_CONFIG_ENABLED:=true}"
: "${COLLECTOR_LOGGING_STDERR_CONFIG_FORMAT_HIDE_CALLSTACK:=true}"
: "${COLLECTOR_LOGGING_STDERR_CONFIG_FORMAT_HIDE_TAGS:=true}"

# Pull down the latest version of the satellite from docker hub
# (Note, this does not happen automatically with docker run)
docker pull ${IMAGE_VERSION}

# These variables will pass through to the docker environment.
VARS="
 COLLECTOR_ADMIN_PLAIN_PORT
 COLLECTOR_ADMIN_SECURE_PORT
 COLLECTOR_API_KEY 
 COLLECTOR_BABYSITTER_PORT
 COLLECTOR_DISABLE_ACCESS_TOKEN_CHECKING
 COLLECTOR_ENABLE_META_EVENTS
 COLLECTOR_FORWARDED_TAGS
 COLLECTOR_GRPC_MAX_MSG_SIZE_BYTES
 COLLECTOR_GRPC_PLAIN_PORT
 COLLECTOR_HTTP_PLAIN_PORT
 COLLECTOR_INGESTION_TAGS
 COLLECTOR_LIGHTSTEP_ACCESS_TOKEN
 COLLECTOR_LIGHTSTEP_COLLECTOR_HOST
 COLLECTOR_LIGHTSTEP_COLLECTOR_PLAINTEXT
 COLLECTOR_LIGHTSTEP_COLLECTOR_PORT
 COLLECTOR_LIGHTSTEP_USE_HTTP
 COLLECTOR_LIGHTSTEP_VERBOSE
 COLLECTOR_LOGGING_STDERR_CONFIG_ENABLED
 COLLECTOR_LOGGING_STDERR_CONFIG_FORMAT_HIDE_CALLSTACK
 COLLECTOR_LOGGING_STDERR_CONFIG_FORMAT_HIDE_TAGS
 COLLECTOR_LOGGING_VERBOSE
 COLLECTOR_PLAIN_PORT 
 COLLECTOR_POOL 
 COLLECTOR_PROJECT_NAME
 COLLECTOR_RAINBOW_GRPC_HOST
 COLLECTOR_RAINBOW_GRPC_PLAINTEXT
 COLLECTOR_RAINBOW_GRPC_PORT
 COLLECTOR_REPORTER_BYTES_PER_PROJECT
 COLLECTOR_ROUTING_TAGS
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

# Lookup the host's IP address that can be used by other containers to reach
# this satellite.
docker_hostip=$(docker network inspect bridge --format '{{ (index .IPAM.Config 0).Gateway }}')

container=lightstep_developer_satellite

echo
echo "Starting the LightStep Developer Satellite on port ${COLLECTOR_HTTP_PLAIN_PORT}."
echo
echo "To access this satellite from inside a Docker container, configure the"
echo "Tracer's \"collector_host\" to ${docker_hostip}."
echo
echo "This process will be restarted by the Docker daemon automatically, including"
echo "when this machine reboots.  To stop this process, run:"
echo "${STOP_CMD}"
echo

docker run -d ${DARGS} ${PARGS} --name ${container} --restart always ${IMAGE_VERSION}
