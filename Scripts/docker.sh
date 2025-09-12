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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DOCKER_APP="$ROOT_DIR/Docker/apps.yml"
DOCKER_SERVICES="$ROOT_DIR/Docker/services.yml"
DOCKER_ENV="$ROOT_DIR/Docker/.env"

# Load environment variables from Docker .env file
if [[ -f "$DOCKER_ENV" ]]; then
    set -a
    source "$DOCKER_ENV"
    set +a
fi

###############################################################################
# Helper functions
###############################################################################
get_container_info() {
    # Simple mapping of container names to their ports based on the services.yml
    echo "user-db:${USER_DB_PORT:-5433}:5432|notification-db:${NOTIFICATION_DB_PORT:-5434}:5432|project-db:${PROJECT_DB_PORT:-5435}:5432|user-rabbitmq:${USER_RABBITMQ_AMQP_PORT:-5672}:5672|user-redis:${USER_REDIS_PORT:-6379}:6379|pdf_extractor_grobid:8070:8070"
}

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
    
    echo -e "${YELLOW}Waiting for $service_name to be ready on port $port...${NC}"
    
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

wait_for_frontend() {
    local max_attempts=30
    local attempt=1
    
    echo -e "${YELLOW}Waiting for Frontend to be ready on port 3000...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s "http://localhost:3000" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Frontend is ready!${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}Attempt $attempt/$max_attempts: Frontend not ready yet...${NC}"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}✗ Frontend failed to start within timeout${NC}"
    return 1
}

print_service_status() {
    local service_name="$1"
    local port="$2"
    
    if curl -s "http://localhost:$port/actuator/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $service_name (localhost:$port)${NC}"
        return 0
    else
        echo -e "${RED}✗ $service_name (localhost:$port)${NC}"
        return 1
    fi
}

print_frontend_status() {
    if curl -s "http://localhost:3000" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Frontend (localhost:3000)${NC}"
        return 0
    else
        echo -e "${RED}✗ Frontend (localhost:3000)${NC}"
        return 1
    fi
}

###############################################################################
# Infrastructure Management
###############################################################################
start_infrastructure() {
    print_step "1" "Starting infrastructure services (Databases, RabbitMQ, Redis)..."
    
    cd "$ROOT_DIR"
    
    if docker compose -f "$DOCKER_SERVICES" up -d; then
        echo -e "${GREEN}✓ Infrastructure services started successfully!${NC}"
        echo -e "${CYAN}Infrastructure services:${NC}"
        echo -e "${GREEN}• user-db:${NC} localhost:${USER_DB_PORT:-5433}"
        echo -e "${GREEN}• notification-db:${NC} localhost:${NOTIFICATION_DB_PORT:-5434}"
        echo -e "${GREEN}• project-db:${NC} localhost:${PROJECT_DB_PORT:-5435}"
        echo -e "${GREEN}• user-rabbitmq:${NC} localhost:${USER_RABBITMQ_AMQP_PORT:-5672}"
        echo -e "${GREEN}• user-redis:${NC} localhost:${USER_REDIS_PORT:-6379}"
        echo -e "${GREEN}• grobid-pdf-extractor:${NC} localhost:8070"
        
        # Wait for infrastructure to be ready
        echo -e "${YELLOW}Waiting 15 seconds for infrastructure to stabilize...${NC}"
        sleep 15
        return 0
    else
        echo -e "${RED}✗ Failed to start infrastructure services${NC}"
        return 1
    fi
}

stop_infrastructure() {
    print_step "1" "Stopping infrastructure services..."
    
    cd "$ROOT_DIR"
    
    if docker compose -f "$DOCKER_SERVICES" down; then
        echo -e "${GREEN}✓ Infrastructure services stopped successfully!${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to stop infrastructure services${NC}"
        return 1
    fi
}

