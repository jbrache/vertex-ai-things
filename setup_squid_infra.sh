#!/bin/bash
set -e

# Define variables
REGION="us-central1"
SUBNET_NAME="us-central1-vertex-psci"
NETWORK="vertex-vpc-prod"
INSTANCE_TEMPLATE_NAME="proxy-template"
MIG_NAME="proxy-rmig"
HEALTH_CHECK_NAME="proxy-hc"
BACKEND_SERVICE_NAME="proxy-backend-service"
FORWARDING_RULE_NAME="proxy-forwarding-rule"
FORWARDING_RULE_IP="192.168.10.27"
STATIC_IP_NAME="proxy-lb-ip"
NETWORK_TAG="proxy"
PROJECT_ID=$(gcloud config get-value project) # Assumes project is set

# --- 1. Create Instance Template with Tinyproxy Startup Script ---
echo "Creating Instance Template: ${INSTANCE_TEMPLATE_NAME}..."
gcloud compute instance-templates create "${INSTANCE_TEMPLATE_NAME}" \
    --region="${REGION}" \
    --network-interface=subnet="${SUBNET_NAME}",no-address \
    --tags="${NETWORK_TAG}" \
    --machine-type=e2-small \
    --image-family=debian-12 \
    --image-project=debian-cloud \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --metadata=startup-script='#! /bin/bash
    # Wait for network config
    sleep 10

    # Install Tinyproxy
    apt-get update -y
    apt-get install -y tinyproxy

    # Configure Tinyproxy
    cat << EOF > /etc/tinyproxy/tinyproxy.conf
# Default user/group for tinyproxy package on Debian
User tinyproxy
Group tinyproxy

# Port to listen on
Port 3128

# Address to listen on (0.0.0.0 for all interfaces)
Listen 0.0.0.0

# Timeout for connections
Timeout 600

# Log file location
LogFile "/var/log/tinyproxy/tinyproxy.log"

# Process ID file location
PidFile "/run/tinyproxy/tinyproxy.pid"

# Max number of clients
MaxClients 100

# Allow RFC1918 networks
Allow 10.0.0.0/8
Allow 172.16.0.0/12
Allow 192.168.0.0/16

# Deny ALL

# Required for HTTP 1.1
ViaProxyName "tinyproxy"
EOF

    # Ensure log directory exists and has correct permissions
    mkdir -p /var/log/tinyproxy
    chown tinyproxy:tinyproxy /var/log/tinyproxy

    # Restart Tinyproxy
    systemctl restart tinyproxy
    systemctl enable tinyproxy'

# --- 2. Create Health Check ---
echo "Creating Health Check: ${HEALTH_CHECK_NAME}..."
gcloud compute health-checks create tcp "${HEALTH_CHECK_NAME}" \
    --region="${REGION}" \
    --port=3128 \
    --check-interval=10s \
    --timeout=5s \
    --unhealthy-threshold=3 \
    --healthy-threshold=2

# --- 3. Create Firewall Rules ---
echo "Creating Firewall Rule for Proxy traffic..."
gcloud compute firewall-rules create fw-allow-proxy \
    --network="${NETWORK}" \
    --direction=INGRESS \
    --priority=1000 \
    --action=ALLOW \
    --rules=tcp:3128 \
    --source-ranges="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16" \
    --target-tags="${NETWORK_TAG}"

echo "Creating Firewall Rule for Health Checks..."
gcloud compute firewall-rules create fw-allow-health-check \
    --network="${NETWORK}" \
    --direction=INGRESS \
    --priority=1000 \
    --action=ALLOW \
    --rules=tcp \
    --source-ranges="130.211.0.0/22,35.191.0.0/16" \
    --target-tags="${NETWORK_TAG}"

# --- 4. Create Regional Managed Instance Group ---
echo "Creating Regional MIG: ${MIG_NAME}..."
gcloud compute instance-groups managed create "${MIG_NAME}" \
    --region="${REGION}" \
    --size=3 \
    --template="${INSTANCE_TEMPLATE_NAME}"

# --- 5. Create Backend Service ---
echo "Creating Backend Service: ${BACKEND_SERVICE_NAME}..."
gcloud compute backend-services create "${BACKEND_SERVICE_NAME}" \
    --load-balancing-scheme=INTERNAL \
    --protocol=TCP \
    --region="${REGION}" \
    --health-checks="${HEALTH_CHECK_NAME}" \
    --health-checks-region="${REGION}"

echo "Adding MIG to Backend Service..."
gcloud compute backend-services add-backend "${BACKEND_SERVICE_NAME}" \
    --region="${REGION}" \
    --instance-group="${MIG_NAME}" \
    --instance-group-region="${REGION}"

# --- 6. Reserve Static IP and Create Forwarding Rule ---
echo "Reserving Static Internal IP: ${STATIC_IP_NAME}..."
gcloud compute addresses create "${STATIC_IP_NAME}" \
    --region="${REGION}" \
    --subnet="${SUBNET_NAME}" \
    --addresses="${FORWARDING_RULE_IP}" \
    --purpose=GCE_ENDPOINT

echo "Creating Forwarding Rule: ${FORWARDING_RULE_NAME}..."
gcloud compute forwarding-rules create "${FORWARDING_RULE_NAME}" \
    --region="${REGION}" \
    --load-balancing-scheme=INTERNAL \
    --address="${STATIC_IP_NAME}" \
    --network="${NETWORK}" \
    --subnet="${SUBNET_NAME}" \
    --ip-protocol=TCP \
    --ports=3128 \
    --backend-service="${BACKEND_SERVICE_NAME}" \
    --backend-service-region="${REGION}"

echo "Setup complete. The Internal NLB IP is:"
# Get IP from the reserved address resource
gcloud compute addresses describe "${STATIC_IP_NAME}" --region="${REGION}" --format='value(address)'
