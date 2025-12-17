# --- GLOBAL CONFIGURATION ---
$env:AWS_REGION = "us-east-1"
# Get AWS Account ID
$env:ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text).Trim()
# Get LabRole ARN (Common in AWS Academy)
$env:ROLE_ARN = (aws iam get-role --role-name LabRole --query 'Role.Arn' --output text).Trim()
# Define unique bucket name
$env:BUCKET_NAME = "datalake-energy-consumption-$($env:ACCOUNT_ID)"

Write-Host "Config: Account $env:ACCOUNT_ID | Bucket $env:BUCKET_NAME"