###############################################################################
# Application Management
###############################################################################
start_applications() {
    print_step "2" "Starting application services in sequence..."
    
    cd "$ROOT_DIR"
    
    # 1. Service Registry
    print_step "2.1" "Starting Service Registry..."
    if docker compose -f "$DOCKER_APP" up -d service-registry; then
        echo -e "${GREEN}✓ Service Registry started${NC}"
        if ! wait_for_service "Service Registry" "8761"; then
            echo -e "${RED}✗ Service Registry failed to become ready${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to start Service Registry${NC}"
        return 1
    fi
    
    # 2. API Gateway
    print_step "2.2" "Starting API Gateway..."
    if docker compose -f "$DOCKER_APP" up -d api-gateway; then
        echo -e "${GREEN}✓ API Gateway started${NC}"
        if ! wait_for_service "API Gateway" "8989"; then
            echo -e "${RED}✗ API Gateway failed to become ready${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to start API Gateway${NC}"
        return 1
    fi
    
    # 3. Notification Service
    print_step "2.3" "Starting Notification Service..."
    if docker compose -f "$DOCKER_APP" up -d notification-service; then
        echo -e "${GREEN}✓ Notification Service started${NC}"
        if ! wait_for_service "Notification Service" "8082"; then
            echo -e "${RED}✗ Notification Service failed to become ready${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to start Notification Service${NC}"
        return 1
    fi
    
    # 4. Project Service
    print_step "2.4" "Starting Project Service..."
    if docker compose -f "$DOCKER_APP" up -d project-service; then
        echo -e "${GREEN}✓ Project Service started${NC}"
        if ! wait_for_service "Project Service" "8083"; then
            echo -e "${RED}✗ Project Service failed to become ready${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to start Project Service${NC}"
        return 1
    fi
    
    # 5. User Service
    print_step "2.5" "Starting User Service..."
    if docker compose -f "$DOCKER_APP" up -d user-service; then
        echo -e "${GREEN}✓ User Service started${NC}"
        if ! wait_for_service "User Service" "8081"; then
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to start User Service${NC}"
        return 1
    fi
    
    # 6. Paper Search Service
    print_step "2.6" "Starting Paper Search Service..."
    if docker compose -f "$DOCKER_APP" up -d paper-search; then
        echo -e "${GREEN}✓ Paper Search Service started${NC}"
        if ! wait_for_service "Paper Search Service" "8001"; then
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to start Paper Search Service${NC}"
        return 1
    fi
    
    # 7. PDF Extractor Service
    print_step "2.7" "Starting PDF Extractor Service..."
    if docker compose -f "$DOCKER_APP" up -d extractor; then
        echo -e "${GREEN}✓ PDF Extractor Service started${NC}"
        if ! wait_for_service "PDF Extractor Service" "8002"; then
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to start PDF Extractor Service${NC}"
        return 1
    fi
    
    # 8. Frontend
    print_step "2.8" "Starting Frontend..."
    if docker compose -f "$DOCKER_APP" up -d frontend; then
        echo -e "${GREEN}✓ Frontend started${NC}"
        if ! wait_for_frontend; then
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to start Frontend${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ All application services started successfully!${NC}"
    return 0
}

stop_applications() {
    print_step "2" "Stopping application services..."
    
    cd "$ROOT_DIR"
    
    if docker compose -f "$DOCKER_APP" down; then
        echo -e "${GREEN}✓ Application services stopped successfully!${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to stop application services${NC}"
        return 1
    fi
}

###############################################################################
# Individual Service Control
###############################################################################
start_service() {
    local service="$1"
    
    cd "$ROOT_DIR"
    
    case "$service" in
        "infra"|"infrastructure")
            start_infrastructure
            ;;
        "apps"|"applications")
            start_applications
            ;;
        "service-registry")
            echo -e "${CYAN}Starting Service Registry...${NC}"
            docker compose -f "$DOCKER_APP" up -d service-registry
            ;;
        "api-gateway")
            echo -e "${CYAN}Starting API Gateway...${NC}"
            docker compose -f "$DOCKER_APP" up -d api-gateway
            ;;
        "notification")
            echo -e "${CYAN}Starting Notification Service...${NC}"
            docker compose -f "$DOCKER_APP" up -d notification-service
            ;;
        "project")
            echo -e "${CYAN}Starting Project Service...${NC}"
            docker compose -f "$DOCKER_APP" up -d project-service
            ;;
        "user")
            echo -e "${CYAN}Starting User Service...${NC}"
            docker compose -f "$DOCKER_APP" up -d user-service
            ;;
        "paper-search")
            echo -e "${CYAN}Starting Paper Search Service...${NC}"
            docker compose -f "$DOCKER_APP" up -d paper-search
            ;;
        "extractor")
            echo -e "${CYAN}Starting PDF Extractor Service...${NC}"
            docker compose -f "$DOCKER_APP" up -d extractor
            ;;
        "frontend")
            echo -e "${CYAN}Starting Frontend...${NC}"
            docker compose -f "$DOCKER_APP" up -d frontend
            ;;
        "grobid")
            echo -e "${CYAN}Starting GROBID PDF Extractor...${NC}"
            docker compose -f "$DOCKER_SERVICES" up -d grobid
            ;;
        *)
            echo -e "${RED}Unknown service: $service${NC}"
            echo -e "${YELLOW}Available services: infra, apps, service-registry, api-gateway, notification, project, user, paper-search, frontend, grobid${NC}"
            return 1
            ;;
    esac
}

