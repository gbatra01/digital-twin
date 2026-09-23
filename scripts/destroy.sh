#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}          # dev | test | prod
PROJECT_NAME=${2:-twin}

echo "💥 Destroying ${PROJECT_NAME} in ${ENVIRONMENT}..."

# 1. Go to project root
cd "$(dirname "$0")/.."

# 2. Terraform workspace
cd terraform

terraform init -input=false

if ! terraform workspace list | grep -qE "(^|[[:space:]])${ENVIRONMENT}([[:space:]]|$)"; then
  echo "❌ Terraform workspace '${ENVIRONMENT}' does not exist."
  exit 1
fi

terraform workspace select "$ENVIRONMENT"

echo "📌 Current Terraform workspace:"
terraform workspace show

# 3. Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

MEMORY_BUCKET="${PROJECT_NAME}-${ENVIRONMENT}-memory-${ACCOUNT_ID}"
FRONTEND_BUCKET="${PROJECT_NAME}-${ENVIRONMENT}-frontend-${ACCOUNT_ID}"

echo ""
echo "🪣 S3 buckets to empty:"
echo "   Memory   : $MEMORY_BUCKET"
echo "   Frontend : $FRONTEND_BUCKET"

# 4. Safety confirmation
echo ""
echo "⚠️  WARNING: This will destroy the ${ENVIRONMENT} environment."
echo "⚠️  AWS resources managed by Terraform will be deleted."
echo ""

read -p "Type DESTROY to continue: " CONFIRM

if [ "$CONFIRM" != "DESTROY" ]; then
  echo "❌ Destroy cancelled."
  exit 0
fi

# 5. Empty S3 buckets
echo ""
echo "🗑️ Emptying memory bucket..."

aws s3 rm "s3://${MEMORY_BUCKET}/" --recursive || true

echo "🗑️ Emptying frontend bucket..."

aws s3 rm "s3://${FRONTEND_BUCKET}/" --recursive || true

# 6. Destroy Terraform infrastructure
echo ""
echo "🔥 Running Terraform destroy..."

if [ "$ENVIRONMENT" = "prod" ]; then

  terraform destroy \
    -var-file=prod.tfvars \
    -var="project_name=$PROJECT_NAME" \
    -var="environment=$ENVIRONMENT" \
    -auto-approve

else

  terraform destroy \
    -var="project_name=$PROJECT_NAME" \
    -var="environment=$ENVIRONMENT" \
    -auto-approve

fi

echo ""
echo "========================================"
echo "✅ ${PROJECT_NAME} ${ENVIRONMENT} destroyed"
echo "========================================"