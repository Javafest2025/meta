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
DOCKER_SERVICES="$ROOT_DIR/Docker/services.yml"
DOCKER_ENV="$ROOT_DIR/Docker/.env"

# Individual service docker-compose file paths
SERVICE_REGISTRY_COMPOSE="$ROOT_DIR/Microservices/service-registry/docker-compose.yml"
API_GATEWAY_COMPOSE="$ROOT_DIR/Microservices/api-gateway/docker-compose.yml"
NOTIFICATION_COMPOSE="$ROOT_DIR/Microservices/notification-service/docker-compose.yml"
PROJECT_COMPOSE="$ROOT_DIR/Microservices/project-service/docker-compose.yml"
USER_COMPOSE="$ROOT_DIR/Microservices/user-service/docker-compose.yml"
PAPER_SEARCH_COMPOSE="$ROOT_DIR/AI-Agents/paper-search/docker-compose.yml"
EXTRACTOR_COMPOSE="$ROOT_DIR/AI-Agents/extractor/docker-compose.yml"
GAP_ANALYZER_COMPOSE="$ROOT_DIR/AI-Agents/gap-analyzer/docker-compose.yml"
FRONTEND_COMPOSE="$ROOT_DIR/Frontend/docker-compose.yml"

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
    echo -e "${PURPLE}║                    ScholarAI Platform Control                ║${NC}"
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
    
    # 1. Service Registry
    print_step "2.1" "Starting Service Registry..."
    cd "$ROOT_DIR/Microservices/service-registry"
    if docker compose -f "$SERVICE_REGISTRY_COMPOSE" up -d; then
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
    cd "$ROOT_DIR/Microservices/api-gateway"
    if docker compose -f "$API_GATEWAY_COMPOSE" up -d; then
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
    cd "$ROOT_DIR/Microservices/notification-service"
    if docker compose -f "$NOTIFICATION_COMPOSE" up -d; then
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
    cd "$ROOT_DIR/Microservices/project-service"
    if docker compose -f "$PROJECT_COMPOSE" up -d; then
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
    cd "$ROOT_DIR/Microservices/user-service"
    if docker compose -f "$USER_COMPOSE" up -d; then
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
    cd "$ROOT_DIR/AI-Agents/paper-search"
    if docker compose -f "$PAPER_SEARCH_COMPOSE" up -d; then
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
    cd "$ROOT_DIR/AI-Agents/extractor"
    if docker compose -f "$EXTRACTOR_COMPOSE" up -d; then
        echo -e "${GREEN}✓ PDF Extractor Service started${NC}"
        if ! wait_for_service "PDF Extractor Service" "8002"; then
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to start PDF Extractor Service${NC}"
        return 1
    fi
    
    # 8. Gap Analyzer Service
    print_step "2.8" "Starting Gap Analyzer Service..."
    cd "$ROOT_DIR/AI-Agents/gap-analyzer"
    if docker compose -f "$GAP_ANALYZER_COMPOSE" up -d; then
        echo -e "${GREEN}✓ Gap Analyzer Service started${NC}"
        if ! wait_for_service "Gap Analyzer Service" "8003"; then
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to start Gap Analyzer Service${NC}"
        return 1
    fi
    
    # 9. Frontend
    print_step "2.9" "Starting Frontend..."
    cd "$ROOT_DIR/Frontend"
    if docker compose -f "$FRONTEND_COMPOSE" up -d; then
        echo -e "${GREEN}✓ Frontend started${NC}"
        if ! wait_for_frontend; then
            return 1
        fi
    else
        echo -e "${RED}✗ Failed to start Frontend${NC}"
        return 1
    fi
    
    # 9. NGINX Proxy
    print_step "2.9" "Starting NGINX Proxy..."
    if docker compose -f "$DOCKER_APP" up -d nginx-proxy; then
        echo -e "${GREEN}✓ NGINX Proxy started${NC}"
        echo -e "${GREEN}✓ Platform accessible at http://localhost${NC}"
    else
        echo -e "${RED}✗ Failed to start NGINX Proxy${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ All application services started successfully!${NC}"
    return 0
}