restart_service() {
    local service="$1"
    
    cd "$ROOT_DIR"
    
    case "$service" in
        "infra"|"infrastructure")
            print_step "1" "Restarting infrastructure services..."
            stop_infrastructure
            sleep 3
            start_infrastructure
            ;;
        "apps"|"applications")
            print_step "1" "Restarting application services..."
            stop_applications
            sleep 3
            start_applications
            ;;
        "service-registry")
            echo -e "${CYAN}Restarting Service Registry (with rebuild)...${NC}"
            docker compose -f "$DOCKER_APP" stop service-registry
            docker compose -f "$DOCKER_APP" build service-registry
            docker compose -f "$DOCKER_APP" up -d service-registry
            ;;
        "api-gateway")
            echo -e "${CYAN}Restarting API Gateway (with rebuild)...${NC}"
            docker compose -f "$DOCKER_APP" stop api-gateway
            docker compose -f "$DOCKER_APP" build api-gateway
            docker compose -f "$DOCKER_APP" up -d api-gateway
            ;;
        "notification")
            echo -e "${CYAN}Restarting Notification Service (with rebuild)...${NC}"
            docker compose -f "$DOCKER_APP" stop notification-service
            docker compose -f "$DOCKER_APP" build notification-service
            docker compose -f "$DOCKER_APP" up -d notification-service
            ;;
        "project")
            echo -e "${CYAN}Restarting Project Service (with rebuild)...${NC}"
            docker compose -f "$DOCKER_APP" stop project-service
            docker compose -f "$DOCKER_APP" build project-service
            docker compose -f "$DOCKER_APP" up -d project-service
            ;;
        "user")
            echo -e "${CYAN}Restarting User Service (with rebuild)...${NC}"
            docker compose -f "$DOCKER_APP" stop user-service
            docker compose -f "$DOCKER_APP" build user-service
            docker compose -f "$DOCKER_APP" up -d user-service
            ;;
        "paper-search")
            echo -e "${CYAN}Restarting Paper Search Service (with rebuild)...${NC}"
            docker compose -f "$DOCKER_APP" stop paper-search
            docker compose -f "$DOCKER_APP" build paper-search
            docker compose -f "$DOCKER_APP" up -d paper-search
            ;;
        "extractor")
            echo -e "${CYAN}Restarting PDF Extractor Service (with rebuild)...${NC}"
            docker compose -f "$DOCKER_APP" stop extractor
            docker compose -f "$DOCKER_APP" build extractor
            docker compose -f "$DOCKER_APP" up -d extractor
            ;;
        "frontend")
            echo -e "${CYAN}Restarting Frontend (with rebuild)...${NC}"
            docker compose -f "$DOCKER_APP" stop frontend
            docker compose -f "$DOCKER_APP" build frontend
            docker compose -f "$DOCKER_APP" up -d frontend
            ;;
        "grobid")
            echo -e "${CYAN}Restarting GROBID PDF Extractor (with rebuild)...${NC}"
            docker compose -f "$DOCKER_SERVICES" stop grobid
            docker compose -f "$DOCKER_SERVICES" build grobid
            docker compose -f "$DOCKER_SERVICES" up -d grobid
            ;;
        *)
            echo -e "${RED}Unknown service: $service${NC}"
            echo -e "${YELLOW}Available services: infra, apps, service-registry, api-gateway, notification, project, user, paper-search, extractor, frontend, grobid${NC}"
            return 1
            ;;
    esac
}

