. "$PSScriptRoot/config/variables.ps1"

Write-Host "=== CONFIGURING AWS GLUE ===" -ForegroundColor Cyan

# 1. Upload ETL Scripts
Write-Host "`n[1/4] Uploading Spark scripts..."
aws s3 cp "$PSScriptRoot/energy_aggregation_daily.py" "s3://$env:BUCKET_NAME/scripts/energy_aggregation_daily.py"
aws s3 cp "$PSScriptRoot/energy_aggregation_monthly.py" "s3://$env:BUCKET_NAME/scripts/energy_aggregation_monthly.py"

# 2. Database
Write-Host "`n[2/4] Creating Database..."
aws glue create-database --database-input "{\"Name\":\"energy_db\"}" 2>$null

# 3. Crawler
aws glue delete-crawler --name energy_raw_crawler 2>$null
$TARGET_PATH = "s3://$env:BUCKET_NAME/raw/energy_consumption/"
# Robust JSON escape for PS
$TARGETS_JSON = '{\"S3Targets\": [{\"Path\": \"' + $TARGET_PATH + '\"}]}'

Write-Host "Creating Crawler..."
aws glue create-crawler `
    --name energy_raw_crawler `
    --role $env:ROLE_ARN `
    --database-name energy_db `
    --targets $TARGETS_JSON

# 4. ETL Jobs
Write-Host "`n[3/4] Creating ETL Jobs..."

# --- Daily Job ---
aws glue delete-job --job-name energy_daily_job 2>$null
$DailyScript = "s3://$env:BUCKET_NAME/scripts/energy_aggregation_daily.py"
$DailyOut = "s3://$env:BUCKET_NAME/processed/daily/"

# JSON Strings
$DailyCmd = '{\"Name\": \"glueetl\", \"ScriptLocation\": \"' + $DailyScript + '\", \"PythonVersion\": \"3\"}'
$DailyArgs = '{\"--database\": \"energy_db\", \"--table_name\": \"energy_consumption\", \"--output_path\": \"' + $DailyOut + '\", \"--job-language\": \"python\"}'

aws glue create-job `
    --name energy_daily_job `
    --role $env:ROLE_ARN `
    --command $DailyCmd `
    --default-arguments $DailyArgs `
    --glue-version "4.0" `
    --number-of-workers 2 `
    --worker-type "G.1X"

# --- Monthly Job ---
aws glue delete-job --job-name energy_monthly_job 2>$null
$MonthlyScript = "s3://$env:BUCKET_NAME/scripts/energy_aggregation_monthly.py"
$MonthlyOut = "s3://$env:BUCKET_NAME/processed/monthly/"

$MonthlyCmd = '{\"Name\": \"glueetl\", \"ScriptLocation\": \"' + $MonthlyScript + '\", \"PythonVersion\": \"3\"}'
$MonthlyArgs = '{\"--database\": \"energy_db\", \"--table_name\": \"energy_consumption\", \"--output_path\": \"' + $MonthlyOut + '\", \"--job-language\": \"python\"}'

aws glue create-job `
    --name energy_monthly_job `
    --role $env:ROLE_ARN `
    --command $MonthlyCmd `
    --default-arguments $MonthlyArgs `
    --glue-version "4.0" `
    --number-of-workers 2 `
    --worker-type "G.1X"

# 5. Run Crawler & Trigger Jobs
Write-Host "`n[4/4] Starting Crawler..."
aws glue start-crawler --name energy_raw_crawler

Write-Host "Waiting 120s for Crawler to catalog data..." -ForegroundColor Magenta
Start-Sleep -Seconds 120

Write-Host "Starting ETL Jobs..." -ForegroundColor Yellow
aws glue start-job-run --job-name energy_daily_job | Out-Null
aws glue start-job-run --job-name energy_monthly_job | Out-Null

Write-Host "Glue ready. Crawler finished (wait time) and Jobs triggered." -ForegroundColor Green