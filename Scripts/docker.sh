#!/bin/bash

###############################################################################
# Pretty colours
###############################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

###############################################################################
# Paths & constants
###############################################################################
ROOT_DIR="$(dirname "$0")/.."
DOCKER_APP="$ROOT_DIR/Docker/apps.yml"
DOCKER_SERVICES="$ROOT_DIR/Docker/services.yml"
COMPOSE_STACK="-f \"$DOCKER_SERVICES\" -f \"$DOCKER_APP\""


# Start/Stop services
start_services() {
    echo -e "${CYAN}Starting core services...${NC}"
    docker compose -f "$DOCKER_SERVICES" up -d
    echo -e "${GREEN}Core services started.${NC}"
    echo -e "${GREEN}userDB (PostgreSQL) → localhost:5433${NC}"
}

stop_services() {
    echo -e "${CYAN}Stopping core services...${NC}"
    docker compose -f "$DOCKER_SERVICES" down
    echo -e "${GREEN}Core services stopped.${NC}"
}

###############################################################################
# Status
###############################################################################
status() {
  echo -e "${CYAN}▶ Current container status:${NC}"
  # shellcheck disable=SC2086
  eval docker compose $COMPOSE_STACK ps
}

###############################################################################
# CLI entrypoint
###############################################################################
case "$1" in
  "start-svc")        start_services ;;
  "stop-svc")         stop_services ;;
  "status")           status ;;
  *)
    echo -e "${RED}Usage:${NC} $0 ${YELLOW}{start-svc|stop-svc|status}${NC}"
    exit 1
    ;;
esac
