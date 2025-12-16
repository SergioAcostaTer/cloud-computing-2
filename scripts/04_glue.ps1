. "$PSScriptRoot/config/variables.ps1"

Write-Host "=== CONFIGURANDO AWS GLUE ===" -ForegroundColor Cyan

# 1. Subir scripts ETL a S3
Write-Host "`n[1/4] Subiendo scripts de Spark a S3..."
aws s3 cp "$PSScriptRoot/energy_aggregation_daily.py" "s3://$env:BUCKET_NAME/scripts/energy_aggregation_daily.py"

# 2. Configurar Base de Datos
Write-Host "`n[2/4] Verificando Base de Datos..."
aws glue create-database --database-input "{\`"Name\`":\`"energy_db\`"}" 2>$null

# 3. Crawler
aws glue delete-crawler --name energy_raw_crawler 2>$null

$TARGET_PATH = "s3://$env:BUCKET_NAME/raw/energy_consumption/"
$TARGETS_JSON = '{\"S3Targets\": [{\"Path\": \"' + $TARGET_PATH + '\"}]}'

Write-Host "Creando Crawler..."
aws glue create-crawler `
    --name energy_raw_crawler `
    --role $env:ROLE_ARN `
    --database-name energy_db `
    --targets $TARGETS_JSON

# 4. Crear Job de Spark
Write-Host "`n[3/4] Creando Job ETL (Daily Aggregation)..."
aws glue delete-job --job-name energy_daily_job 2>$null

aws glue create-job `
    --name energy_daily_job `
    --role $env:ROLE_ARN `
    --command '{"Name": "glueetl", "ScriptLocation": "s3://' + $env:BUCKET_NAME + '/scripts/energy_aggregation_daily.py", "PythonVersion": "3"}' `
    --default-arguments '{
        "--database": "energy_db",
        "--table_name": "energy_consumption",
        "--output_path": "s3://' + $env:BUCKET_NAME + '/processed/daily/",
        "--job-language": "python"
    }' `
    --glue-version "4.0" `
    --number-of-workers 2 `
    --worker-type "G.1X"

# 5. Ejecución inicial
Write-Host "`n[4/4] Iniciando Crawler (Primer escaneo)..."
aws glue start-crawler --name energy_raw_crawler

Write-Host "Glue configurado. El Crawler está corriendo." -ForegroundColor Green
Write-Host "Cuando el Crawler termine, podrás ver la tabla 'energy_consumption' en Glue Data Catalog."
Write-Host "Después, ejecuta el job con: aws glue start-job-run --job-name energy_daily_job"