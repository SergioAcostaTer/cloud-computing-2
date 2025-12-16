. "$PSScriptRoot/config/variables.ps1"

Write-Host "INICIANDO LIMPIEZA TOTAL DE RECURSOS PARA CUENTA $env:ACCOUNT_ID..." -ForegroundColor Red

# --- 1. GLUE CLEANUP ---
Write-Host "1. Eliminando recursos Glue..."
Write-Host "   - Eliminando Jobs..."
aws glue delete-job --job-name energy_daily_job 2>$null
aws glue delete-job --job-name energy_monthly_job 2>$null

Write-Host "   - Eliminando Crawler 'energy_raw_crawler'..."
aws glue delete-crawler --name energy_raw_crawler 2>$null

Write-Host "   - Eliminando Base de Datos 'energy_db'..."
aws glue delete-database --name energy_db 2>$null

# --- 2. INFRAESTRUCTURA INGESTIÓN ---
Write-Host "2. Eliminando Infraestructura de Ingestión..."
Write-Host "   - Eliminando Firehose..."
aws firehose delete-delivery-stream --delivery-stream-name "consumo-energetico-firehose" 2>$null

Write-Host "   - Eliminando Kinesis Stream..."
aws kinesis delete-stream --stream-name "consumo-energetico-stream" 2>$null

Write-Host "   - Eliminando Función Lambda 'energy_firehose_processor'..."
aws lambda delete-function --function-name "energy_firehose_processor" 2>$null

# --- 3. STORAGE ---
Write-Host "3. Eliminando Storage (S3)..."
Write-Host "   - Eliminando Bucket ($env:BUCKET_NAME)..."
# Force delete elimina todos los objetos dentro antes de borrar el bucket
aws s3 rb "s3://$env:BUCKET_NAME" --force 2>$null

Write-Host "Limpieza finalizada." -ForegroundColor Green