#!/usr/bin/env bash
# Creates the S3 bucket + DynamoDB table for Terraform remote state.
# Run ONCE before enabling the backend block in terraform/envs/dev/main.tf.
set -euo pipefail

REGION="${1:-us-east-1}"
SUFFIX="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="devops-portfolio-tfstate-${SUFFIX}"
TABLE="devops-portfolio-tf-locks"

echo "Creating state bucket: ${BUCKET}"
if [ "$REGION" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
fi

aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "Creating lock table: ${TABLE}"
aws dynamodb create-table --table-name "$TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region "$REGION" 2>/dev/null || echo "table exists"

echo
echo "Done. Put these in the backend block of terraform/envs/dev/main.tf:"
echo "  bucket         = \"${BUCKET}\""
echo "  dynamodb_table = \"${TABLE}\""
echo "  region         = \"${REGION}\""
