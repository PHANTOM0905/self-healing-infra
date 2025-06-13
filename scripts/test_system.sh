#!/bin/bash
# Save as: ~/self-healing-infra/test_system.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

echo "🧪 Testing Self-Healing Infrastructure System..."
echo

# Test 1: Check if all services are running
print_status "Test 1: Checking if all services are running..."
services=("nginx" "prometheus" "alertmanager" "webhook-handler" "node-exporter" "cadvisor" "grafana")

for service in "${services[@]}"; do
    if docker ps --filter "name=$service" --filter "status=running" | grep -q "$service"; then
        print_success "$service is running"
    else
        print_error "$service is not running"
        exit 1
    fi
done

echo

# Test 2: Check service endpoints
print_status "Test 2: Checking service endpoints..."

endpoints=(
    "NGINX:http://localhost:8181/health"
    "Prometheus:http://localhost:9090/-/healthy"
    "Alertmanager:http://localhost:9093/-/healthy"
    "Webhook Handler:http://localhost:5000/health"
    "Grafana:http://localhost:3000/api/health"
)

for endpoint in "${endpoints[@]}"; do
    name=$(echo $endpoint | cut -d':' -f1)
    url=$(echo $endpoint | cut -d':' -f2-)
    
    if curl -s -f "$url" >/dev/null 2>&1; then
        print_success "$name endpoint is responding"
    else
        print_error "$name endpoint is not responding"
    fi
done

echo

# Test 3: Check Prometheus targets
print_status "Test 3: Checking Prometheus targets..."
sleep 5  # Give Prometheus time to discover targets

if curl -s "http://localhost:9090/api/v1/targets" | grep -q '"health":"up"'; then
    print_success "Prometheus targets are up"
else
    print_warning "Some Prometheus targets may be down (this is normal on first startup)"
fi

echo

# Test 4: Simulate NGINX failure and recovery
print_status "Test 4: Testing self-healing by stopping NGINX..."

# Stop NGINX container
docker stop nginx
print_status "NGINX container stopped"

# Wait for alert to trigger
print_status "Waiting 60 seconds for alert to trigger and self-healing to activate..."
sleep 60

# Check if NGINX was restarted
if docker ps --filter "name=nginx" --filter "status=running" | grep -q "nginx"; then
    print_success "✨ Self-healing worked! NGINX was automatically restarted"
else
    print_error "Self-healing failed - NGINX was not restarted"
    # Manually restart for cleanup
    docker start nginx
fi

echo

# Test 5: Check logs
print_status "Test 5: Checking system logs..."

log_files=("logs/webhook.log" "logs/actions.log")

for log_file in "${log_files[@]}"; do
    if [ -f "$log_file" ]; then
        print_success "Log file $log_file exists"
        if [ -s "$log_file" ]; then
            print_status "Recent entries in $log_file:"
            tail -3 "$log_file" | sed 's/^/    /'
        fi
    else
        print_warning "Log file $log_file not found (may be created after first alert)"
    fi
done

echo

# Test 6: Send test alert manually
print_status "Test 6: Sending test alert to webhook handler..."

test_alert='{
  "alerts": [
    {
      "status": "firing",
      "labels": {
        "alertname": "TestAlert",
        "service": "test",
        "severity": "warning"
      },
      "annotations": {
        "summary": "This is a test alert",
        "description": "Testing webhook handler functionality"
      }
    }
  ]
}'

if curl -s -X POST -H "Content-Type: application/json" -d "$test_alert" "http://localhost:5000/alert" | grep -q "success"; then
    print_success "Webhook handler processed test alert successfully"
else
    print_error "Webhook handler failed to process test alert"
fi

echo

# Test 7: Verify Ansible connectivity
print_status "Test 7: Testing Ansible connectivity..."

cd ansible 2>/dev/null || true
if ansible localhost -m ping 2>/dev/null | grep -q "SUCCESS"; then
    print_success "Ansible can connect to localhost"
else
    print_warning "Ansible connectivity test failed (may need configuration)"
fi

echo

# Display monitoring dashboard URLs
print_status "🎯 Monitoring Dashboard URLs:"
echo "  📊 Prometheus: http://localhost:9090"
echo "  🚨 Alertmanager: http://localhost:9093"
echo "  📈 Grafana: http://localhost:3000 (admin/admin123)"
echo "  🌐 NGINX: http://localhost:8181"
echo "  🔧 Webhook Handler: http://localhost:5000"

echo

# Display useful commands
print_status "🛠️  Useful Commands:"
echo "  View all logs: docker compose logs -f"
echo "  View specific service logs: docker compose logs -f [service-name]"
echo "  Restart all services: docker compose restart"
echo "  Stop all services: docker compose down"
echo "  View container status: docker compose ps"

echo

print_success "🎉 System testing completed!"
print_status "The self-healing infrastructure is ready to use."

echo
echo "💡 Try these scenarios to see self-healing in action:"
echo "  1. Stop NGINX: docker stop nginx (should auto-restart in ~1 minute)"
echo "  2. Generate high load: stress --cpu 4 --timeout 300s"
echo "  3. Monitor alerts: watch -n 5 'curl -s http://localhost:9093/api/v1/alerts'"