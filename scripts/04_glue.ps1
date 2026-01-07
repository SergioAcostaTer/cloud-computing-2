. "$PSScriptRoot/config/variables.ps1"

Write-Host "=== CONFIGURING AWS GLUE (SEQUENTIAL MODE) ===" -ForegroundColor Cyan

# Helper function to create temp JSON files
function New-TempJson {
    param($Content)
    $Path = [System.IO.Path]::GetTempFileName()
    $Content | ConvertTo-Json -Depth 5 -Compress | Out-File -FilePath $Path -Encoding ASCII
    return $Path
}

# Función para esperar a que un Job termine
function Wait-ForJob {
    param($JobName, $RunId)
    
    Write-Host "Waiting for job $JobName (Run ID: $RunId) to finish..." -ForegroundColor Magenta
    
    do {
        Start-Sleep -Seconds 15
        $Status = (aws glue get-job-run --job-name $JobName --run-id $RunId --query 'JobRun.JobRunState' --output text).Trim()
        Write-Host "  -> $JobName Status: $Status" -ForegroundColor Gray
    } while ($Status -in "STARTING", "RUNNING", "STOPPING")
    
    return $Status
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

# 4. ETL Jobs Creation (Daily & Monthly)
Write-Host "`n[3/4] Creating ETL Jobs..."

# --- Daily Job Setup ---
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

# --- Monthly Job Setup ---
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

# 5. Run Crawler & Trigger Jobs SEQUENTIALLY
Write-Host "`n[4/4] Starting Crawler..."
aws glue start-crawler --name energy_raw_crawler

Write-Host "Waiting for Crawler to finish cataloging..." -ForegroundColor Magenta
do {
    Start-Sleep -Seconds 15
    $CrawlerStatus = (aws glue get-crawler --name energy_raw_crawler --query 'Crawler.State' --output text).Trim()
    Write-Host "Crawler Status: $CrawlerStatus" -ForegroundColor Gray
} while ($CrawlerStatus -ne "READY")

# --- SEQUENTIAL EXECUTION START ---
Write-Host "`n[SEQUENTIAL EXECUTION] Starting Daily Job first..." -ForegroundColor Yellow
$DailyRunId = (aws glue start-job-run --job-name energy_daily_job --query 'JobRunId' --output text).Trim()

# Wait for Daily Job
$DailyStatus = Wait-ForJob -JobName "energy_daily_job" -RunId $DailyRunId

if ($DailyStatus -eq "SUCCEEDED") {
    Write-Host "Daily Job SUCCEEDED. Starting Monthly Job..." -ForegroundColor Green
    
    $MonthlyRunId = (aws glue start-job-run --job-name energy_monthly_job --query 'JobRunId' --output text).Trim()
    
    # Wait for Monthly Job (Optional, but good for verification)
    $MonthlyStatus = Wait-ForJob -JobName "energy_monthly_job" -RunId $MonthlyRunId
    
    if ($MonthlyStatus -eq "SUCCEEDED") {
        Write-Host "All Jobs completed successfully." -ForegroundColor Green
    }
    else {
        Write-Host "Monthly Job FAILED or STOPPED." -ForegroundColor Red
    }
}
else {
    Write-Host "Daily Job FAILED. Skipping Monthly Job to prevent errors/costs." -ForegroundColor Red
}