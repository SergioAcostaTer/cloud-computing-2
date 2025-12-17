# --- LOGGING SETUP ---
$LogDir = "$PSScriptRoot/../logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
$LogFile = "$LogDir/deploy_$(Get-Date -Format 'yyyyMMdd_HHmm').log"

# Start recording all output (PS + Python) to file
Start-Transcript -Path $LogFile

Write-Host "=== PIPELINE DEPLOYMENT ===" -ForegroundColor Cyan

# 1. Load config
. "$PSScriptRoot/config/variables.ps1"

# 2. Setup S3
Write-Host "`n[1/5] Setting up S3..." -ForegroundColor Yellow
. "$PSScriptRoot/01_s3.ps1"

# 3. Setup Kinesis
Write-Host "`n[2/5] Setting up Kinesis..." -ForegroundColor Yellow
. "$PSScriptRoot/02_kinesis.ps1"

# 4. Setup Firehose
Write-Host "`n[3/5] Setting up Firehose..." -ForegroundColor Yellow
. "$PSScriptRoot/03_firehose.ps1"

# 5. Run Producer
Write-Host "`n[4/5] Generating Data & Syncing..." -ForegroundColor Yellow

# Move to python producer directory
Push-Location "$PSScriptRoot/../src/producer"

try {
    # Check for mydata.json
    if (-not (Test-Path "../data/mydata.json")) {
        throw "Data file '../data/mydata.json' not found. Please ensure your custom data file exists."
    }

    Write-Host "Installing requirements..."
    python -m pip install -r requirements.txt | Out-Null

    Write-Host "Running Python Producer with mydata.json..."
    python kinesis.py
}
catch {
    Write-Host "Error running Python script: $_" -ForegroundColor Red
    Pop-Location
    Stop-Transcript
    exit 1
}

# Return to scripts dir
Pop-Location

# Wait for Firehose buffer (60s buffer + margin)
Write-Host "Waiting 70s for Firehose buffer to flush to S3..." -ForegroundColor Magenta
Start-Sleep -Seconds 70

# 6. Setup Glue
Write-Host "`n[5/5] Setting up Glue..." -ForegroundColor Yellow
. "$PSScriptRoot/04_glue.ps1"

Write-Host "`nPipeline deployed successfully." -ForegroundColor Green
Write-Host "Logs saved to: $LogFile" -ForegroundColor Gray

# Stop logging
Stop-Transcript