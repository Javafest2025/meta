#!/bin/bash

###############################################################################
# ScholarAI Meta Repository - Complete Docker Orchestration Script
# Controls the entire platform: Infrastructure → Backend → Frontend
###############################################################################

###############################################################################
# Pretty colours
###############################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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
print_header() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                    ScholarAI Platform Control               ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
}

print_step() {
    local step="$1"
    local message="$2"
    echo -e "${BLUE}[STEP $step]${NC} ${message}"
}

wait_for_service() {
    local service_name="$1"
    local port="$2"
    local max_attempts=30
    local attempt=1
    
    echo -e "${YELLOW}Waiting for $service_name to be ready...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:$port/actuator/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ $service_name is ready!${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}Attempt $attempt/$max_attempts: $service_name not ready yet...${NC}"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}✗ $service_name failed to start within timeout${NC}"
    return 1
}

get_container_info() {
    # Infrastructure services
    echo "user-db:${USER_DB_PORT:-5433}:5432|notification-db:${NOTIFICATION_DB_PORT:-5434}:5432|project-db:${PROJECT_DB_PORT:-5435}:5432|user-rabbitmq:${USER_RABBITMQ_AMQP_PORT:-5672}:5672|user-redis:${USER_REDIS_PORT:-6379}:6379"
}

get_app_info() {
    # Application services
    echo "scholar-service-registry:8761:8761|scholar-api-gateway:8989:8989|scholar-notification-service:8082:8082|scholar-project-service:8083:8083|scholar-user-service:8081:8081|scholar-frontend:3000:3000"
}

print_container_status() {
    local container_info="$1"
    local status="$2"
    local type="$3"
    
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
# Infrastructure Management
###############################################################################
start_infrastructure() {
    print_step "1" "Starting infrastructure services (Databases, RabbitMQ, Redis)..."
    docker compose -f "$DOCKER_SERVICES" up -d
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Infrastructure services started successfully!${NC}"
        echo -e "${CYAN}Infrastructure endpoints:${NC}"
        local container_info=$(get_container_info)
        print_container_status "$container_info" "started" "infrastructure"
        
        # Wait for infrastructure to be ready
        echo -e "${YELLOW}Waiting 30 seconds for infrastructure to stabilize...${NC}"
        sleep 30
    else
        echo -e "${RED}✗ Failed to start infrastructure services${NC}"
        exit 1
    fi
}

stop_infrastructure() {
    print_step "1" "Stopping infrastructure services..."
    docker compose -f "$DOCKER_SERVICES" down
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Infrastructure services stopped successfully!${NC}"
    else
        echo -e "${RED}✗ Failed to stop infrastructure services${NC}"
        exit 1
    fi
}

###############################################################################
# Application Management
###############################################################################
start_applications() {
    print_step "2" "Starting application services..."
    
    # Start service registry first
    print_step "2.1" "Starting Service Registry..."
    docker compose -f "$DOCKER_APP" up -d service-registry
    if ! wait_for_service "Service Registry" "8761"; then
        echo -e "${RED}✗ Service Registry failed to start${NC}"
        exit 1
    fi
    
    # Start API Gateway
    print_step "2.2" "Starting API Gateway..."
    docker compose -f "$DOCKER_APP" up -d api-gateway
    if ! wait_for_service "API Gateway" "8989"; then
        echo -e "${RED}✗ API Gateway failed to start${NC}"
        exit 1
    fi
    
    # Start microservices in parallel
    print_step "2.3" "Starting microservices (Notification, Project, User)..."
    docker compose -f "$DOCKER_APP" up -d notification-service project-service user-service
    
    # Wait for microservices to be ready
    echo -e "${YELLOW}Waiting for microservices to be ready...${NC}"
    sleep 30
    
    # Start frontend last
    print_step "2.4" "Starting Frontend..."
    docker compose -f "$DOCKER_APP" up -d frontend
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ All application services started successfully!${NC}"
        echo -e "${CYAN}Application endpoints:${NC}"
        local app_info=$(get_app_info)
        print_container_status "$app_info" "started" "application"
    else
        echo -e "${RED}✗ Failed to start some application services${NC}"
        exit 1
    fi
}

stop_applications() {
    print_step "2" "Stopping application services..."
    docker compose -f "$DOCKER_APP" down
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Application services stopped successfully!${NC}"
    else
        echo -e "${RED}✗ Failed to stop application services${NC}"
        exit 1
    fi
}

###############################################################################
# Individual Service Control
###############################################################################
start_service() {
    local service="$1"
    
    case "$service" in
        "infra"|"infrastructure")
            start_infrastructure
            ;;
        "apps"|"applications")
            start_applications
            ;;
        "service-registry")
            docker compose -f "$DOCKER_APP" up -d service-registry
            ;;
        "api-gateway")
            docker compose -f "$DOCKER_APP" up -d api-gateway
            ;;
        "notification")
            docker compose -f "$DOCKER_APP" up -d notification-service
            ;;
        "project")
            docker compose -f "$DOCKER_APP" up -d project-service
            ;;
        "user")
            docker compose -f "$DOCKER_APP" up -d user-service
            ;;
        "frontend")
            docker compose -f "$DOCKER_APP" up -d frontend
            ;;
        *)
            echo -e "${RED}Unknown service: $service${NC}"
            echo -e "${YELLOW}Available services: infra, apps, service-registry, api-gateway, notification, project, user, frontend${NC}"
            exit 1
            ;;
    esac
}

