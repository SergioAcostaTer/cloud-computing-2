# --- VARIABLES ---
$env:AWS_REGION = "us-east-1"
# Obtener ID y Rol automáticamente
$env:ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text).Trim()
$env:ROLE_ARN = (aws iam get-role --role-name LabRole --query 'Role.Arn' --output text).Trim()
# Nombre único del bucket
$env:BUCKET_NAME = "datalake-consumo-energetico-$($env:ACCOUNT_ID)"

Write-Host "Configurando: Cuenta $env:ACCOUNT_ID | Bucket $env:BUCKET_NAME"

# 1. Crear Bucket S3
aws s3 mb "s3://$env:BUCKET_NAME"

# 2. Crear carpetas
aws s3api put-object --bucket $env:BUCKET_NAME --key raw/
aws s3api put-object --bucket $env:BUCKET_NAME --key processed/
aws s3api put-object --bucket $env:BUCKET_NAME --key config/
aws s3api put-object --bucket $env:BUCKET_NAME --key scripts/
aws s3api put-object --bucket $env:BUCKET_NAME --key errors/

# 3. Crear Stream de Kinesis
aws kinesis create-stream --stream-name "consumo-energetico-stream" --shard-count 1

# Esperar 5 segundos para evitar errores de propagación
Start-Sleep -Seconds 5

# 4. Crear Firehose (Conecta Kinesis con S3)
aws firehose create-delivery-stream `
    --delivery-stream-name "consumo-energetico-firehose" `
    --delivery-stream-type KinesisStreamAsSource `
    --kinesis-stream-source-configuration "KinesisStreamARN=arn:aws:kinesis:$($env:AWS_REGION):$($env:ACCOUNT_ID):stream/consumo-energetico-stream,RoleARN=$env:ROLE_ARN" `
    --extended-s3-destination-configuration "BucketARN=arn:aws:s3:::$($env:BUCKET_NAME),RoleARN=$env:ROLE_ARN,Prefix=raw/,ErrorOutputPrefix=errors/,BufferingHints={SizeInMBs=1,IntervalInSeconds=60}"