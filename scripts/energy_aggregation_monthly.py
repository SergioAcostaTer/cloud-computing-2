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

# 2. Read from Catalog
datasource = glueContext.create_dynamic_frame.from_catalog(
    database=database,
    table_name=table_name,
    transformation_ctx="datasource"
)

df = datasource.toDF()

# 3. Transform (Monthly)
# Extract YYYY-MM
df_transformed = df.withColumn("fecha_mes", substring(col("timestamp_origen"), 1, 7))

# Aggregate by Month/Type
monthly_agg = df_transformed.groupBy("fecha_mes", "tipo") \
    .agg(
        spark_sum("valor").alias("total_valor"),
        avg("porcentaje").alias("avg_porcentaje"),
        avg("temperature").alias("avg_temperature_c"),
        avg("voltage").alias("avg_voltage_v")
    )

monthly_agg = monthly_agg.repartition("fecha_mes")

# 4. Write to S3
output_dyf = glueContext.create_dynamic_frame.from_catalog(
    database=database,
    table_name=table_name
).fromDF(monthly_agg, glueContext, "output_dyf")

glueContext.write_dynamic_frame.from_options(
    frame=output_dyf,
    connection_type="s3",
    connection_options={
        "path": output_path,
        "partitionKeys": ["fecha_mes"]
    },
    format="parquet",
    format_options={"compression": "snappy"},
    transformation_ctx="datasink"
)

job.commit()