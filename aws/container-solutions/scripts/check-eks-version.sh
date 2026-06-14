#!/usr/bin/env bash
# =============================================================================
# check-eks-version.sh
# Purpose: Report EKS cluster versions and check against AWS support window
# Usage:   ./scripts/check-eks-version.sh [region]
# Example: ./scripts/check-eks-version.sh eu-west-1
# =============================================================================

set -euo pipefail

REGION="${1:-eu-west-1}"
PROJECT="eks-platform"
ENVIRONMENTS=("dev" "test" "prod")

echo "=== EKS Version Report ==="
echo "Region: ${REGION}"
echo ""

for ENV in "${ENVIRONMENTS[@]}"; do
  CLUSTER="${PROJECT}-${ENV}-eks"

  echo "--- ${ENV} ---"

  VERSION=$(aws eks describe-cluster \
    --name "${CLUSTER}" \
    --region "${REGION}" \
    --query 'cluster.version' \
    --output text 2>/dev/null || echo "CLUSTER_NOT_FOUND")

  if [ "${VERSION}" = "CLUSTER_NOT_FOUND" ]; then
    echo "  Cluster: ${CLUSTER} — not found or no access"
    continue
  fi

  STATUS=$(aws eks describe-cluster \
    --name "${CLUSTER}" \
    --region "${REGION}" \
    --query 'cluster.status' \
    --output text)

  echo "  Cluster : ${CLUSTER}"
  echo "  Version : ${VERSION}"
  echo "  Status  : ${STATUS}"

  # Report add-on versions
  echo "  Add-ons :"
  aws eks list-addons \
    --cluster-name "${CLUSTER}" \
    --region "${REGION}" \
    --query 'addons[]' \
    --output text 2>/dev/null | tr '\t' '\n' | while read -r ADDON; do
    ADDON_VERSION=$(aws eks describe-addon \
      --cluster-name "${CLUSTER}" \
      --addon-name "${ADDON}" \
      --region "${REGION}" \
      --query 'addon.addonVersion' \
      --output text 2>/dev/null || echo "unknown")
    echo "    ${ADDON}: ${ADDON_VERSION}"
  done

  echo ""
done

echo "=== Check Complete ==="
echo ""
echo "Reference: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html"
echo "Ensure all clusters are within the AWS 14-month support window."
