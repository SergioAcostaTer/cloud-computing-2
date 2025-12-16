. "$PSScriptRoot/config/variables.ps1"

Write-Host "=== CONFIGURANDO AWS GLUE ===" -ForegroundColor Cyan

# 1. Subir scripts ETL a S3
Write-Host "`n[1/4] Subiendo scripts de Spark a S3..."
aws s3 cp "$PSScriptRoot/energy_aggregation_daily.py" "s3://$env:BUCKET_NAME/scripts/energy_aggregation_daily.py"
aws s3 cp "$PSScriptRoot/energy_aggregation_monthly.py" "s3://$env:BUCKET_NAME/scripts/energy_aggregation_monthly.py"

# 2. Configurar Base de Datos
Write-Host "`n[2/4] Verificando Base de Datos..."
# Usamos escapeo robusto \" para asegurar que llegue el JSON válido
aws glue create-database --database-input "{\"Name\":\"energy_db\"}" 2>$null

# 3. Crawler
# Eliminamos el anterior si existe
aws glue delete-crawler --name energy_raw_crawler 2>$null

$TARGET_PATH = "s3://$env:BUCKET_NAME/raw/energy_consumption/"
# SOLUCIÓN JSON: Usamos comillas simples fuera y escapamos las dobles dentro con backslash \"
$TARGETS_JSON = '{\"S3Targets\": [{\"Path\": \"' + $TARGET_PATH + '\"}]}'

Write-Host "Creando Crawler..."
aws glue create-crawler `
    --name energy_raw_crawler `
    --role $env:ROLE_ARN `
    --database-name energy_db `
    --targets $TARGETS_JSON

# 4. Crear Jobs de Spark
Write-Host "`n[3/4] Creando Jobs ETL..."

# --- JOB DIARIO ---
Write-Host "   - Configurando Job Diario..."
aws glue delete-job --job-name energy_daily_job 2>$null

$DailyScriptLoc = "s3://$env:BUCKET_NAME/scripts/energy_aggregation_daily.py"
$DailyOutputPath = "s3://$env:BUCKET_NAME/processed/daily/"

# Construcción robusta de JSON con escapeo \"
$DailyCommand = '{\"Name\": \"glueetl\", \"ScriptLocation\": \"' + $DailyScriptLoc + '\", \"PythonVersion\": \"3\"}'
$DailyDefaultArgs = '{\"--database\": \"energy_db\", \"--table_name\": \"energy_consumption\", \"--output_path\": \"' + $DailyOutputPath + '\", \"--job-language\": \"python\"}'

aws glue create-job `
    --name energy_daily_job `
    --role $env:ROLE_ARN `
    --command $DailyCommand `
    --default-arguments $DailyDefaultArgs `
    --glue-version "4.0" `
    --number-of-workers 2 `
    --worker-type "G.1X"

# --- JOB MENSUAL ---
Write-Host "   - Configurando Job Mensual..."
aws glue delete-job --job-name energy_monthly_job 2>$null

$MonthlyScriptLoc = "s3://$env:BUCKET_NAME/scripts/energy_aggregation_monthly.py"
$MonthlyOutputPath = "s3://$env:BUCKET_NAME/processed/monthly/"

$MonthlyCommand = '{\"Name\": \"glueetl\", \"ScriptLocation\": \"' + $MonthlyScriptLoc + '\", \"PythonVersion\": \"3\"}'
$MonthlyDefaultArgs = '{\"--database\": \"energy_db\", \"--table_name\": \"energy_consumption\", \"--output_path\": \"' + $MonthlyOutputPath + '\", \"--job-language\": \"python\"}'

aws glue create-job `
    --name energy_monthly_job `
    --role $env:ROLE_ARN `
    --command $MonthlyCommand `
    --default-arguments $MonthlyDefaultArgs `
    --glue-version "4.0" `
    --number-of-workers 2 `
    --worker-type "G.1X"

# 5. Ejecución inicial
Write-Host "`n[4/4] Iniciando Crawler (Primer escaneo)..."
aws glue start-crawler --name energy_raw_crawler

Write-Host "Glue configurado. El Crawler está corriendo." -ForegroundColor Green
Write-Host "Cuando el Crawler termine, podrás ver la tabla 'energy_consumption' en Glue Data Catalog."
Write-Host "Después, ejecuta los jobs:"
Write-Host "  aws glue start-job-run --job-name energy_daily_job"
Write-Host "  aws glue start-job-run --job-name energy_monthly_job"