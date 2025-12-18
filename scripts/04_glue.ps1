. "$PSScriptRoot/config/variables.ps1"

Write-Host "=== CONFIGURING AWS GLUE ===" -ForegroundColor Cyan

# Helper function to create temp JSON files
function New-TempJson {
    param($Content)
    $Path = [System.IO.Path]::GetTempFileName()
    $Content | ConvertTo-Json -Depth 5 -Compress | Out-File -FilePath $Path -Encoding ASCII
    return $Path
}

# 1. Upload ETL Scripts
Write-Host "`n[1/4] Uploading Spark scripts..."
aws s3 cp "$PSScriptRoot/energy_aggregation_daily.py" "s3://$env:BUCKET_NAME/scripts/energy_aggregation_daily.py"
aws s3 cp "$PSScriptRoot/energy_aggregation_monthly.py" "s3://$env:BUCKET_NAME/scripts/energy_aggregation_monthly.py"

# 2. Database
Write-Host "`n[2/4] Creating Database..."
# Use temp file to avoid PowerShell quoting issues
$DbInput = @{ Name = "energy_db" }
$DbFile = New-TempJson -Content $DbInput
aws glue create-database --database-input "file://$DbFile" 2>&1 | Out-Null
Remove-Item $DbFile

# 3. Crawler
Write-Host "Configuring Crawler..."
aws glue delete-crawler --name energy_raw_crawler 2>&1 | Out-Null

$CrawlerTargets = @{
    S3Targets = @(
        @{ Path = "s3://$env:BUCKET_NAME/raw/energy_consumption/" }
    )
}
$CrawlerFile = New-TempJson -Content $CrawlerTargets

aws glue create-crawler `
    --name energy_raw_crawler `
    --role $env:ROLE_ARN `
    --database-name energy_db `
    --targets "file://$CrawlerFile"

Remove-Item $CrawlerFile

# 4. ETL Jobs
Write-Host "`n[3/4] Creating ETL Jobs..."

# --- Daily Job ---
aws glue delete-job --job-name energy_daily_job 2>&1 | Out-Null
$DailyScript = "s3://$env:BUCKET_NAME/scripts/energy_aggregation_daily.py"
$DailyOut = "s3://$env:BUCKET_NAME/processed/daily/"

$DailyCommand = @{
    Name           = "glueetl"
    ScriptLocation = $DailyScript
    PythonVersion  = "3"
}
$DailyArgs = @{
    "--database"     = "energy_db"
    "--table_name"   = "energy_consumption"
    "--output_path"  = $DailyOut
    "--job-language" = "python"
}

# Save configs to files
$DailyCmdFile = New-TempJson -Content $DailyCommand
$DailyArgsFile = New-TempJson -Content $DailyArgs

aws glue create-job `
    --name energy_daily_job `
    --role $env:ROLE_ARN `
    --command "file://$DailyCmdFile" `
    --default-arguments "file://$DailyArgsFile" `
    --glue-version "4.0" `
    --number-of-workers 2 `
    --worker-type "G.1X"

Remove-Item $DailyCmdFile, $DailyArgsFile

# --- Monthly Job ---
aws glue delete-job --job-name energy_monthly_job 2>&1 | Out-Null
$MonthlyScript = "s3://$env:BUCKET_NAME/scripts/energy_aggregation_monthly.py"
$MonthlyOut = "s3://$env:BUCKET_NAME/processed/monthly/"

$MonthlyCommand = @{
    Name           = "glueetl"
    ScriptLocation = $MonthlyScript
    PythonVersion  = "3"
}
$MonthlyArgs = @{
    "--database"     = "energy_db"
    "--table_name"   = "energy_consumption"
    "--output_path"  = $MonthlyOut
    "--job-language" = "python"
}

$MonthlyCmdFile = New-TempJson -Content $MonthlyCommand
$MonthlyArgsFile = New-TempJson -Content $MonthlyArgs

aws glue create-job `
    --name energy_monthly_job `
    --role $env:ROLE_ARN `
    --command "file://$MonthlyCmdFile" `
    --default-arguments "file://$MonthlyArgsFile" `
    --glue-version "4.0" `
    --number-of-workers 2 `
    --worker-type "G.1X"

Remove-Item $MonthlyCmdFile, $MonthlyArgsFile

# 5. Run Crawler & Trigger Jobs
Write-Host "`n[4/4] Starting Crawler..."
aws glue start-crawler --name energy_raw_crawler

Write-Host "Waiting for Crawler to finish cataloging..." -ForegroundColor Magenta

# Poll until crawler is back to READY state
do {
    Start-Sleep -Seconds 15
    $CrawlerStatus = (aws glue get-crawler --name energy_raw_crawler | ConvertFrom-Json).Crawler.State
    Write-Host "Crawler Status: $CrawlerStatus" -ForegroundColor Gray
} while ($CrawlerStatus -ne "READY")

Write-Host "Starting ETL Jobs..." -ForegroundColor Yellow
aws glue start-job-run --job-name energy_daily_job | Out-Null
aws glue start-job-run --job-name energy_monthly_job | Out-Null

Write-Host "Glue ready. Crawler finished and Jobs triggered." -ForegroundColor Green