stop_service() {
    local service="$1"
    
    cd "$ROOT_DIR"
    
    case "$service" in
        "infra"|"infrastructure")
            stop_infrastructure
            ;;
        "apps"|"applications")
            stop_applications
            ;;
        "service-registry")
            echo -e "${CYAN}Stopping Service Registry...${NC}"
            docker compose -f "$DOCKER_APP" stop service-registry
            ;;
        "api-gateway")
            echo -e "${CYAN}Stopping API Gateway...${NC}"
            docker compose -f "$DOCKER_APP" stop api-gateway
            ;;
        "notification")
            echo -e "${CYAN}Stopping Notification Service...${NC}"
            docker compose -f "$DOCKER_APP" stop notification-service
            ;;
        "project")
            echo -e "${CYAN}Stopping Project Service...${NC}"
            docker compose -f "$DOCKER_APP" stop project-service
            ;;
        "user")
            echo -e "${CYAN}Stopping User Service...${NC}"
            docker compose -f "$DOCKER_APP" stop user-service
            ;;
        "paper-search")
            echo -e "${CYAN}Stopping Paper Search Service...${NC}"
            docker compose -f "$DOCKER_APP" stop paper-search
            ;;
        "extractor")
            echo -e "${CYAN}Stopping PDF Extractor Service...${NC}"
            docker compose -f "$DOCKER_APP" stop extractor
            ;;
        "frontend")
            echo -e "${CYAN}Stopping Frontend...${NC}"
            docker compose -f "$DOCKER_APP" stop frontend
            ;;
        "grobid")
            echo -e "${CYAN}Stopping GROBID PDF Extractor...${NC}"
            docker compose -f "$DOCKER_SERVICES" stop grobid
            ;;
        *)
            echo -e "${RED}Unknown service: $service${NC}"
            echo -e "${YELLOW}Available services: infra, apps, service-registry, api-gateway, notification, project, user, paper-search, extractor, frontend, grobid${NC}"
            return 1
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
    if ! start_infrastructure; then
        echo -e "${RED}✗ Failed to start infrastructure. Aborting.${NC}"
        exit 1
    fi
    
    # Start applications
    if ! start_applications; then
        echo -e "${RED}✗ Failed to start applications. Aborting.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}🎉 ScholarAI platform is now running!${NC}"
    echo -e "${CYAN}Access points:${NC}"
    echo -e "${GREEN}• Frontend:${NC} http://localhost:3000"
    echo -e "${GREEN}• API Gateway:${NC} http://localhost:8989"
    echo -e "${GREEN}• Service Registry:${NC} http://localhost:8761"
    echo -e "${GREEN}• Paper Search Service:${NC} http://localhost:8001"
    echo -e "${GREEN}• PDF Extractor Service:${NC} http://localhost:8002"
    echo -e "${GREEN}• RabbitMQ Management:${NC} http://localhost:15672"
    echo -e "${GREEN}• GROBID PDF Extractor:${NC} http://localhost:8070"
}

stop_all() {
    print_header
    print_step "1" "Stopping complete ScholarAI platform..."
    
    # Stop applications first
    if ! stop_applications; then
        echo -e "${YELLOW}Warning: Some application services failed to stop${NC}"
    fi
    
    # Stop infrastructure
    if ! stop_infrastructure; then
        echo -e "${YELLOW}Warning: Some infrastructure services failed to stop${NC}"
    fi
    
    echo -e "${GREEN}✓ ScholarAI platform stopped successfully!${NC}"
}

restart_all() {
    print_header
    print_step "1" "Restarting complete ScholarAI platform..."
    
    stop_all
    sleep 5
    start_all
}

rebuild_all() {
    print_header
    print_step "1" "Rebuilding and restarting complete ScholarAI platform..."
    
    # Stop everything first
    stop_all
    
    # Build all images fresh
    build_all
    
    # Start everything
    start_all
}

###############################################################################
# Status and Monitoring
###############################################################################
status() {
    print_header
    echo -e "${CYAN}▶ Current platform status:${NC}"
    
    cd "$ROOT_DIR"
    
    # Infrastructure status
    echo -e "\n${BLUE}Infrastructure Services:${NC}"
    docker compose -f "$DOCKER_SERVICES" ps
    
    # Application status
    echo -e "\n${BLUE}Application Services:${NC}"
    docker compose -f "$DOCKER_APP" ps
    
    # Health check status
    echo -e "\n${BLUE}Service Health Status:${NC}"
    print_service_status "Service Registry" "8761"
    print_service_status "API Gateway" "8989"
    print_service_status "Notification Service" "8082"
    print_service_status "Project Service" "8083"
    print_service_status "User Service" "8081"
    print_service_status "Paper Search Service" "8001"
    print_service_status "PDF Extractor Service" "8002"
    print_frontend_status
    
    # Container endpoints
    echo -e "\n${CYAN}Service Endpoints:${NC}"
    echo -e "${GREEN}• Frontend:${NC} http://localhost:3000"
    echo -e "${GREEN}• API Gateway:${NC} http://localhost:8989"
    echo -e "${GREEN}• Service Registry:${NC} http://localhost:8761"
    echo -e "${GREEN}• Notification Service:${NC} http://localhost:8082"
    echo -e "${GREEN}• Project Service:${NC} http://localhost:8083"
    echo -e "${GREEN}• User Service:${NC} http://localhost:8081"
    echo -e "${GREEN}• Paper Search Service:${NC} http://localhost:8001"
    echo -e "${GREEN}• RabbitMQ Management:${NC} http://localhost:15672"
    echo -e "${GREEN}• GROBID PDF Extractor:${NC} http://localhost:8070"
}

