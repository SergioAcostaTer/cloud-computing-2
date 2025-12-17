. "$PSScriptRoot/config/variables.ps1"

Write-Host "CLEANING UP RESOURCES FOR ACCOUNT $env:ACCOUNT_ID..." -ForegroundColor Red

# 1. Glue
Write-Host "1. Deleting Glue Resources..."
aws glue delete-job --job-name energy_daily_job 2>$null
aws glue delete-job --job-name energy_monthly_job 2>$null
aws glue delete-crawler --name energy_raw_crawler 2>$null
aws glue delete-database --name energy_db 2>$null

# 2. Ingestion
Write-Host "2. Deleting Ingestion Resources..."
aws firehose delete-delivery-stream --delivery-stream-name "consumo-energetico-firehose" 2>$null
aws kinesis delete-stream --stream-name "consumo-energetico-stream" 2>$null
aws lambda delete-function --function-name "energy_firehose_processor" 2>$null

# 3. S3
Write-Host "3. Deleting Bucket..."
# Force delete removes all files inside first
aws s3 rb "s3://$env:BUCKET_NAME" --force 2>$null

Write-Host "Cleanup complete." -ForegroundColor Green