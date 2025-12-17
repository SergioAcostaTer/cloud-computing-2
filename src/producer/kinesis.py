import boto3
from loguru import logger
import time
import json

# Constants
STREAM_NAME = 'consumo-energetico-stream'
INPUT_FILE = '../data/datos.json'

kinesis = boto3.client('kinesis')

def load_data(path: str):
    with open(path, 'r') as f:
        return json.load(f)

def run_producer():
    data = load_data(INPUT_FILE)
    records_sent = 0 
    series_list = data.get('included', [])

    logger.info(f"Starting transmission to {STREAM_NAME}")

    for serie in series_list:
        tipo_demanda = serie['attributes']['title']
        valores = serie['attributes']['values']

        for registro in valores:
            payload = {
                'tipo': tipo_demanda,
                'valor': registro['value'],
                'timestamp_origen': registro['datetime'],
                'porcentaje': registro['percentage'],
            }

            # Send to Kinesis
            # Note: Added newline for Firehose compatibility
            response = kinesis.put_record(
                StreamName=STREAM_NAME,
                Data=json.dumps(payload) + '\n',  
                PartitionKey=tipo_demanda
            )
            
            records_sent += 1
            logger.info(f"Sent record {records_sent}")
            
            # Rate limiting
            time.sleep(0.01)

if __name__ == "__main__":
    run_producer()