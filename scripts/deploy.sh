#!/bin/bash
# Save as: ~/self-healing-infra/deploy.sh

set -e  # Exit on any error

echo "🚀 Starting Self-Healing Infrastructure Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_status "Checking prerequisites..."

if ! command_exists docker; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

if ! command_exists ansible; then
    print_error "Ansible is not installed. Please install Ansible first."
    exit 1
fi

print_success "All prerequisites are installed."

# Check if running as non-root user
if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root. It's recommended to run as a regular user with docker group access."
fi

# Create necessary directories
print_status "Creating directory structure..."
mkdir -p logs/{nginx,prometheus,alertmanager,webhook,ansible}
chmod 755 logs
print_success "Directory structure created."

# Make scripts executable
print_status "Setting up permissions..."
chmod +x deploy.sh
if [ -f "test_system.sh" ]; then
    chmod +x test_system.sh
fi
print_success "Permissions set."

# Stop any existing containers
print_status "Stopping existing containers (if any)..."
docker compose down --remove-orphans 2>/dev/null || true
print_success "Cleaned up existing containers."

# Build and start services
print_status "Building and starting services..."
docker compose up -d --build


# Wait for services to start
print_status "Waiting for services to start..."
sleep 30

# Check service health
print_status "Checking service health..."

services=(
    "nginx:8181/health"
    "prometheus:9090/-/healthy"
    "alertmanager:9093/-/healthy"
    "webhook-handler:5000/health"
    "grafana:3000/api/health"
)

all_healthy=true

for service in "${services[@]}"; do
    name=$(echo $service | cut -d':' -f1)
    endpoint=$(echo $service | cut -d':' -f2-)
    
    print_status "Checking $name..."
    
    max_attempts=10
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "http://localhost:$endpoint" >/dev/null 2>&1; then
            print_success "$name is healthy"
            break
        else
            if [ $attempt -eq $max_attempts ]; then
                print_error "$name is not responding after $max_attempts attempts"
                all_healthy=false
            else
                print_status "Waiting for $name... (attempt $attempt/$max_attempts)"
                sleep 5
            fi
        fi
        ((attempt++))
    done
done

# Display service URLs
if [ "$all_healthy" = true ]; then
    print_success "🎉 All services are running successfully!"
    echo
    echo "📊 Service URLs:"
    echo "  • NGINX (Sample Service):     http://localhost:8181"
    echo "  • Prometheus (Monitoring):    http://localhost:9090"
    echo "  • Alertmanager (Alerts):      http://localhost:9093"
    echo "  • Grafana (Dashboard):        http://localhost:3000 (admin/admin123)"
    echo "  • Webhook Handler (API):      http://localhost:5000"
    echo "  • cAdvisor (Container Stats): http://localhost:8081"
    echo
    echo "📝 Log files location: ./logs/"
    echo
    echo "🧪 To test the system, run: ./test_system.sh"
    echo
    echo "📖 Key features:"
    echo "  • Automatic service restart when NGINX goes down"
    echo "  • System cleanup when high load is detected"
    echo "  • Emergency procedures for critical alerts"
    echo "  • Comprehensive logging and monitoring"
else
    print_error "Some services failed to start properly. Check the logs:"
    echo "  docker compose logs [service-name]"
    exit 1
fi

print_status "Deployment completed successfully! 🎉"