logs() {
    local service="$1"
    
    cd "$ROOT_DIR"
    
    if [[ -z "$service" ]]; then
        echo -e "${RED}Please specify a service to view logs${NC}"
        echo -e "${YELLOW}Available services: infra, apps, service-registry, api-gateway, notification, project, user, paper-search, extractor, frontend, grobid${NC}"
        return 1
    fi
    
    case "$service" in
        "infra"|"infrastructure")
            docker compose -f "$DOCKER_SERVICES" logs -f
            ;;
        "apps"|"applications")
            docker compose -f "$DOCKER_APP" logs -f
            ;;
        "service-registry")
            docker compose -f "$DOCKER_APP" logs -f service-registry
            ;;
        "api-gateway")
            docker compose -f "$DOCKER_APP" logs -f api-gateway
            ;;
        "notification")
            docker compose -f "$DOCKER_APP" logs -f notification-service
            ;;
        "project")
            docker compose -f "$DOCKER_APP" logs -f project-service
            ;;
        "user")
            docker compose -f "$DOCKER_APP" logs -f user-service
            ;;
        "paper-search")
            docker compose -f "$DOCKER_APP" logs -f paper-search
            ;;
        "extractor")
            docker compose -f "$DOCKER_APP" logs -f extractor
            ;;
        "frontend")
            docker compose -f "$DOCKER_APP" logs -f frontend
            ;;
        "grobid")
            docker compose -f "$DOCKER_SERVICES" logs -f grobid
            ;;
        *)
            echo -e "${RED}Unknown service: $service${NC}"
            echo -e "${YELLOW}Available services: infra, apps, service-registry, api-gateway, notification, project, user, paper-search, extractor, frontend, grobid${NC}"
            return 1
            ;;
    esac
}

###############################################################################
# Build and Clean
###############################################################################
build_all() {
    print_header
    print_step "1" "Building all Docker images..."
    
    cd "$ROOT_DIR"
    
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
        
        cd "$ROOT_DIR"
        
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
    echo -e "  ${GREEN}rebuild-all${NC}   - Rebuild all images and restart complete platform"
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
    echo -e "  ${GREEN}restart [SERVICE]${NC} - Restart specific service (with rebuild)"
    echo -e "  ${GREEN}logs [SERVICE]${NC}  - View logs for specific service"
    echo ""
    echo -e "${BLUE}Available Services:${NC}"
    echo -e "  • service-registry  - Eureka Service Registry"
    echo -e "  • api-gateway       - Spring Cloud Gateway"
    echo -e "  • notification      - Notification Service"
    echo -e "  • project          - Project Service"
    echo -e "  • user             - User Service"
    echo -e "  • paper-search     - Paper Search Service (FastAPI)"
    echo -e "  • extractor        - PDF Extractor Service (FastAPI)"
    echo -e "  • frontend         - Next.js Frontend"
    echo -e "  • grobid           - GROBID PDF Extractor Service"
    echo ""
    echo -e "${BLUE}Utility Commands:${NC}"
    echo -e "  ${GREEN}build-all${NC}     - Build all Docker images"
    echo -e "  ${GREEN}clean-all${NC}     - Remove all containers, images, and volumes"
    echo -e "  ${GREEN}help${NC}          - Show this help message"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo -e "  $0 start-all                    # Start everything"
    echo -e "  $0 rebuild-all                  # Rebuild all images and restart"
    echo -e "  $0 start infra                  # Start only infrastructure"
    echo -e "  $0 start apps                   # Start only applications"
    echo -e "  $0 start service-registry       # Start specific service"
    echo -e "  $0 restart frontend             # Restart frontend with rebuild"
    echo -e "  $0 restart project              # Restart project service with rebuild"
    echo -e "  $0 logs api-gateway             # View API Gateway logs"
    echo -e "  $0 logs paper-search            # View Paper Search logs"
    echo -e "  $0 logs extractor               # View PDF Extractor logs"
    echo -e "  $0 logs grobid                  # View GROBID logs"
    echo -e "  $0 status                       # Show platform status"
}

###############################################################################
# CLI entrypoint
###############################################################################
case "$1" in
    "start-all")           start_all ;;
    "stop-all")            stop_all ;;
    "restart-all")         restart_all ;;
    "rebuild-all")         rebuild_all ;;
    "start")               start_service "$2" ;;
    "stop")                stop_service "$2" ;;
    "restart")             restart_service "$2" ;;
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
