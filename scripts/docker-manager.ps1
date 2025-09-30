# Unity MCP Docker Management Script for Windows
# Provides easy commands for Docker operations

param(
    [Parameter(Position=0)]
    [string]$Command = "help"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Split-Path -Parent $ScriptDir
$ServerDir = Join-Path $ProjectRoot "UnityMcpBridge\UnityMcpServer~\src"

# Function to write colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error-Message {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Function to check if Docker is running
function Test-Docker {
    try {
        docker info | Out-Null
        return $true
    }
    catch {
        Write-Error-Message "Docker is not running. Please start Docker and try again."
        exit 1
    }
}

# Function to check if Docker Compose is available
function Test-DockerCompose {
    $composeV1 = Get-Command docker-compose -ErrorAction SilentlyContinue
    $composeV2 = try { docker compose version; $true } catch { $false }
    
    if (-not $composeV1 -and -not $composeV2) {
        Write-Error-Message "Docker Compose is not available. Please install Docker Compose."
        exit 1
    }
}

# Function to get compose command
function Get-ComposeCommand {
    if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        return "docker-compose"
    }
    else {
        return "docker compose"
    }
}

# Show usage information
function Show-Usage {
    Write-Host "Unity MCP Docker Management Script"
    Write-Host ""
    Write-Host "Usage: .\docker-manager.ps1 [COMMAND]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  build         Build the Unity MCP server Docker image"
    Write-Host "  up            Start the server using Docker Compose"
    Write-Host "  dev           Start development environment with hot-reload"
    Write-Host "  down          Stop all running containers"
    Write-Host "  logs          Show server logs"
    Write-Host "  shell         Open shell in running container"
    Write-Host "  clean         Remove containers and images"
    Write-Host "  status        Show container status"
    Write-Host "  test          Test the Docker setup"
    Write-Host "  help          Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\docker-manager.ps1 build"
    Write-Host "  .\docker-manager.ps1 up"
    Write-Host "  .\docker-manager.ps1 dev"
    Write-Host "  .\docker-manager.ps1 logs"
}

# Build Docker image
function Invoke-Build {
    Write-Status "Building Unity MCP server Docker image..."
    Set-Location $ProjectRoot
    docker build -t unity-mcp-server:latest $ServerDir
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker image built successfully!"
    }
    else {
        Write-Error-Message "Docker build failed!"
        exit 1
    }
}

# Start services with Docker Compose
function Invoke-Up {
    Write-Status "Starting Unity MCP server..."
    Set-Location $ProjectRoot
    $ComposeCmd = Get-ComposeCommand
    Invoke-Expression "$ComposeCmd up -d unity-mcp-server"
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Unity MCP server started! Check logs with: .\docker-manager.ps1 logs"
    }
}

# Start development environment
function Invoke-Dev {
    Write-Status "Starting Unity MCP development environment..."
    Set-Location $ProjectRoot
    $ComposeCmd = Get-ComposeCommand
    Invoke-Expression "$ComposeCmd --profile development up -d unity-mcp-dev"
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Development environment started! Check logs with: .\docker-manager.ps1 logs"
    }
}

# Stop services
function Invoke-Down {
    Write-Status "Stopping Unity MCP services..."
    Set-Location $ProjectRoot
    $ComposeCmd = Get-ComposeCommand
    Invoke-Expression "$ComposeCmd down"
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Services stopped!"
    }
}

# Show logs
function Invoke-Logs {
    Set-Location $ProjectRoot
    $ComposeCmd = Get-ComposeCommand
    $serverRunning = docker ps --format "table {{.Names}}" | Select-String "unity-mcp-server"
    $devRunning = docker ps --format "table {{.Names}}" | Select-String "unity-mcp-dev"
    
    if ($serverRunning) {
        Write-Status "Showing Unity MCP server logs..."
        Invoke-Expression "$ComposeCmd logs -f unity-mcp-server"
    }
    elseif ($devRunning) {
        Write-Status "Showing Unity MCP development logs..."
        Invoke-Expression "$ComposeCmd logs -f unity-mcp-dev"
    }
    else {
        Write-Warning "No Unity MCP containers are running."
    }
}

