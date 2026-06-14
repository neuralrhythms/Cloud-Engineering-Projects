#!/usr/bin/env bash
# =============================================================================
# bootstrap-state-backend.sh
# Purpose: Bootstrap Terraform S3 state backend and DynamoDB lock table
#          Run ONCE before first terraform init in a new environment.
# Usage:   ./scripts/bootstrap-state-backend.sh <environment> <aws-account-id> <region>
# Example: ./scripts/bootstrap-state-backend.sh dev 123456789012 eu-west-1
# =============================================================================

set -euo pipefail

ENVIRONMENT="${1:?Usage: $0 <environment> <account-id> <region>}"
ACCOUNT_ID="${2:?Usage: $0 <environment> <account-id> <region>}"
REGION="${3:-eu-west-1}"
PROJECT="eks-platform"

BUCKET_NAME="${PROJECT}-${ENVIRONMENT}-terraform-state-${ACCOUNT_ID}"
TABLE_NAME="${PROJECT}-${ENVIRONMENT}-terraform-locks"
KMS_ALIAS="alias/${PROJECT}-${ENVIRONMENT}-terraform-state"

echo "=== Bootstrap Terraform State Backend ==="
echo "Environment : ${ENVIRONMENT}"
echo "Account ID  : ${ACCOUNT_ID}"
echo "Region      : ${REGION}"
echo "Bucket      : ${BUCKET_NAME}"
echo "DynamoDB    : ${TABLE_NAME}"
echo ""

# -----------------------------------------------------------------------------
# Create S3 bucket
# -----------------------------------------------------------------------------
echo "[1/5] Creating S3 state bucket..."
if aws s3api head-bucket --bucket "${BUCKET_NAME}" --region "${REGION}" 2>/dev/null; then
  echo "  ℹ️  Bucket already exists: ${BUCKET_NAME}"
else
  aws s3api create-bucket \
    --bucket "${BUCKET_NAME}" \
    --region "${REGION}" \
    --create-bucket-configuration LocationConstraint="${REGION}"
  echo "  ✅ Bucket created: ${BUCKET_NAME}"
fi

# -----------------------------------------------------------------------------
# Enable versioning
# -----------------------------------------------------------------------------
echo "[2/5] Enabling S3 versioning..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled \
  --region "${REGION}"
echo "  ✅ Versioning enabled"

# -----------------------------------------------------------------------------
# Block public access
# -----------------------------------------------------------------------------
echo "[3/5] Blocking public access..."
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --region "${REGION}"
echo "  ✅ Public access blocked"

# -----------------------------------------------------------------------------
# Create DynamoDB lock table
# -----------------------------------------------------------------------------
echo "[4/5] Creating DynamoDB lock table..."
if aws dynamodb describe-table --table-name "${TABLE_NAME}" --region "${REGION}" 2>/dev/null; then
  echo "  ℹ️  Table already exists: ${TABLE_NAME}"
else
  aws dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"
  echo "  ✅ DynamoDB table created: ${TABLE_NAME}"
fi

# -----------------------------------------------------------------------------
# Enable S3 server-side encryption (AES256 — upgrade to KMS after KMS key is created)
# -----------------------------------------------------------------------------
echo "[5/5] Enabling S3 server-side encryption..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }' \
  --region "${REGION}"
echo "  ✅ Server-side encryption enabled (AES256)"
echo "  ℹ️  Upgrade to KMS encryption after the KMS key is created by Terraform"

echo ""
echo "=== Bootstrap complete ==="
echo "Next steps:"
echo "  1. cd terraform/environments/${ENVIRONMENT}"
echo "  2. terraform init -backend-config=backend.hcl"
echo "  3. terraform plan -var-file=terraform.tfvars"
