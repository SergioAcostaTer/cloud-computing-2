. "$PSScriptRoot/config/variables.ps1"

Write-Host "=== CONFIGURANDO INGESTION AVANZADA (FIREHOSE + LAMBDA) ===" -ForegroundColor Cyan

# --- 1. PREPARAR LAMBDA ---
Write-Host "`n[1/3] Desplegando Lambda de Procesamiento..." -ForegroundColor Yellow

$LAMBDA_NAME = "energy_firehose_processor"
$LAMBDA_SRC = "$PSScriptRoot/../src/lambda/firehose_processor.py"
$ZIP_PATH = "$PSScriptRoot/../src/lambda/function.zip"

# Verificar si existe el código fuente
if (-not (Test-Path $LAMBDA_SRC)) {
    Write-Error "No se encuentra $LAMBDA_SRC. Asegúrate de crear el archivo Python."
    exit 1
}

# Crear ZIP (PowerShell nativo)
Write-Host "Zippeando código..."
Compress-Archive -Path $LAMBDA_SRC -DestinationPath $ZIP_PATH -Force

# Eliminar función si existe para actualizar limpiamente
aws lambda delete-function --function-name $LAMBDA_NAME 2>$null

# Crear función Lambda
Write-Host "Creando función en AWS..."
aws lambda create-function `
    --function-name $LAMBDA_NAME `
    --runtime python3.9 `
    --role $env:ROLE_ARN `
    --handler firehose_processor.lambda_handler `
    --zip-file "fileb://$ZIP_PATH" `
    --timeout 60 `
    --memory-size 128 | Out-Null

# Obtener ARN de la Lambda
$LAMBDA_ARN = (aws lambda get-function --function-name $LAMBDA_NAME --query 'Configuration.FunctionArn' --output text).Trim()
Write-Host "Lambda creada: $LAMBDA_ARN" -ForegroundColor Green

# --- 2. ESPERAR PROPAGACIÓN ---
Write-Host "Esperando 10s..."
Start-Sleep -Seconds 10

# --- 3. CREAR FIREHOSE CON PARTICIONAMIENTO DINÁMICO ---
Write-Host "`n[2/3] Creando Firehose con Particionamiento..." -ForegroundColor Yellow

# Eliminar si existe
aws firehose delete-delivery-stream --delivery-stream-name "consumo-energetico-firehose" 2>$null
Start-Sleep -Seconds 5

# Definir configuración compleja (JSON)
# Nota: Prefix usa !{partitionKeyFromLambda:processing_date} que coincide con el Python
$FIREHOSE_CONFIG = @"
{
    "BucketARN": "arn:aws:s3:::$($env:BUCKET_NAME)",
    "RoleARN": "$env:ROLE_ARN",
    "Prefix": "raw/energy_consumption/processing_date=!{partitionKeyFromLambda:processing_date}/",
    "ErrorOutputPrefix": "errors/!{firehose:error-output-type}/",
    "BufferingHints": { "SizeInMBs": 1, "IntervalInSeconds": 60 },
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

# Crear Stream
aws firehose create-delivery-stream `
    --delivery-stream-name "consumo-energetico-firehose" `
    --delivery-stream-type KinesisStreamAsSource `
    --kinesis-stream-source-configuration "KinesisStreamARN=arn:aws:kinesis:$($env:AWS_REGION):$($env:ACCOUNT_ID):stream/consumo-energetico-stream,RoleARN=$env:ROLE_ARN" `
    --extended-s3-destination-configuration $FIREHOSE_CONFIG

Write-Host "Firehose creado exitosamente." -ForegroundColor Green