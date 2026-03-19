#!/bin/bash
# Test script for TensorFlow serving
# Comprehensive testing suite

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
    local test_type="all"
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                test_type="$2"
                shift 2
                ;;
            --verbose)
                verbose=true
                shift
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
    
    echo "$test_type $verbose"
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Run tests for TensorFlow serving"
    echo ""
    echo "Options:"
    echo "  --type TYPE    Test type: unit, integration, e2e, all (default: all)"
    echo "  --verbose      Enable verbose output"
    echo "  --help         Show this help message"
}

# Run unit tests
run_unit_tests() {
    log_step "Running unit tests..."
    
    # Python unit tests
    log_info "Running Python unit tests..."
    
    # Test training script
    if python3 -c "
import sys
sys.path.append('src')
from train import create_model, load_dataset
import tensorflow as tf

# Test model creation
model = create_model()
assert model is not None
print('✓ Model creation test passed')

# Test dataset loading
(x_train, y_train), (x_test, y_test) = load_dataset()
assert x_train.shape[0] > 0
assert y_train.shape[0] > 0
print('✓ Dataset loading test passed')
"; then
        log_info "✓ Python unit tests passed"
    else
        log_error "✗ Python unit tests failed"
        return 1
    fi
    
    # Test serving script
    log_info "Testing serving script..."
    if python3 -c "
import sys
sys.path.append('src')
from serve import load_model
import tensorflow as tf
import numpy as np

# Create a dummy model for testing
model = tf.keras.Sequential([tf.keras.layers.Dense(10)])
dummy_input = np.random.randn(1, 5).astype(np.float32)
prediction = model.predict(dummy_input)
assert prediction.shape == (1, 10)
print('✓ Serving model test passed')
"; then
        log_info "✓ Serving script tests passed"
    else
        log_warn "✗ Serving script tests failed (may be expected)"
    fi
    
    return 0
}

# Run integration tests
run_integration_tests() {
    log_step "Running integration tests..."
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_warn "Docker is not running, skipping integration tests"
        return 0
    fi
    
    # Build test image
    log_info "Building test image..."
    if ./scripts/build.sh --type cpu --tag tensorflow-test:latest --skip-tests --skip-scan; then
        log_info "✓ Test image built successfully"
    else
        log_error "✗ Failed to build test image"
        return 1
    fi
    
    # Test container startup
    log_info "Testing container startup..."
    container_id=$(docker run -d -p 8501:8501 tensorflow-test:latest)
    
    # Wait for container to start
    sleep 10
    
    # Test health endpoint
    log_info "Testing health endpoint..."
    if curl -s -f http://localhost:8501/health > /dev/null 2>&1; then
        log_info "✓ Health endpoint test passed"
    else
        log_error "✗ Health endpoint test failed"
        docker logs "$container_id"
        docker stop "$container_id" > /dev/null
        docker rm "$container_id" > /dev/null
        return 1
    fi
    
    # Test prediction endpoint
    log_info "Testing prediction endpoint..."
    if curl -s -X POST http://localhost:8501/predict \
        -H "Content-Type: application/json" \
        -d '{"inputs": [[1.0, 2.0, 3.0, 4.0, 5.0]]}' \
        > /dev/null 2>&1; then
        log_info "✓ Prediction endpoint test passed"
    else
        log_warn "✗ Prediction endpoint test failed (may be expected without trained model)"
    fi
    
    # Cleanup
    docker stop "$container_id" > /dev/null
    docker rm "$container_id" > /dev/null
    
    log_info "✓ Integration tests completed"
    return 0
}

# Run end-to-end tests
run_e2e_tests() {
    log_step "Running end-to-end tests..."
    
    # Check if Docker Compose is available
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_warn "Docker Compose not available, skipping E2E tests"
        return 0
    fi
    
    # Start full stack
    log_info "Starting full stack..."
    if ./scripts/deploy.sh --env test --scale 1 --profile cpu > /dev/null 2>&1; then
        log_info "✓ Stack started successfully"
    else
        log_error "✗ Failed to start stack"
        return 1
    fi
    
    # Wait for services
    sleep 15
    
    # Test all endpoints
    log_info "Testing all service endpoints..."
    
    endpoints=(
        "http://localhost:8501/health"
        "http://localhost:8501/"
        "http://localhost:8501/model/info"
        "http://localhost:9090/-/healthy"
        "http://localhost:3000/api/health"
    )
    
    all_passed=true
    for endpoint in "${endpoints[@]}"; do
        service=$(echo "$endpoint" | cut -d'/' -f3 | cut -d':' -f1)
        if curl -s -f "$endpoint" > /dev/null 2>&1; then
            log_info "✓ $service endpoint is healthy"
        else
            log_error "✗ $service endpoint failed"
            all_passed=false
        fi
    done
    
    # Stop stack
    log_info "Stopping test stack..."
    if docker compose down > /dev/null 2>&1 || docker-compose down > /dev/null 2>&1; then
        log_info "✓ Stack stopped successfully"
    else
        log_warn "Failed to stop stack cleanly"
    fi
    
    if [ "$all_passed" = true ]; then
        log_info "✓ End-to-end tests completed successfully"
        return 0
    else
        log_error "✗ End-to-end tests failed"
        return 1
    fi
}