stop_service() {
    local service="$1"
    
    case "$service" in
        "infra"|"infrastructure")
            stop_infrastructure
            ;;
        "apps"|"applications")
            stop_applications
            ;;
        "service-registry")
            docker compose -f "$DOCKER_APP" stop service-registry
            ;;
        "api-gateway")
            docker compose -f "$DOCKER_APP" stop api-gateway
            ;;
        "notification")
            docker compose -f "$DOCKER_APP" stop notification-service
            ;;
        "project")
            docker compose -f "$DOCKER_APP" stop project-service
            ;;
        "user")
            docker compose -f "$DOCKER_APP" stop user-service
            ;;
        "frontend")
            docker compose -f "$DOCKER_APP" stop frontend
            ;;
        *)
            echo -e "${RED}Unknown service: $service${NC}"
            echo -e "${YELLOW}Available services: infra, apps, service-registry, api-gateway, notification, project, user, frontend${NC}"
            exit 1
            ;;
    esac
}

###############################################################################
# Complete Platform Control
###############################################################################
start_all() {
    print_header
    print_step "1" "Starting complete ScholarAI platform..."
    
    # Start infrastructure first
    start_infrastructure
    
    # Start applications
    start_applications
    
    echo -e "${GREEN}🎉 ScholarAI platform is now running!${NC}"
    echo -e "${CYAN}Access points:${NC}"
    echo -e "${GREEN}• Frontend:${NC} http://localhost:3000"
    echo -e "${GREEN}• API Gateway:${NC} http://localhost:8989"
    echo -e "${GREEN}• Service Registry:${NC} http://localhost:8761"
    echo -e "${GREEN}• RabbitMQ Management:${NC} http://localhost:15672"
}

stop_all() {
    print_header
    print_step "1" "Stopping complete ScholarAI platform..."
    
    # Stop applications first
    stop_applications
    
    # Stop infrastructure
    stop_infrastructure
    
    echo -e "${GREEN}✓ ScholarAI platform stopped successfully!${NC}"
}

restart_all() {
    print_header
    print_step "1" "Restarting complete ScholarAI platform..."
    
    stop_all
    sleep 5
    start_all
}

###############################################################################
# Status and Monitoring
###############################################################################
status() {
    print_header
    echo -e "${CYAN}▶ Current platform status:${NC}"
    
    # Infrastructure status
    echo -e "\n${BLUE}Infrastructure Services:${NC}"
    docker compose -f "$DOCKER_SERVICES" ps
    
    # Application status
    echo -e "\n${BLUE}Application Services:${NC}"
    docker compose -f "$DOCKER_APP" ps
    
    # Container endpoints
    echo -e "\n${CYAN}Infrastructure endpoints:${NC}"
    local container_info=$(get_container_info)
    print_container_status "$container_info" "status" "infrastructure"
    
    echo -e "\n${CYAN}Application endpoints:${NC}"
    local app_info=$(get_app_info)
    print_container_status "$app_info" "status" "application"
}

logs() {
    local service="$1"
    
    if [[ -z "$service" ]]; then
        echo -e "${RED}Please specify a service to view logs${NC}"
        echo -e "${YELLOW}Available services: infra, apps, service-registry, api-gateway, notification, project, user, frontend${NC}"
        exit 1
    fi
    
    case "$service" in
        "infra"|"infrastructure")
            docker compose -f "$DOCKER_SERVICES" logs -f
            ;;
        "apps"|"applications")
            docker compose -f "$DOCKER_APP" logs -f
            ;;
        *)
            docker compose -f "$DOCKER_APP" logs -f "$service"
            ;;
    esac
}

