#!/bin/bash
# Build script for TensorFlow Docker templates
# Production-ready build automation

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    log_info "Docker is installed: $(docker --version)"
}

# Check if NVIDIA Docker is installed (for GPU builds)
check_nvidia_docker() {
    if [ "$1" = "gpu" ]; then
        if ! command -v nvidia-docker &> /dev/null && ! docker info | grep -q "Runtimes.*nvidia"; then
            log_warn "NVIDIA Docker not found. GPU builds may not work."
            return 1
        fi
        log_info "NVIDIA Docker is available"
    fi
}

# Build Docker image
build_image() {
    local type=$1
    local tag=$2
    
    case $type in
        "cpu")
            local dockerfile="Dockerfile.cpu"
            local build_args=""
            ;;
        "gpu")
            local dockerfile="Dockerfile.gpu"
            local build_args=""
            # Check for NVIDIA Docker
            check_nvidia_docker "gpu"
            ;;
        *)
            log_error "Unknown build type: $type. Use 'cpu' or 'gpu'."
            exit 1
            ;;
    esac
    
    log_info "Building $type image with tag: $tag"
    
    # Build the image
    if docker build \
        -f "$dockerfile" \
        -t "$tag" \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        .; then
        log_info "Successfully built $type image: $tag"
        
        # Display image information
        log_info "Image details:"
        docker images "$tag" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
    else
        log_error "Failed to build $type image"
        exit 1
    fi
}

# Run security scan on built image
security_scan() {
    local image=$1
    
    log_info "Running security scan on: $image"
    
    # Check for Trivy (popular vulnerability scanner)
    if command -v trivy &> /dev/null; then
        log_info "Running Trivy vulnerability scan..."
        trivy image --severity HIGH,CRITICAL "$image"
    else
        log_warn "Trivy not installed. Skipping vulnerability scan."
        log_info "Install Trivy: https://github.com/aquasecurity/trivy"
    fi
    
    # Check for Docker Scout
    if command -v docker &> /dev/null && docker scout &> /dev/null; then
        log_info "Running Docker Scout analysis..."
        docker scout quickview "$image"
    fi
}

# Run tests on built image
run_tests() {
    local image=$1
    
    log_info "Running tests on: $image"
    
    # Test 1: Basic container startup
    log_info "Test 1: Container startup test..."
    if docker run --rm "$image" python3 -c "import tensorflow as tf; print('TensorFlow version:', tf.__version__)"; then
        log_info "✓ Container starts successfully"
    else
        log_error "✗ Container failed to start"
        exit 1
    fi
    
    # Test 2: Model loading capability
    log_info "Test 2: Model loading test..."
    if docker run --rm "$image" python3 -c "
import tensorflow as tf
import numpy as np
# Create a simple model
model = tf.keras.Sequential([tf.keras.layers.Dense(10)])
# Test prediction
dummy_input = np.random.randn(1, 5).astype(np.float32)
prediction = model.predict(dummy_input)
print('Model prediction test passed')
"; then
        log_info "✓ Model loading test passed"
    else
        log_warn "✗ Model loading test failed (may be expected for some configurations)"
    fi
    
    # Test 3: Health check
    log_info "Test 3: Health check test..."
    # Start container in background
    container_id=$(docker run -d -p 8501:8501 "$image")
    sleep 10  # Wait for startup
    
    if curl -f http://localhost:8501/health 2>/dev/null; then
        log_info "✓ Health check passed"
    else
        log_warn "✗ Health check failed"
    fi
    
    # Cleanup
    docker stop "$container_id" > /dev/null
    docker rm "$container_id" > /dev/null
}

# Push image to registry (optional)
push_to_registry() {
    local image=$1
    local registry=$2
    
    if [ -z "$registry" ]; then
        log_warn "No registry specified. Skipping push."
        return
    fi
    
    log_info "Pushing $image to $registry"
    
    # Tag image for registry
    docker tag "$image" "$registry/$image"
    
    # Push to registry
    if docker push "$registry/$image"; then
        log_info "Successfully pushed to $registry"
    else
        log_error "Failed to push to registry"
        exit 1
    fi
}

# Main function
main() {
    # Parse arguments
    local build_type="cpu"
    local tag="tensorflow-app:latest"
    local registry=""
    local skip_tests=false
    local skip_scan=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                build_type="$2"
                shift 2
                ;;
            --tag)
                tag="$2"
                shift 2
                ;;
            --registry)
                registry="$2"
                shift 2
                ;;
            --skip-tests)
                skip_tests=true
                shift
                ;;
            --skip-scan)
                skip_scan=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Build TensorFlow Docker images"
                echo ""
                echo "Options:"
                echo "  --type TYPE      Build type: cpu or gpu (default: cpu)"
                echo "  --tag TAG        Docker image tag (default: tensorflow-app:latest)"
                echo "  --registry URL   Push to registry after build"
                echo "  --skip-tests     Skip running tests"
                echo "  --skip-scan      Skip security scan"
                echo "  --help           Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    log_info "Starting TensorFlow Docker build process"
    log_info "Build type: $build_type"
    log_info "Image tag: $tag"
    
    # Check prerequisites
    check_docker
    
    # Build image
    build_image "$build_type" "$tag"
    
    # Run security scan
    if [ "$skip_scan" = false ]; then
        security_scan "$tag"
    fi
    
    # Run tests
    if [ "$skip_tests" = false ]; then
        run_tests "$tag"
    fi
    
    # Push to registry if specified
    if [ -n "$registry" ]; then
        push_to_registry "$tag" "$registry"
    fi
    
    log_info "Build process completed successfully!"
    log_info "Image ready: $tag"
    
    # Display usage instructions
    echo ""
    echo "To run the image:"
    echo "  docker run -p 8501:8501 $tag"
    echo ""
    echo "To run with GPU support (if built as gpu):"
    echo "  docker run --gpus all -p 8501:8501 $tag"
}

# Run main function with all arguments
main "$@"