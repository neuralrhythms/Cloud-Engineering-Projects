#!/usr/bin/env bash
# =============================================================================
# update-kubeconfig.sh
# Purpose: Update local kubeconfig for a given environment
# Usage:   ./scripts/update-kubeconfig.sh <environment> [region]
# Example: ./scripts/update-kubeconfig.sh prod eu-west-1
# =============================================================================

set -euo pipefail

ENVIRONMENT="${1:?Usage: $0 <environment> [region]}"
REGION="${2:-eu-west-1}"
PROJECT="eks-platform"
CLUSTER_NAME="${PROJECT}-${ENVIRONMENT}-eks"

echo "Updating kubeconfig for: ${CLUSTER_NAME} (${REGION})"

aws eks update-kubeconfig \
  --name "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --alias "${CLUSTER_NAME}"

echo "✅ kubeconfig updated. Current context: ${CLUSTER_NAME}"
echo ""
kubectl config current-context
kubectl get nodes
