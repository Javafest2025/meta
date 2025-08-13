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
DOCKER_ENV="$ROOT_DIR/Docker/.env"
COMPOSE_STACK="-f \"$DOCKER_SERVICES\" -f \"$DOCKER_APP\""

# Load environment variables from Docker .env file
if [[ -f "$DOCKER_ENV" ]]; then
    export $(grep -v '^#' "$DOCKER_ENV" | xargs)
fi

###############################################################################
# Helper functions
###############################################################################
get_container_info() {
    # Simple mapping of container names to their ports based on the services.yml
    echo "user-db:${USER_DB_PORT:-5433}:5432|notification-db:${NOTIFICATION_DB_PORT:-5434}:5432|project-db:${PROJECT_DB_PORT:-5435}:5432|user-rabbitmq:${USER_RABBITMQ_AMQP_PORT:-5672}:5672|user-redis:${USER_REDIS_PORT:-6379}:6379"
}

print_container_status() {
    local container_info="$1"
    local status="$2"
    
    if [[ -z "$container_info" ]]; then
        echo -e "${YELLOW}No container information available${NC}"
        return
    fi
    
    # Split the container info and print each one
    IFS='|' read -ra CONTAINERS <<< "$container_info"
    
    for container in "${CONTAINERS[@]}"; do
        if [[ -n "$container" ]]; then
            # Split container:port info
            IFS=':' read -ra PARTS <<< "$container"
            local container_name="${PARTS[0]}"
            local external_port="${PARTS[1]}"
            local internal_port="${PARTS[2]}"
            
            if [[ -n "$container_name" ]]; then
                case "$status" in
                    "started")
                        if [[ -n "$external_port" && "$external_port" != "unknown" ]]; then
                            echo -e "${GREEN}✓ $container_name → localhost:$external_port${NC}"
                        else
                            echo -e "${GREEN}✓ $container_name${NC}"
                        fi
                        ;;
                    "stopped")
                        echo -e "${RED}✗ $container_name${NC}"
                        ;;
                    *)
                        echo -e "${CYAN}• $container_name${NC}"
                        ;;
                esac
            fi
        fi
    done
}

###############################################################################
# Start/Stop services
###############################################################################
start_services() {
    echo -e "${CYAN}Starting core services...${NC}"
    docker compose -f "$DOCKER_SERVICES" up -d
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Core services started successfully!${NC}"
        echo -e "${CYAN}Container endpoints:${NC}"
        
        # Get container information and print status
        local container_info=$(get_container_info)
        print_container_status "$container_info" "started"
    else
        echo -e "${RED}Failed to start core services${NC}"
        exit 1
    fi
}

stop_services() {
    echo -e "${CYAN}Stopping core services...${NC}"
    docker compose -f "$DOCKER_SERVICES" down
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Core services stopped successfully!${NC}"
        
        # Get container information and print status
        local container_info=$(get_container_info)
        print_container_status "$container_info" "stopped"
    else
        echo -e "${RED}Failed to stop core services${NC}"
        exit 1
    fi
}

###############################################################################
# Status
###############################################################################
status() {
    echo -e "${CYAN}▶ Current container status:${NC}"
    # shellcheck disable=SC2086
    eval docker compose $COMPOSE_STACK ps
    
    echo -e "\n${CYAN}Container endpoints:${NC}"
    local container_info=$(get_container_info)
    print_container_status "$container_info" "status"
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
    echo -e "${CYAN}Commands:${NC}"
    echo -e "  ${YELLOW}start-svc${NC}  - Start all core services"
    echo -e "  ${YELLOW}stop-svc${NC}   - Stop all core services"
    echo -e "  ${YELLOW}status${NC}     - Show current container status"
    exit 1
    ;;
esac