###############################################################################
# Build and Clean
###############################################################################
build_all() {
    print_header
    print_step "1" "Building all Docker images..."
    
    # Build infrastructure (if needed)
    echo -e "${CYAN}Building infrastructure images...${NC}"
    docker compose -f "$DOCKER_SERVICES" build
    
    # Build applications
    echo -e "${CYAN}Building application images...${NC}"
    docker compose -f "$DOCKER_APP" build
    
    echo -e "${GREEN}✓ All images built successfully!${NC}"
}

clean_all() {
    print_header
    echo -e "${YELLOW}⚠️  This will remove ALL containers, images, and volumes!${NC}"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_step "1" "Cleaning up all Docker resources..."
        
        # Stop and remove everything
        docker compose -f "$DOCKER_SERVICES" down --rmi all --volumes --remove-orphans
        docker compose -f "$DOCKER_APP" down --rmi all --volumes --remove-orphans
        
        # Remove dangling images
        docker image prune -f
        
        # Remove network
        docker network rm scholarai-network 2>/dev/null || true
        
        echo -e "${GREEN}✓ Cleanup completed!${NC}"
    else
        echo -e "${CYAN}Cleanup cancelled${NC}"
    fi
}

###############################################################################
# Help
###############################################################################
show_help() {
    print_header
    echo -e "${CYAN}ScholarAI Platform Control Script${NC}"
    echo ""
    echo -e "${YELLOW}Usage:${NC} $0 [COMMAND] [SERVICE]"
    echo ""
    echo -e "${BLUE}Platform Commands:${NC}"
    echo -e "  ${GREEN}start-all${NC}     - Start complete platform (infrastructure + applications)"
    echo -e "  ${GREEN}stop-all${NC}      - Stop complete platform"
    echo -e "  ${GREEN}restart-all${NC}   - Restart complete platform"
    echo -e "  ${GREEN}status${NC}        - Show platform status"
    echo ""
    echo -e "${BLUE}Infrastructure Commands:${NC}"
    echo -e "  ${GREEN}start infra${NC}   - Start only infrastructure (DBs, RabbitMQ, Redis)"
    echo -e "  ${GREEN}stop infra${NC}    - Stop only infrastructure"
    echo ""
    echo -e "${BLUE}Application Commands:${NC}"
    echo -e "  ${GREEN}start apps${NC}    - Start only applications (after infrastructure)"
    echo -e "  ${GREEN}stop apps${NC}     - Stop only applications"
    echo ""
    echo -e "${BLUE}Individual Service Commands:${NC}"
    echo -e "  ${GREEN}start [SERVICE]${NC} - Start specific service"
    echo -e "  ${GREEN}stop [SERVICE]${NC}  - Stop specific service"
    echo -e "  ${GREEN}logs [SERVICE]${NC}  - View logs for specific service"
    echo ""
    echo -e "${BLUE}Available Services:${NC}"
    echo -e "  • service-registry  - Eureka Service Registry"
    echo -e "  • api-gateway       - Spring Cloud Gateway"
    echo -e "  • notification      - Notification Service"
    echo -e "  • project          - Project Service"
    echo -e "  • user             - User Service"
    echo -e "  • frontend         - Next.js Frontend"
    echo ""
    echo -e "${BLUE}Utility Commands:${NC}"
    echo -e "  ${GREEN}build-all${NC}     - Build all Docker images"
    echo -e "  ${GREEN}clean-all${NC}     - Remove all containers, images, and volumes"
    echo -e "  ${GREEN}help${NC}          - Show this help message"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo -e "  $0 start-all                    # Start everything"
    echo -e "  $0 start infra                  # Start only infrastructure"
    echo -e "  $0 start apps                   # Start only applications"
    echo -e "  $0 start service-registry       # Start specific service"
    echo -e "  $0 logs api-gateway             # View API Gateway logs"
    echo -e "  $0 status                       # Show platform status"
}

###############################################################################
# CLI entrypoint
###############################################################################
case "$1" in
    "start-all")           start_all ;;
    "stop-all")            stop_all ;;
    "restart-all")         restart_all ;;
    "start")               start_service "$2" ;;
    "stop")                stop_service "$2" ;;
    "status")              status ;;
    "logs")                logs "$2" ;;
    "build-all")           build_all ;;
    "clean-all")           clean_all ;;
    "help"|"-h"|"--help") show_help ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo -e "${YELLOW}Use '$0 help' for usage information${NC}"
        exit 1
        ;;
esac
