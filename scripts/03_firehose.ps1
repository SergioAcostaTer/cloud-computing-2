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

# Crear ZIP de forma segura (limpiando previos y evitando rutas relativas internas)
Write-Host "Zippeando código..."
if (Test-Path $ZIP_PATH) { Remove-Item $ZIP_PATH }
Push-Location "$PSScriptRoot/../src/lambda/"
Compress-Archive -Path "firehose_processor.py" -DestinationPath "function.zip" -Force
Move-Item "function.zip" $ZIP_PATH -Force
Pop-Location

# Actualizar/Crear Lambda
aws lambda delete-function --function-name $LAMBDA_NAME 2>$null

Write-Host "Creando función en AWS..."
aws lambda create-function `
    --function-name $LAMBDA_NAME `
    --runtime python3.9 `
    --role $env:ROLE_ARN `
    --handler firehose_processor.lambda_handler `
    --zip-file "fileb://$ZIP_PATH" `
    --timeout 60 `
    --memory-size 128 | Out-Null

$LAMBDA_ARN = (aws lambda get-function --function-name $LAMBDA_NAME --query 'Configuration.FunctionArn' --output text).Trim()
Write-Host "Lambda creada: $LAMBDA_ARN" -ForegroundColor Green

# Esperar propagación
Start-Sleep -Seconds 5

# --- 2. CREAR FIREHOSE ---
Write-Host "`n[2/3] Creando Firehose con Particionamiento..." -ForegroundColor Yellow
$DELIVERY_STREAM_NAME = "consumo-energetico-firehose"

# Eliminar y esperar
aws firehose delete-delivery-stream --delivery-stream-name $DELIVERY_STREAM_NAME 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Firehose existe. Borrando y esperando..." -ForegroundColor Magenta
    for ($i=0; $i -lt 10; $i++) {
        $status = aws firehose describe-delivery-stream --delivery-stream-name $DELIVERY_STREAM_NAME 2>$null
        if (-not $?) { break } # Si da error, es que ya no existe
        Start-Sleep -Seconds 5
    }
}

# --- SOLUCIÓN ERROR JSON ---
# Guardamos el JSON en un archivo temporal para evitar problemas de comillas en PowerShell
# CORRECCIÓN: SizeInMBs debe ser al menos 64 cuando Dynamic Partitioning está habilitado
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

Write-Host "Configuración escrita en $CONFIG_FILE"

# Crear Stream usando file://
aws firehose create-delivery-stream `
    --delivery-stream-name $DELIVERY_STREAM_NAME `
    --delivery-stream-type KinesisStreamAsSource `
    --kinesis-stream-source-configuration "KinesisStreamARN=arn:aws:kinesis:$($env:AWS_REGION):$($env:ACCOUNT_ID):stream/consumo-energetico-stream,RoleARN=$env:ROLE_ARN" `
    --extended-s3-destination-configuration "file://$CONFIG_FILE"

if ($?) {
    Write-Host "Firehose creado exitosamente." -ForegroundColor Green
} else {
    Write-Host "Error al crear Firehose." -ForegroundColor Red
}

# Limpieza
Remove-Item $CONFIG_FILE -ErrorAction SilentlyContinue