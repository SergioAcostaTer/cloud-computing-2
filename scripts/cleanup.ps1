# --- VARIABLES ---
$env:AWS_REGION = "us-east-1"
$env:ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text).Trim()
$env:BUCKET_NAME = "datalake-consumo-energetico-$($env:ACCOUNT_ID)"

Write-Host "Iniciando limpieza TOTAL de recursos para la cuenta $env:ACCOUNT_ID..." -ForegroundColor Red

# --- 1. LIMPIEZA DE GLUE (LO NUEVO) ---
Write-Host "1. Eliminando recursos de Glue..."

# 1.1 Eliminar el Crawler
Write-Host "   - Eliminando Crawler 'energy_temp_crawler'..."
aws glue delete-crawler --name energy_temp_crawler 2>$null

# 1.2 Eliminar la Base de Datos
# Esto borra también las tablas definidas dentro (pero NO los datos en S3)
Write-Host "   - Eliminando Base de Datos 'energy_db'..."
aws glue delete-database --name energy_db 2>$null


# --- 2. LIMPIEZA DE INFRAESTRUCTURA ---
Write-Host "2. Eliminando infraestructura de ingestión..."

# 2.1 Eliminar Firehose
Write-Host "   - Eliminando Firehose Delivery Stream..."
aws firehose delete-delivery-stream --delivery-stream-name "consumo-energetico-firehose" 2>$null

# 2.2 Eliminar Kinesis Stream
Write-Host "   - Eliminando Kinesis Data Stream..."
aws kinesis delete-stream --stream-name "consumo-energetico-stream" 2>$null


# --- 3. LIMPIEZA DE ALMACENAMIENTO ---
Write-Host "3. Eliminando almacenamiento (S3)..."

# 3.1 Eliminar Bucket S3 (Force para borrar contenido: raw data, logs y scripts)
Write-Host "   - Eliminando S3 Bucket ($env:BUCKET_NAME)..."
aws s3 rb "s3://$env:BUCKET_NAME" --force 2>$null

Write-Host "Limpieza completa finalizada." -ForegroundColor Green