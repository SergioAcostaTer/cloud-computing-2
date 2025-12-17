import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import col, sum as spark_sum, avg, substring

# 1. Init
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'database', 'table_name', 'output_path'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

database = args['database']
table_name = args['table_name']
output_path = args['output_path']

# 2. Read from Catalog (Data from Crawler)
datasource = glueContext.create_dynamic_frame.from_catalog(
    database=database,
    table_name=table_name,
    transformation_ctx="datasource"
)

df = datasource.toDF()

# 3. Transform
# Extract date (YYYY-MM-DD) from timestamp
df_transformed = df.withColumn("fecha_reporte", substring(col("timestamp_origen"), 1, 10))

# Aggregate: Sum value, Avg percentage by Date/Type
daily_agg = df_transformed.groupBy("fecha_reporte", "tipo") \
    .agg(
        spark_sum("valor").alias("total_valor_mw"),
        avg("porcentaje").alias("avg_porcentaje")
    )

# Repartition for optimal writes
daily_agg = daily_agg.repartition("fecha_reporte")

# 4. Write to S3 (Parquet)
output_dyf = glueContext.create_dynamic_frame.from_catalog(
    database=database,
    table_name=table_name
).fromDF(daily_agg, glueContext, "output_dyf")

glueContext.write_dynamic_frame.from_options(
    frame=output_dyf,
    connection_type="s3",
    connection_options={
        "path": output_path,
        "partitionKeys": ["fecha_reporte"]
    },
    format="parquet",
    format_options={"compression": "snappy"},
    transformation_ctx="datasink"
)

job.commit()