stop_applications() {
    print_step "2" "Stopping application services..."
    
    # Stop services in reverse order
    local services=(
        "Frontend:$ROOT_DIR/Frontend:$FRONTEND_COMPOSE"
        "Gap Analyzer:$ROOT_DIR/AI-Agents/gap-analyzer:$GAP_ANALYZER_COMPOSE"
        "PDF Extractor:$ROOT_DIR/AI-Agents/extractor:$EXTRACTOR_COMPOSE"
        "Paper Search:$ROOT_DIR/AI-Agents/paper-search:$PAPER_SEARCH_COMPOSE"
        "User Service:$ROOT_DIR/Microservices/user-service:$USER_COMPOSE"
        "Project Service:$ROOT_DIR/Microservices/project-service:$PROJECT_COMPOSE"
        "Notification Service:$ROOT_DIR/Microservices/notification-service:$NOTIFICATION_COMPOSE"
        "API Gateway:$ROOT_DIR/Microservices/api-gateway:$API_GATEWAY_COMPOSE"
        "Service Registry:$ROOT_DIR/Microservices/service-registry:$SERVICE_REGISTRY_COMPOSE"
    )
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service_name service_dir compose_file <<< "$service_info"
        echo -e "${CYAN}Stopping $service_name...${NC}"
        cd "$service_dir"
        if docker compose -f "$compose_file" down; then
            echo -e "${GREEN}✓ $service_name stopped${NC}"
        else
            echo -e "${YELLOW}⚠ $service_name stop failed (may not be running)${NC}"
        fi
    done
    
    echo -e "${GREEN}✓ Application services stopped successfully!${NC}"
    return 0
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
            cd "$ROOT_DIR/Microservices/service-registry"
            docker compose -f "$SERVICE_REGISTRY_COMPOSE" up -d
            ;;
        "api-gateway")
            echo -e "${CYAN}Starting API Gateway...${NC}"
            cd "$ROOT_DIR/Microservices/api-gateway"
            docker compose -f "$API_GATEWAY_COMPOSE" up -d
            ;;
        "notification")
            echo -e "${CYAN}Starting Notification Service...${NC}"
            cd "$ROOT_DIR/Microservices/notification-service"
            docker compose -f "$NOTIFICATION_COMPOSE" up -d
            ;;
        "project")
            echo -e "${CYAN}Starting Project Service...${NC}"
            cd "$ROOT_DIR/Microservices/project-service"
            docker compose -f "$PROJECT_COMPOSE" up -d
            ;;
        "user")
            echo -e "${CYAN}Starting User Service...${NC}"
            cd "$ROOT_DIR/Microservices/user-service"
            docker compose -f "$USER_COMPOSE" up -d
            ;;
        "paper-search")
            echo -e "${CYAN}Starting Paper Search Service...${NC}"
            cd "$ROOT_DIR/AI-Agents/paper-search"
            docker compose -f "$PAPER_SEARCH_COMPOSE" up -d
            ;;
        "extractor")
            echo -e "${CYAN}Starting PDF Extractor Service...${NC}"
            cd "$ROOT_DIR/AI-Agents/extractor"
            docker compose -f "$EXTRACTOR_COMPOSE" up -d
            ;;
        "gap-analyzer")
            echo -e "${CYAN}Starting Gap Analyzer Service...${NC}"
            cd "$ROOT_DIR/AI-Agents/gap-analyzer"
            docker compose -f "$GAP_ANALYZER_COMPOSE" up -d
            ;;
        "frontend")
            echo -e "${CYAN}Starting Frontend...${NC}"
            cd "$ROOT_DIR/Frontend"
            docker compose -f "$FRONTEND_COMPOSE" up -d
            ;;
        "nginx"|"nginx-proxy")
            echo -e "${CYAN}Starting NGINX Proxy...${NC}"
            docker compose -f "$DOCKER_APP" up -d nginx-proxy
            ;;
        "grobid")
            echo -e "${CYAN}Starting GROBID PDF Extractor...${NC}"
            docker compose -f "$DOCKER_SERVICES" up -d grobid
            ;;
        *)
            echo -e "${RED}Unknown service: $service${NC}"
            echo -e "${YELLOW}Available services: infra, apps, service-registry, api-gateway, notification, project, user, paper-search, extractor, gap-analyzer, frontend, grobid${NC}"
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
            cd "$ROOT_DIR/Microservices/service-registry"
            docker compose -f "$SERVICE_REGISTRY_COMPOSE" down
            docker compose -f "$SERVICE_REGISTRY_COMPOSE" build
            docker compose -f "$SERVICE_REGISTRY_COMPOSE" up -d
            ;;
        "api-gateway")
            echo -e "${CYAN}Restarting API Gateway (with rebuild)...${NC}"
            cd "$ROOT_DIR/Microservices/api-gateway"
            docker compose -f "$API_GATEWAY_COMPOSE" down
            docker compose -f "$API_GATEWAY_COMPOSE" build
            docker compose -f "$API_GATEWAY_COMPOSE" up -d
            ;;
        "notification")
            echo -e "${CYAN}Restarting Notification Service (with rebuild)...${NC}"
            cd "$ROOT_DIR/Microservices/notification-service"
            docker compose -f "$NOTIFICATION_COMPOSE" down
            docker compose -f "$NOTIFICATION_COMPOSE" build
            docker compose -f "$NOTIFICATION_COMPOSE" up -d
            ;;
        "project")
            echo -e "${CYAN}Restarting Project Service (with rebuild)...${NC}"
            cd "$ROOT_DIR/Microservices/project-service"
            docker compose -f "$PROJECT_COMPOSE" down
            docker compose -f "$PROJECT_COMPOSE" build
            docker compose -f "$PROJECT_COMPOSE" up -d
            ;;
        "user")
            echo -e "${CYAN}Restarting User Service (with rebuild)...${NC}"
            cd "$ROOT_DIR/Microservices/user-service"
            docker compose -f "$USER_COMPOSE" down
            docker compose -f "$USER_COMPOSE" build
            docker compose -f "$USER_COMPOSE" up -d
            ;;
        "paper-search")
            echo -e "${CYAN}Restarting Paper Search Service (with rebuild)...${NC}"
            cd "$ROOT_DIR/AI-Agents/paper-search"
            docker compose -f "$PAPER_SEARCH_COMPOSE" down
            docker compose -f "$PAPER_SEARCH_COMPOSE" build
            docker compose -f "$PAPER_SEARCH_COMPOSE" up -d
            ;;
        "extractor")
            echo -e "${CYAN}Restarting PDF Extractor Service (with rebuild)...${NC}"
            cd "$ROOT_DIR/AI-Agents/extractor"
            docker compose -f "$EXTRACTOR_COMPOSE" down
            docker compose -f "$EXTRACTOR_COMPOSE" build
            docker compose -f "$EXTRACTOR_COMPOSE" up -d
            ;;
        "gap-analyzer")
            echo -e "${CYAN}Restarting Gap Analyzer Service (with rebuild)...${NC}"
            cd "$ROOT_DIR/AI-Agents/gap-analyzer"
            docker compose -f "$GAP_ANALYZER_COMPOSE" down
            docker compose -f "$GAP_ANALYZER_COMPOSE" build
            docker compose -f "$GAP_ANALYZER_COMPOSE" up -d
            ;;
        "frontend")
            echo -e "${CYAN}Restarting Frontend (with rebuild)...${NC}"
            cd "$ROOT_DIR/Frontend"
            docker compose -f "$FRONTEND_COMPOSE" down
            docker compose -f "$FRONTEND_COMPOSE" build
            docker compose -f "$FRONTEND_COMPOSE" up -d
            ;;
        "nginx"|"nginx-proxy")
            echo -e "${CYAN}Restarting NGINX Proxy (with config reload)...${NC}"
            docker compose -f "$DOCKER_APP" stop nginx-proxy
            docker compose -f "$DOCKER_APP" build nginx-proxy
            docker compose -f "$DOCKER_APP" up -d nginx-proxy
            ;;
        "grobid")
            echo -e "${CYAN}Restarting GROBID PDF Extractor (with rebuild)...${NC}"
            docker compose -f "$DOCKER_SERVICES" stop grobid
            docker compose -f "$DOCKER_SERVICES" build grobid
            docker compose -f "$DOCKER_SERVICES" up -d grobid
            ;;
        *)
            echo -e "${RED}Unknown service: $service${NC}"
            echo -e "${YELLOW}Available services: infra, apps, service-registry, api-gateway, notification, project, user, paper-search, extractor, frontend, nginx, grobid${NC}"
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
            cd "$ROOT_DIR/Microservices/service-registry"
            docker compose -f "$SERVICE_REGISTRY_COMPOSE" down
            ;;
        "api-gateway")
            echo -e "${CYAN}Stopping API Gateway...${NC}"
            cd "$ROOT_DIR/Microservices/api-gateway"
            docker compose -f "$API_GATEWAY_COMPOSE" down
            ;;
        "notification")
            echo -e "${CYAN}Stopping Notification Service...${NC}"
            cd "$ROOT_DIR/Microservices/notification-service"
            docker compose -f "$NOTIFICATION_COMPOSE" down
            ;;
        "project")
            echo -e "${CYAN}Stopping Project Service...${NC}"
            cd "$ROOT_DIR/Microservices/project-service"
            docker compose -f "$PROJECT_COMPOSE" down
            ;;
        "user")
            echo -e "${CYAN}Stopping User Service...${NC}"
            cd "$ROOT_DIR/Microservices/user-service"
            docker compose -f "$USER_COMPOSE" down
            ;;
        "paper-search")
            echo -e "${CYAN}Stopping Paper Search Service...${NC}"
            cd "$ROOT_DIR/AI-Agents/paper-search"
            docker compose -f "$PAPER_SEARCH_COMPOSE" down
            ;;
        "extractor")
            echo -e "${CYAN}Stopping PDF Extractor Service...${NC}"
            cd "$ROOT_DIR/AI-Agents/extractor"
            docker compose -f "$EXTRACTOR_COMPOSE" down
            ;;
        "gap-analyzer")
            echo -e "${CYAN}Stopping Gap Analyzer Service...${NC}"
            cd "$ROOT_DIR/AI-Agents/gap-analyzer"
            docker compose -f "$GAP_ANALYZER_COMPOSE" down
            ;;
        "frontend")
            echo -e "${CYAN}Stopping Frontend...${NC}"
            cd "$ROOT_DIR/Frontend"
            docker compose -f "$FRONTEND_COMPOSE" down
            ;;
        "nginx"|"nginx-proxy")
            echo -e "${CYAN}Stopping NGINX Proxy...${NC}"
            docker compose -f "$DOCKER_APP" stop nginx-proxy
            ;;
        "grobid")
            echo -e "${CYAN}Stopping GROBID PDF Extractor...${NC}"
            docker compose -f "$DOCKER_SERVICES" stop grobid
            ;;
        *)
            echo -e "${RED}Unknown service: $service${NC}"
            echo -e "${YELLOW}Available services: infra, apps, service-registry, api-gateway, notification, project, user, paper-search, extractor, frontend, nginx, grobid${NC}"
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
    echo -e "${GREEN}• Main Platform:${NC} http://localhost (via NGINX Proxy)"
    echo -e "${GREEN}• Frontend:${NC} http://localhost:3000 (direct access)"
    echo -e "${GREEN}• API Gateway:${NC} http://localhost:8989 (direct access)"
    echo -e "${GREEN}• Service Registry:${NC} http://localhost:8761"
    echo -e "${GREEN}• Paper Search Service:${NC} http://localhost:8001"
    echo -e "${GREEN}• PDF Extractor Service:${NC} http://localhost:8002"
    echo -e "${GREEN}• Gap Analyzer Service:${NC} http://localhost:8003"
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
    local services=(
        "Service Registry:$ROOT_DIR/Microservices/service-registry:$SERVICE_REGISTRY_COMPOSE"
        "API Gateway:$ROOT_DIR/Microservices/api-gateway:$API_GATEWAY_COMPOSE"
        "Notification Service:$ROOT_DIR/Microservices/notification-service:$NOTIFICATION_COMPOSE"
        "Project Service:$ROOT_DIR/Microservices/project-service:$PROJECT_COMPOSE"
        "User Service:$ROOT_DIR/Microservices/user-service:$USER_COMPOSE"
        "Paper Search:$ROOT_DIR/AI-Agents/paper-search:$PAPER_SEARCH_COMPOSE"
        "PDF Extractor:$ROOT_DIR/AI-Agents/extractor:$EXTRACTOR_COMPOSE"
        "Gap Analyzer:$ROOT_DIR/AI-Agents/gap-analyzer:$GAP_ANALYZER_COMPOSE"
        "Frontend:$ROOT_DIR/Frontend:$FRONTEND_COMPOSE"
    )
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service_name service_dir compose_file <<< "$service_info"
        echo -e "\n${CYAN}$service_name:${NC}"
        cd "$service_dir"
        docker compose -f "$compose_file" ps
    done
    
    # Health check status
    echo -e "\n${BLUE}Service Health Status:${NC}"
    print_service_status "Service Registry" "8761"
    print_service_status "API Gateway" "8989"
    print_service_status "Notification Service" "8082"
    print_service_status "Project Service" "8083"
    print_service_status "User Service" "8081"
    print_service_status "Paper Search Service" "8001"
    print_service_status "PDF Extractor Service" "8002"
    print_service_status "Gap Analyzer Service" "8003"
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
    echo -e "${GREEN}• PDF Extractor Service:${NC} http://localhost:8002"
    echo -e "${GREEN}• Gap Analyzer Service:${NC} http://localhost:8003"
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
            echo -e "${CYAN}Viewing logs for all application services...${NC}"
            local services=(
                "Service Registry:$ROOT_DIR/Microservices/service-registry:$SERVICE_REGISTRY_COMPOSE"
                "API Gateway:$ROOT_DIR/Microservices/api-gateway:$API_GATEWAY_COMPOSE"
                "Notification Service:$ROOT_DIR/Microservices/notification-service:$NOTIFICATION_COMPOSE"
                "Project Service:$ROOT_DIR/Microservices/project-service:$PROJECT_COMPOSE"
                "User Service:$ROOT_DIR/Microservices/user-service:$USER_COMPOSE"
                "Paper Search:$ROOT_DIR/AI-Agents/paper-search:$PAPER_SEARCH_COMPOSE"
                "PDF Extractor:$ROOT_DIR/AI-Agents/extractor:$EXTRACTOR_COMPOSE"
                "Gap Analyzer:$ROOT_DIR/AI-Agents/gap-analyzer:$GAP_ANALYZER_COMPOSE"
                "Frontend:$ROOT_DIR/Frontend:$FRONTEND_COMPOSE"
            )
            
            for service_info in "${services[@]}"; do
                IFS=':' read -r service_name service_dir compose_file <<< "$service_info"
                echo -e "\n${YELLOW}=== $service_name Logs ===${NC}"
                cd "$service_dir"
                docker compose -f "$compose_file" logs --tail=50
            done
            ;;
        "service-registry")
            cd "$ROOT_DIR/Microservices/service-registry"
            docker compose -f "$SERVICE_REGISTRY_COMPOSE" logs -f
            ;;
        "api-gateway")
            cd "$ROOT_DIR/Microservices/api-gateway"
            docker compose -f "$API_GATEWAY_COMPOSE" logs -f
            ;;
        "notification")
            cd "$ROOT_DIR/Microservices/notification-service"
            docker compose -f "$NOTIFICATION_COMPOSE" logs -f
            ;;
        "project")
            cd "$ROOT_DIR/Microservices/project-service"
            docker compose -f "$PROJECT_COMPOSE" logs -f
            ;;
        "user")
            cd "$ROOT_DIR/Microservices/user-service"
            docker compose -f "$USER_COMPOSE" logs -f
            ;;
        "paper-search")
            cd "$ROOT_DIR/AI-Agents/paper-search"
            docker compose -f "$PAPER_SEARCH_COMPOSE" logs -f
            ;;
        "extractor")
            cd "$ROOT_DIR/AI-Agents/extractor"
            docker compose -f "$EXTRACTOR_COMPOSE" logs -f
            ;;
        "gap-analyzer")
            cd "$ROOT_DIR/AI-Agents/gap-analyzer"
            docker compose -f "$GAP_ANALYZER_COMPOSE" logs -f
            ;;
        "frontend")
            cd "$ROOT_DIR/Frontend"
            docker compose -f "$FRONTEND_COMPOSE" logs -f
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
    
    # Build infrastructure (if needed)
    echo -e "${CYAN}Building infrastructure images...${NC}"
    cd "$ROOT_DIR"
    docker compose -f "$DOCKER_SERVICES" build
    
    # Build applications
    echo -e "${CYAN}Building application images...${NC}"
    local services=(
        "Service Registry:$ROOT_DIR/Microservices/service-registry:$SERVICE_REGISTRY_COMPOSE"
        "API Gateway:$ROOT_DIR/Microservices/api-gateway:$API_GATEWAY_COMPOSE"
        "Notification Service:$ROOT_DIR/Microservices/notification-service:$NOTIFICATION_COMPOSE"
        "Project Service:$ROOT_DIR/Microservices/project-service:$PROJECT_COMPOSE"
        "User Service:$ROOT_DIR/Microservices/user-service:$USER_COMPOSE"
        "Paper Search:$ROOT_DIR/AI-Agents/paper-search:$PAPER_SEARCH_COMPOSE"
        "PDF Extractor:$ROOT_DIR/AI-Agents/extractor:$EXTRACTOR_COMPOSE"
        "Gap Analyzer:$ROOT_DIR/AI-Agents/gap-analyzer:$GAP_ANALYZER_COMPOSE"
        "Frontend:$ROOT_DIR/Frontend:$FRONTEND_COMPOSE"
    )
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service_name service_dir compose_file <<< "$service_info"
        echo -e "${CYAN}Building $service_name...${NC}"
        cd "$service_dir"
        docker compose -f "$compose_file" build
    done
    
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
        
        # Clean individual application services
        local services=(
            "Service Registry:$ROOT_DIR/Microservices/service-registry:$SERVICE_REGISTRY_COMPOSE"
            "API Gateway:$ROOT_DIR/Microservices/api-gateway:$API_GATEWAY_COMPOSE"
            "Notification Service:$ROOT_DIR/Microservices/notification-service:$NOTIFICATION_COMPOSE"
            "Project Service:$ROOT_DIR/Microservices/project-service:$PROJECT_COMPOSE"
            "User Service:$ROOT_DIR/Microservices/user-service:$USER_COMPOSE"
            "Paper Search:$ROOT_DIR/AI-Agents/paper-search:$PAPER_SEARCH_COMPOSE"
            "PDF Extractor:$ROOT_DIR/AI-Agents/extractor:$EXTRACTOR_COMPOSE"
            "Gap Analyzer:$ROOT_DIR/AI-Agents/gap-analyzer:$GAP_ANALYZER_COMPOSE"
            "Frontend:$ROOT_DIR/Frontend:$FRONTEND_COMPOSE"
        )
        
        for service_info in "${services[@]}"; do
            IFS=':' read -r service_name service_dir compose_file <<< "$service_info"
            echo -e "${CYAN}Cleaning $service_name...${NC}"
            cd "$service_dir"
            docker compose -f "$compose_file" down --rmi all --volumes --remove-orphans
        done
        
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
    echo -e "  • gap-analyzer     - Gap Analyzer Service (FastAPI)"
    echo -e "  • frontend         - Next.js Frontend"
    echo -e "  • nginx            - NGINX Reverse Proxy (SSE Support)"
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
