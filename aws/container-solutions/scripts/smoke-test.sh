#!/usr/bin/env bash
# =============================================================================
# smoke-test.sh
# Purpose: Post-deployment smoke test — verifies basic application health
# Usage:   ./scripts/smoke-test.sh <environment> [app-name]
# Example: ./scripts/smoke-test.sh prod sample-app
# =============================================================================

set -euo pipefail

ENVIRONMENT="${1:-dev}"
APP_NAME="${2:-sample-app}"
NAMESPACE="${APP_NAME}-${ENVIRONMENT}"
TIMEOUT=120

echo "=== Smoke Test: ${APP_NAME} in ${ENVIRONMENT} ==="
echo "Namespace: ${NAMESPACE}"
echo ""

# -----------------------------------------------------------------------------
# 1. Check deployment rollout status
# -----------------------------------------------------------------------------
echo "[1/4] Checking deployment rollout status..."
if kubectl rollout status deployment/"${APP_NAME}" \
    --namespace "${NAMESPACE}" \
    --timeout="${TIMEOUT}s"; then
  echo "  ✅ Deployment rollout: complete"
else
  echo "  ❌ Deployment rollout: failed or timed out"
  kubectl describe deployment "${APP_NAME}" --namespace "${NAMESPACE}"
  exit 1
fi

# -----------------------------------------------------------------------------
# 2. Check pod readiness
# -----------------------------------------------------------------------------
echo "[2/4] Checking pod readiness..."
READY=$(kubectl get deployment "${APP_NAME}" \
  --namespace "${NAMESPACE}" \
  --output jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
DESIRED=$(kubectl get deployment "${APP_NAME}" \
  --namespace "${NAMESPACE}" \
  --output jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")

if [ "${READY}" -ge "1" ] && [ "${READY}" -eq "${DESIRED}" ]; then
  echo "  ✅ Pods ready: ${READY}/${DESIRED}"
else
  echo "  ❌ Pods not ready: ${READY}/${DESIRED}"
  kubectl get pods --namespace "${NAMESPACE}" -l "app.kubernetes.io/name=${APP_NAME}"
  exit 1
fi

# -----------------------------------------------------------------------------
# 3. HTTP health check (via port-forward)
# -----------------------------------------------------------------------------
echo "[3/4] Running HTTP health check..."
POD=$(kubectl get pod \
  --namespace "${NAMESPACE}" \
  -l "app.kubernetes.io/name=${APP_NAME}" \
  --field-selector=status.phase=Running \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "${POD}" ]; then
  echo "  ⚠️  No running pod found — skipping HTTP health check"
else
  # Port-forward in background
  kubectl port-forward "${POD}" 18080:8080 \
    --namespace "${NAMESPACE}" &>/dev/null &
  PF_PID=$!
  sleep 3

  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 10 \
    http://localhost:18080/health/ready 2>/dev/null || echo "000")

  kill "${PF_PID}" 2>/dev/null || true

  if [ "${HTTP_STATUS}" = "200" ]; then
    echo "  ✅ Health check HTTP ${HTTP_STATUS}: /health/ready"
  else
    echo "  ❌ Health check returned HTTP ${HTTP_STATUS}"
    exit 1
  fi
fi

# -----------------------------------------------------------------------------
# 4. Check for recent crash loops
# -----------------------------------------------------------------------------
echo "[4/4] Checking for container restart anomalies..."
RESTARTS=$(kubectl get pods \
  --namespace "${NAMESPACE}" \
  -l "app.kubernetes.io/name=${APP_NAME}" \
  -o jsonpath='{range .items[*]}{.status.containerStatuses[*].restartCount}{"\n"}{end}' \
  2>/dev/null | awk '{sum+=$1} END {print sum+0}')

if [ "${RESTARTS}" -le 3 ]; then
  echo "  ✅ Container restarts: ${RESTARTS} (within threshold)"
else
  echo "  ⚠️  Container restarts: ${RESTARTS} (elevated — investigate)"
fi

echo ""
echo "=== Smoke Test PASSED: ${APP_NAME} in ${ENVIRONMENT} ==="
