. "$PSScriptRoot/config/variables.ps1"

Write-Host "=== CONFIGURING FIREHOSE + LAMBDA ===" -ForegroundColor Cyan

# --- 1. PREPARE LAMBDA ---
Write-Host "`n[1/3] Deploying Processor Lambda..." -ForegroundColor Yellow

$LAMBDA_NAME = "energy_firehose_processor"
$ZIP_PATH = "$PSScriptRoot/../src/lambda/function.zip"

# Zip Python code
Write-Host "Zipping code..."
if (Test-Path $ZIP_PATH) { Remove-Item $ZIP_PATH }
Push-Location "$PSScriptRoot/../src/lambda/"
Compress-Archive -Path "firehose_processor.py" -DestinationPath "function.zip" -Force
Move-Item "function.zip" $ZIP_PATH -Force
Pop-Location

# Delete old function if exists
aws lambda delete-function --function-name $LAMBDA_NAME 2>$null

# Create Function
Write-Host "Creating Lambda..."
aws lambda create-function `
    --function-name $LAMBDA_NAME `
    --runtime python3.9 `
    --role $env:ROLE_ARN `
    --handler firehose_processor.lambda_handler `
    --zip-file "fileb://$ZIP_PATH" `
    --timeout 60 `
    --memory-size 128 | Out-Null

# Get Lambda ARN
$LAMBDA_ARN = (aws lambda get-function --function-name $LAMBDA_NAME --query 'Configuration.FunctionArn' --output text).Trim()
Write-Host "Lambda ARN: $LAMBDA_ARN" -ForegroundColor Green

# Wait for propagation
Start-Sleep -Seconds 5

# --- 2. CREATE FIREHOSE ---
Write-Host "`n[2/3] Creating Firehose..." -ForegroundColor Yellow
$DELIVERY_STREAM_NAME = "consumo-energetico-firehose"

# Cleanup old stream
aws firehose delete-delivery-stream --delivery-stream-name $DELIVERY_STREAM_NAME 2>$null
Start-Sleep -Seconds 5

# Create Temp Config JSON (Fixes PowerShell quote issues)
$FIREHOSE_CONFIG_JSON = @"
{
    "BucketARN": "arn:aws:s3:::$($env:BUCKET_NAME)",
    "RoleARN": "$env:ROLE_ARN",
    "Prefix": "raw/energy_consumption/processing_date=!{partitionKeyFromLambda:processing_date}/",
    "ErrorOutputPrefix": "errors/!{firehose:error-output-type}/",
    "BufferingHints": { "SizeInMBs": 64, "IntervalInSeconds": 60 },
    "ProcessingConfiguration": {
        "Enabled": true,
        "Processors": [
            {
                "Type": "Lambda",
                "Parameters": [
                    { "ParameterName": "LambdaArn", "ParameterValue": "$LAMBDA_ARN" },
                    { "ParameterName": "BufferSizeInMBs", "ParameterValue": "1" },
                    { "ParameterName": "BufferIntervalInSeconds", "ParameterValue": "60" }
                ]
            }
        ]
    },
    "DynamicPartitioningConfiguration": {
        "Enabled": true,
        "RetryOptions": { "DurationInSeconds": 300 }
    }
}
"@

$CONFIG_FILE = "$PSScriptRoot/firehose_config.json"
$FIREHOSE_CONFIG_JSON | Out-File -FilePath $CONFIG_FILE -Encoding ASCII

# Create Stream
aws firehose create-delivery-stream `
    --delivery-stream-name $DELIVERY_STREAM_NAME `
    --delivery-stream-type KinesisStreamAsSource `
    --kinesis-stream-source-configuration "KinesisStreamARN=arn:aws:kinesis:$($env:AWS_REGION):$($env:ACCOUNT_ID):stream/consumo-energetico-stream,RoleARN=$env:ROLE_ARN" `
    --extended-s3-destination-configuration "file://$CONFIG_FILE"

if ($?) { Write-Host "Firehose created." -ForegroundColor Green }
else { Write-Host "Firehose creation failed." -ForegroundColor Red }

# Cleanup temp file
Remove-Item $CONFIG_FILE -ErrorAction SilentlyContinue