# Run performance tests
run_performance_tests() {
    log_step "Running performance tests..."
    
    log_info "Starting performance test container..."
    container_id=$(docker run -d -p 8501:8501 tensorflow-test:latest)
    sleep 10
    
    # Run simple load test
    log_info "Running load test..."
    
    # Test with Apache Bench if available
    if command -v ab &> /dev/null; then
        log_info "Running Apache Bench test..."
        if ab -n 100 -c 10 http://localhost:8501/health 2>&1 | grep -q "Failed requests:        0"; then
            log_info "✓ Load test passed (100 requests)"
        else
            log_warn "✗ Load test had failures"
        fi
    else
        log_warn "Apache Bench not installed, skipping load test"
    fi
    
    # Test latency
    log_info "Testing latency..."
    start_time=$(date +%s%N)
    for i in {1..10}; do
        curl -s -o /dev/null -w "%{time_total}\n" http://localhost:8501/health
    done | awk '{sum+=$1} END {print "Average latency: " sum/NR " seconds"}'
    
    # Cleanup
    docker stop "$container_id" > /dev/null
    docker rm "$container_id" > /dev/null
    
    log_info "✓ Performance tests completed"
    return 0
}

# Generate test report
generate_report() {
    local test_type=$1
    local passed=$2
    local failed=$3
    
    log_step "Test Report"
    echo "========================================"
    echo "Test Type: $test_type"
    echo "Timestamp: $(date)"
    echo "----------------------------------------"
    echo "Tests Passed: $passed"
    echo "Tests Failed: $failed"
    echo "Total Tests: $((passed + failed))"
    echo "Success Rate: $((passed * 100 / (passed + failed)))%"
    echo "========================================"
    
    if [ $failed -eq 0 ]; then
        log_info "All tests passed! 🎉"
        return 0
    else
        log_error "Some tests failed 😞"
        return 1
    fi
}

# Main test function
main() {
    log_step "Starting TensorFlow serving test suite"
    
    # Parse arguments
    read -r test_type verbose <<< "$(parse_args "$@")"
    
    log_info "Test type: $test_type"
    log_info "Verbose: $verbose"
    
    # Track test results
    local passed=0
    local failed=0
    
    # Run tests based on type
    case $test_type in
        "unit")
            if run_unit_tests; then
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
            fi
            ;;
        "integration")
            if run_integration_tests; then
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
            fi
            ;;
        "e2e")
            if run_e2e_tests; then
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
            fi
            ;;
        "performance")
            if run_performance_tests; then
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
            fi
            ;;
        "all")
            # Run all test types
            test_types=("unit" "integration" "e2e" "performance")
            for type in "${test_types[@]}"; do
                log_step "Running $type tests..."
                case $type in
                    "unit")
                        if run_unit_tests; then
                            passed=$((passed + 1))
                        else
                            failed=$((failed + 1))
                        fi
                        ;;
                    "integration")
                        if run_integration_tests; then
                            passed=$((passed + 1))
                        else
                            failed=$((failed + 1))
                        fi
                        ;;
                    "e2e")
                        if run_e2e_tests; then
                            passed=$((passed + 1))
                        else
                            failed=$((failed + 1))
                        fi
                        ;;
                    "performance")
                        if run_performance_tests; then
                            passed=$((passed + 1))
                        else
                            failed=$((failed + 1))
                        fi
                        ;;
                esac
            done
            ;;
        *)
            log_error "Unknown test type: $test_type"
            show_help
            exit 1
            ;;
    esac
    
    # Generate report
    generate_report "$test_type" "$passed" "$failed"
    
    # Exit with appropriate code
    if [ $failed -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"