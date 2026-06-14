#!/bin/bash
# Deploys a specific layer
# Usage: ./scripts/deploy-layer.sh <layer-number> [plan|apply]
set -e

LAYER=$1
ACTION=${2:-plan}

if [ -z "$LAYER" ]; then
  echo "Usage: $0 <layer-number> [plan|apply]"
  echo "  Example: $0 01-organization plan"
  echo "  Example: $0 02-security apply"
  exit 1
fi

LAYER_DIR="layers/${LAYER}"

if [ ! -d "$LAYER_DIR" ]; then
  echo "Error: Layer directory not found: ${LAYER_DIR}"
  exit 1
fi

echo "=== Deploying Layer: ${LAYER} (${ACTION}) ==="
echo ""

cd "${LAYER_DIR}"

# Initialize
echo "--- Initializing ---"
terraform init -input=false

# Validate
echo "--- Validating ---"
terraform validate

# Plan or Apply
if [ "$ACTION" == "apply" ]; then
  echo "--- Applying ---"
  terraform apply -input=false
else
  echo "--- Planning ---"
  terraform plan -input=false
fi

echo ""
echo "=== Done: ${LAYER} ==="
