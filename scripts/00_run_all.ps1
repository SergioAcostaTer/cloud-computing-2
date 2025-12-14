Write-Host "=== PIPELINE DEPLOYMENT ===" -ForegroundColor Cyan

# 1. Load variables
. "$PSScriptRoot/config/variables.ps1"

# 2. Storage (S3)
Write-Host "`n[1/5] Setting up S3..." -ForegroundColor Yellow
. "$PSScriptRoot/01_s3.ps1"

# 3. Kinesis Stream
Write-Host "`n[2/5] Setting up Kinesis..." -ForegroundColor Yellow
. "$PSScriptRoot/02_kinesis.ps1"

# 4. Firehose Delivery
Write-Host "`n[3/5] Setting up Firehose..." -ForegroundColor Yellow
. "$PSScriptRoot/03_firehose.ps1"

# --- NEW STEP: EXECUTE DATA PRODUCER ---
Write-Host "`n[4/5] Generating Data & Syncing..." -ForegroundColor Yellow

# Store current location (scripts/) and move to python dir to handle relative paths correctly
Push-Location "$PSScriptRoot/../src/producer"

try {
    # Check if data file exists
    if (-not (Test-Path "../data/datos.json")) {
        Write-Host "ERROR: '../data/datos.json' not found!" -ForegroundColor Red
        Write-Host "Please rename 'datos.json.example' to 'datos.json' inside src/data/" -ForegroundColor Red
        Pop-Location
        exit 1
    }

    Write-Host "Installing requirements..."
    python -m pip install -r requirements.txt

    Write-Host "Running Python Producer..."
    python kinesis.py
}
catch {
    Write-Host "Error running Python script: $_" -ForegroundColor Red
    Pop-Location
    exit 1
}

# Return to scripts directory
Pop-Location


# Wait for Firehose to flush data to S3
Write-Host "Waiting 70s for Firehose buffer to flush to S3..." -ForegroundColor Magenta
Start-Sleep -Seconds 70

# 5. Glue Catalog
Write-Host "`n[5/5] Setting up Glue..." -ForegroundColor Yellow
. "$PSScriptRoot/04_glue.ps1"

Write-Host "`nPipeline deployed successfully." -ForegroundColor Green
Write-Host "Data has been generated, flushed to S3, and Crawled." -ForegroundColor Green