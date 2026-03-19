#!/bin/bash
# Deployment script for TensorFlow serving
# Production-ready deployment automation

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Parse arguments
parse_args() {
    local env="development"
    local scale=1
    local profile="cpu"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --env)
                env="$2"
                shift 2
                ;;
            --scale)
                scale="$2"
                shift 2
                ;;
            --profile)
                profile="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    echo "$env $scale $profile"
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Deploy TensorFlow serving stack"
    echo ""
    echo "Options:"
    echo "  --env ENV      Deployment environment: development, staging, production (default: development)"
    echo "  --scale N      Number of replicas (default: 1)"
    echo "  --profile TYPE Deployment profile: cpu, gpu, full (default: cpu)"
    echo "  --help         Show this help message"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    log_info "Docker: $(docker --version | head -n1)"
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed"
        exit 1
    fi
    
    # Check for compose v2
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
        log_info "Using Docker Compose v2"
    else
        COMPOSE_CMD="docker-compose"
        log_info "Using Docker Compose v1"
    fi
}

# Load environment configuration
load_env_config() {
    local env=$1
    
    log_step "Loading environment configuration: $env"
    
    # Check for environment file
    local env_file=".env.$env"
    if [ -f "$env_file" ]; then
        log_info "Loading environment from $env_file"
        set -a
        source "$env_file"
        set +a
    else
        log_warn "Environment file $env_file not found, using defaults"
    fi
    
    # Set default environment variables
    export DEPLOY_ENV=${DEPLOY_ENV:-$env}
    export COMPOSE_PROJECT_NAME=${COMPOSE_PROJECT_NAME:-"tensorflow-serving-$env"}
}

# Build images if needed
build_images() {
    local profile=$1
    
    log_step "Building Docker images..."
    
    case $profile in
        "cpu")
            log_info "Building CPU images..."
            ./scripts/build.sh --type cpu --tag tensorflow-serving:cpu
            ;;
        "gpu")
            log_info "Building GPU images..."
            ./scripts/build.sh --type gpu --tag tensorflow-serving:gpu
            ;;
        "full")
            log_info "Building all images..."
            ./scripts/build.sh --type cpu --tag tensorflow-serving:cpu
            ./scripts/build.sh --type gpu --tag tensorflow-serving:gpu
            ;;
    esac
}

# Deploy stack
deploy_stack() {
    local env=$1
    local scale=$2
    local profile=$3
    
    log_step "Deploying stack..."
    
    # Determine compose profiles
    local compose_profiles=""
    case $profile in
        "gpu")
            compose_profiles="--profile gpu"
            ;;
        "full")
            compose_profiles="--profile gpu --profile monitoring"
            ;;
    esac
    
    # Start services
    log_info "Starting services with $scale replicas..."
    
    if [ "$scale" -gt 1 ]; then
        # For multiple replicas, we need to use swarm mode
        if docker node ls &> /dev/null; then
            log_info "Docker Swarm detected, deploying in swarm mode"
            deploy_swarm "$env" "$scale" "$compose_profiles"
        else
            log_warn "Multiple replicas requested but Docker Swarm not available"
            log_info "Starting single instance instead"
            $COMPOSE_CMD up -d $compose_profiles
        fi
    else
        # Single instance deployment
        $COMPOSE_CMD up -d $compose_profiles
    fi
    
    log_info "Services started successfully"
}

# Deploy with Docker Swarm
deploy_swarm() {
    local env=$1
    local scale=$2
    local profiles=$3
    
    log_info "Deploying to Docker Swarm..."
    
    # Deploy stack
    $COMPOSE_CMD $profiles config | docker stack deploy -c - "$COMPOSE_PROJECT_NAME"
    
    # Scale services
    docker service scale "${COMPOSE_PROJECT_NAME}_tensorflow-serving-cpu=$scale"
    
    if [[ "$profiles" == *"gpu"* ]]; then
        docker service scale "${COMPOSE_PROJECT_NAME}_tensorflow-serving-gpu=$scale"
    fi
}

# Wait for services to be healthy
wait_for_services() {
    log_step "Waiting for services to be healthy..."
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Health check attempt $attempt/$max_attempts"
        
        # Check TensorFlow serving health
        if curl -s -f http://localhost:8501/health > /dev/null 2>&1; then
            log_info "✓ TensorFlow serving is healthy"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_error "✗ Services failed to become healthy"
            show_service_status
            exit 1
        fi
        
        sleep 5
        attempt=$((attempt + 1))
    done
    
    # Check additional services if monitoring is enabled
    if [[ "$COMPOSE_PROFILES" == *"monitoring"* ]]; then
        check_monitoring_services
    fi
}

# Check monitoring services
check_monitoring_services() {
    log_info "Checking monitoring services..."
    
    # Check Prometheus
    if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
        log_info "✓ Prometheus is healthy"
    else
        log_warn "✗ Prometheus health check failed"
    fi
    
    # Check Grafana
    if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
        log_info "✓ Grafana is healthy"
    else
        log_warn "✗ Grafana health check failed"
    fi
}

# Show service status
show_service_status() {
    log_step "Service status:"
    
    # Docker Compose services
    $COMPOSE_CMD ps
    
    # Show logs for any failed services
    log_info "Checking for service failures..."
    $COMPOSE_CMD ps --filter "status=exited" | grep -v "NAME" | while read line; do
        service=$(echo "$line" | awk '{print $1}')
        log_error "Service $service has exited"
        log_info "Logs for $service:"
        $COMPOSE_CMD logs "$service" | tail -20
    done
}

# Main deployment function
main() {
    log_step "Starting TensorFlow serving deployment"
    
    # Parse arguments
    read -r env scale profile <<< "$(parse_args "$@")"
    
    log_info "Environment: $env"
    log_info "Scale: $scale"
    log_info "Profile: $profile"
    
    # Check prerequisites
    check_prerequisites
    
    # Load environment configuration
    load_env_config "$env"
    
    # Build images
    build_images "$profile"
    
    # Deploy stack
    deploy_stack "$env" "$scale" "$profile"
    
    # Wait for services
    wait_for_services
    
    # Show final status
    show_service_status
    
    log_step "Deployment completed successfully!"
    
    # Show access information
    echo ""
    echo "Access URLs:"
    echo "  TensorFlow Serving: http://localhost:8501"
    echo "  Prometheus:         http://localhost:9090"
    echo "  Grafana:            http://localhost:3000 (admin/admin)"
    echo ""
    echo "To view logs:"
    echo "  $COMPOSE_CMD logs -f"
    echo ""
    echo "To scale services:"
    echo "  $COMPOSE_CMD up -d --scale tensorflow-serving-cpu=N"
}

# Run main function
main "$@"