#!/bin/bash

# Unity MCP Docker Management Script
# Provides easy commands for Docker operations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVER_DIR="$PROJECT_ROOT/UnityMcpBridge/UnityMcpServer~/src"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
}

# Function to check if Docker Compose is available
check_compose() {
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
}

# Function to get compose command
get_compose_cmd() {
    if command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

# Show usage information
show_usage() {
    echo "Unity MCP Docker Management Script"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  build         Build the Unity MCP server Docker image"
    echo "  up            Start the server using Docker Compose"
    echo "  dev           Start development environment with hot-reload"
    echo "  down          Stop all running containers"
    echo "  logs          Show server logs"
    echo "  shell         Open shell in running container"
    echo "  clean         Remove containers and images"
    echo "  status        Show container status"
    echo "  test          Test the Docker setup"
    echo "  help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 build"
    echo "  $0 up"
    echo "  $0 dev"
    echo "  $0 logs"
}

# Build Docker image
cmd_build() {
    print_status "Building Unity MCP server Docker image..."
    cd "$PROJECT_ROOT"
    docker build -t unity-mcp-server:latest "$SERVER_DIR"
    print_success "Docker image built successfully!"
}

# Start services with Docker Compose
cmd_up() {
    print_status "Starting Unity MCP server..."
    cd "$PROJECT_ROOT"
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD up -d unity-mcp-server
    print_success "Unity MCP server started! Check logs with: $0 logs"
}

# Start development environment
cmd_dev() {
    print_status "Starting Unity MCP development environment..."
    cd "$PROJECT_ROOT"
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD --profile development up -d unity-mcp-dev
    print_success "Development environment started! Check logs with: $0 logs"
}

# Stop services
cmd_down() {
    print_status "Stopping Unity MCP services..."
    cd "$PROJECT_ROOT"
    COMPOSE_CMD=$(get_compose_cmd)
    $COMPOSE_CMD down
    print_success "Services stopped!"
}

# Show logs
cmd_logs() {
    cd "$PROJECT_ROOT"
    COMPOSE_CMD=$(get_compose_cmd)
    if docker ps --format "table {{.Names}}" | grep -q "unity-mcp-server"; then
        print_status "Showing Unity MCP server logs..."
        $COMPOSE_CMD logs -f unity-mcp-server
    elif docker ps --format "table {{.Names}}" | grep -q "unity-mcp-dev"; then
        print_status "Showing Unity MCP development logs..."
        $COMPOSE_CMD logs -f unity-mcp-dev
    else
        print_warning "No Unity MCP containers are running."
    fi
}

# Open shell in container
cmd_shell() {
    if docker ps --format "table {{.Names}}" | grep -q "unity-mcp-server"; then
        print_status "Opening shell in Unity MCP server container..."
        docker exec -it unity-mcp-server /bin/bash
    elif docker ps --format "table {{.Names}}" | grep -q "unity-mcp-dev"; then
        print_status "Opening shell in Unity MCP development container..."
        docker exec -it unity-mcp-dev /bin/bash
    else
        print_warning "No Unity MCP containers are running."
        print_status "Starting a temporary container for shell access..."
        docker run -it --rm unity-mcp-server:latest /bin/bash
    fi
}

# Clean up containers and images
cmd_clean() {
    print_warning "This will remove all Unity MCP containers and images."
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleaning up Unity MCP Docker resources..."
        cd "$PROJECT_ROOT"
        COMPOSE_CMD=$(get_compose_cmd)
        $COMPOSE_CMD down -v --rmi all
        docker rmi unity-mcp-server:latest 2>/dev/null || true
        docker rmi unity-mcp-server:dev 2>/dev/null || true
        print_success "Cleanup completed!"
    else
        print_status "Cleanup cancelled."
    fi
}

# Show status
cmd_status() {
    print_status "Unity MCP Docker status:"
    echo ""
    
    # Check if images exist
    if docker images unity-mcp-server --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedAt}}\t{{.Size}}" | grep -q unity-mcp-server; then
        echo "Images:"
        docker images unity-mcp-server --format "table {{.Repository}}:{{.Tag}}\t{{.CreatedAt}}\t{{.Size}}"
        echo ""
    fi
    
    # Check running containers
    if docker ps --filter "name=unity-mcp" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | tail -n +2 | grep -q .; then
        echo "Running containers:"
        docker ps --filter "name=unity-mcp" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
    else
        print_warning "No Unity MCP containers are currently running."
    fi
}

# Test Docker setup
cmd_test() {
    print_status "Testing Unity MCP Docker setup..."
    
    # Test building
    print_status "Testing Docker build..."
    cmd_build
    
    # Test running
    print_status "Testing container startup..."
    docker run --rm -d --name unity-mcp-test -p 6505:6500 unity-mcp-server:latest
    
    # Wait a moment for startup
    sleep 5
    
    # Test if server is responding (basic check)
    if docker ps | grep -q unity-mcp-test; then
        print_success "Container started successfully!"
        
        # Clean up test container
        docker stop unity-mcp-test >/dev/null 2>&1
        print_status "Test completed. Container cleaned up."
    else
        print_error "Container failed to start properly."
        docker logs unity-mcp-test 2>/dev/null || true
        docker rm unity-mcp-test >/dev/null 2>&1 || true
        exit 1
    fi
}

# Main execution
main() {
    check_docker
    check_compose
    
    case "${1:-help}" in
        build)
            cmd_build
            ;;
        up)
            cmd_up
            ;;
        dev)
            cmd_dev
            ;;
        down)
            cmd_down
            ;;
        logs)
            cmd_logs
            ;;
        shell)
            cmd_shell
            ;;
        clean)
            cmd_clean
            ;;
        status)
            cmd_status
            ;;
        test)
            cmd_test
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"