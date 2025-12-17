. "$PSScriptRoot/config/variables.ps1"

Write-Host "Creating S3 Bucket and folders..."

# 1. Create Bucket
aws s3 mb "s3://$env:BUCKET_NAME"

# 2. Create folders (keys)
aws s3api put-object --bucket $env:BUCKET_NAME --key raw/
aws s3api put-object --bucket $env:BUCKET_NAME --key processed/
aws s3api put-object --bucket $env:BUCKET_NAME --key config/
aws s3api put-object --bucket $env:BUCKET_NAME --key scripts/
aws s3api put-object --bucket $env:BUCKET_NAME --key errors/