#!/bin/bash
# Validates all Terraform layers
set -e

echo "=== Validating Terraform Code ==="
echo ""

LAYERS=(
  "layers/00-bootstrap"
  "layers/01-organization"
  "layers/02-security"
  "layers/03-logging"
  "layers/04-networking"
  "layers/05-identity"
  "layers/06-workloads"
)

FAILED=0

for layer in "${LAYERS[@]}"; do
  echo "--- Validating: ${layer} ---"
  
  if [ ! -d "${layer}" ]; then
    echo "  SKIP: Directory not found"
    continue
  fi
  
  cd "${layer}"
  
  # Format check
  if ! terraform fmt -check -recursive . > /dev/null 2>&1; then
    echo "  WARN: Formatting issues found"
  fi
  
  # Init (local backend for validation)
  terraform init -backend=false -input=false > /dev/null 2>&1
  
  # Validate
  if terraform validate > /dev/null 2>&1; then
    echo "  PASS"
  else
    echo "  FAIL"
    terraform validate
    FAILED=1
  fi
  
  cd - > /dev/null
  echo ""
done

if [ $FAILED -eq 1 ]; then
  echo "=== VALIDATION FAILED ==="
  exit 1
else
  echo "=== ALL VALIDATIONS PASSED ==="
fi