# Open shell in container
function Invoke-Shell {
    $serverRunning = docker ps --format "table {{.Names}}" | Select-String "unity-mcp-server"
    $devRunning = docker ps --format "table {{.Names}}" | Select-String "unity-mcp-dev"
    
    if ($serverRunning) {
        Write-Status "Opening shell in Unity MCP server container..."
        docker exec -it unity-mcp-server /bin/bash
    }
    elseif ($devRunning) {
        Write-Status "Opening shell in Unity MCP development container..."
        docker exec -it unity-mcp-dev /bin/bash
    }
    else {
        Write-Warning "No Unity MCP containers are running."
        Write-Status "Starting a temporary container for shell access..."
        docker run -it --rm unity-mcp-server:latest /bin/bash
    }
}

# Clean up containers and images
function Invoke-Clean {
    Write-Warning "This will remove all Unity MCP containers and images."
    $response = Read-Host "Are you sure? (y/N)"
    if ($response -match '^[Yy]$') {
        Write-Status "Cleaning up Unity MCP Docker resources..."
        Set-Location $ProjectRoot
        $ComposeCmd = Get-ComposeCommand
        Invoke-Expression "$ComposeCmd down -v --rmi all"
        docker rmi unity-mcp-server:latest 2>$null
        docker rmi unity-mcp-server:dev 2>$null
        Write-Success "Cleanup completed!"
    }
    else {
        Write-Status "Cleanup cancelled."
    }
}

# Show status
function Invoke-Status {
    Write-Status "Unity MCP Docker status:"
    Write-Host ""
    
    # Check if images exist
    $images = docker images unity-mcp-server --format "table {{.Repository}}:{{.Tag}}`t{{.CreatedAt}}`t{{.Size}}" | Select-String "unity-mcp-server"
    if ($images) {
        Write-Host "Images:"
        docker images unity-mcp-server --format "table {{.Repository}}:{{.Tag}}`t{{.CreatedAt}}`t{{.Size}}"
        Write-Host ""
    }
    
    # Check running containers
    $containers = docker ps --filter "name=unity-mcp" --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}" | Select-Object -Skip 1
    if ($containers) {
        Write-Host "Running containers:"
        docker ps --filter "name=unity-mcp" --format "table {{.Names}}`t{{.Status}}`t{{.Ports}}"
        Write-Host ""
    }
    else {
        Write-Warning "No Unity MCP containers are currently running."
    }
}

# Test Docker setup
function Invoke-Test {
    Write-Status "Testing Unity MCP Docker setup..."
    
    # Test building
    Write-Status "Testing Docker build..."
    Invoke-Build
    
    # Test running
    Write-Status "Testing container startup..."
    docker run --rm -d --name unity-mcp-test -p 6505:6500 unity-mcp-server:latest
    
    # Wait a moment for startup
    Start-Sleep -Seconds 5
    
    # Test if server is responding (basic check)
    $testContainer = docker ps | Select-String "unity-mcp-test"
    if ($testContainer) {
        Write-Success "Container started successfully!"
        
        # Clean up test container
        docker stop unity-mcp-test | Out-Null
        Write-Status "Test completed. Container cleaned up."
    }
    else {
        Write-Error-Message "Container failed to start properly."
        docker logs unity-mcp-test 2>$null
        docker rm unity-mcp-test 2>$null
        exit 1
    }
}

# Main execution
Test-Docker
Test-DockerCompose

switch ($Command.ToLower()) {
    "build" { Invoke-Build }
    "up" { Invoke-Up }
    "dev" { Invoke-Dev }
    "down" { Invoke-Down }
    "logs" { Invoke-Logs }
    "shell" { Invoke-Shell }
    "clean" { Invoke-Clean }
    "status" { Invoke-Status }
    "test" { Invoke-Test }
    "help" { Show-Usage }
    default {
        Write-Error-Message "Unknown command: $Command"
        Write-Host ""
        Show-Usage
        exit 1
    }
}