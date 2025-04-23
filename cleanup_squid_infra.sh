#!/bin/bash

# Define variables (should match the setup script)
REGION="us-central1"
SUBNET_NAME="us-central1-vertex-psci"
INSTANCE_TEMPLATE_NAME="proxy-template"
MIG_NAME="proxy-rmig"
HEALTH_CHECK_NAME="proxy-hc"
BACKEND_SERVICE_NAME="proxy-backend-service"
FORWARDING_RULE_NAME="proxy-forwarding-rule"
STATIC_IP_NAME="proxy-lb-ip" # Added static IP name
# Firewall rule names defined during setup
FW_RULE_PROXY="fw-allow-proxy"
FW_RULE_HC="fw-allow-health-check"

echo "Starting cleanup of proxy infrastructure in region ${REGION}..."

# --- 1. Delete Forwarding Rule ---
echo "Deleting Forwarding Rule: ${FORWARDING_RULE_NAME}..."
gcloud compute forwarding-rules delete "${FORWARDING_RULE_NAME}" \
    --region="${REGION}" \
    --quiet || echo "Forwarding Rule ${FORWARDING_RULE_NAME} not found or already deleted."

# --- 1.5. Delete Static IP Address ---
# Must be deleted after the Forwarding Rule
echo "Deleting Static IP Address: ${STATIC_IP_NAME}..."
gcloud compute addresses delete "${STATIC_IP_NAME}" \
    --region="${REGION}" \
    --quiet || echo "Static IP Address ${STATIC_IP_NAME} not found or already deleted."

# --- 2. Delete Backend Service ---
# Note: Backends (MIG) are implicitly removed when the backend service is deleted.
echo "Deleting Backend Service: ${BACKEND_SERVICE_NAME}..."
gcloud compute backend-services delete "${BACKEND_SERVICE_NAME}" \
    --region="${REGION}" \
    --quiet || echo "Backend Service ${BACKEND_SERVICE_NAME} not found or already deleted."

# --- 3. Delete Regional Managed Instance Group ---
echo "Deleting Regional MIG: ${MIG_NAME}..."
gcloud compute instance-groups managed delete "${MIG_NAME}" \
    --region="${REGION}" \
    --quiet || echo "MIG ${MIG_NAME} not found or already deleted."

# --- 4. Delete Firewall Rules ---
echo "Deleting Firewall Rule: ${FW_RULE_HC}..."
gcloud compute firewall-rules delete "${FW_RULE_HC}" \
    --quiet || echo "Firewall Rule ${FW_RULE_HC} not found or already deleted."

echo "Deleting Firewall Rule: ${FW_RULE_PROXY}..."
gcloud compute firewall-rules delete "${FW_RULE_PROXY}" \
    --quiet || echo "Firewall Rule ${FW_RULE_PROXY} not found or already deleted."

# --- 5. Delete Health Check ---
echo "Deleting Health Check: ${HEALTH_CHECK_NAME}..."
gcloud compute health-checks delete "${HEALTH_CHECK_NAME}" \
    --region="${REGION}" \
    --quiet || echo "Health Check ${HEALTH_CHECK_NAME} not found or already deleted."

# --- 6. Delete Instance Template ---
echo "Deleting Instance Template: ${INSTANCE_TEMPLATE_NAME}..."
gcloud compute instance-templates delete "${INSTANCE_TEMPLATE_NAME}" \
    --quiet || echo "Instance Template ${INSTANCE_TEMPLATE_NAME} not found or already deleted."

echo "Cleanup script finished."
