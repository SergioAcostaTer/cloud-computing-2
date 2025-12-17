import boto3
from loguru import logger
import time
import json
import os

# Constants
STREAM_NAME = 'consumo-energetico-stream'
INPUT_FILE = '../data/mydata.json'

kinesis = boto3.client('kinesis')

def load_data(path: str):
    if not os.path.exists(path):
        logger.error(f"File not found: {path}")
        raise FileNotFoundError(f"File not found: {path}")
    
    with open(path, 'r') as f:
        return json.load(f)

def run_producer():
    try:
        data = load_data(INPUT_FILE)
    except Exception as e:
        logger.error(str(e))
        return

    records_sent = 0 
    devices_list = data.get('devices', [])

    logger.info(f"Starting transmission to {STREAM_NAME} using {INPUT_FILE}")

    for device in devices_list:
        # Extract device level info
        dev_type = device.get('type', 'Unknown')
        dev_id = device.get('id', 'Unknown')
        dev_data = device.get('data', {})
        dev_label = dev_data.get('label', 'Unknown')
        
        # Get readings list
        readings = dev_data.get('readings', [])

        logger.info(f"Processing device: {dev_label} ({dev_id}) - {len(readings)} readings")

        for reading in readings:
            # Construct flattened payload including new metrics
            payload = {
                # Keys used for Partitioning/Grouping
                'tipo': dev_type,
                'device_id': dev_id,
                'device_label': dev_label,
                
                # Metrics
                'valor': reading.get('value'),
                'porcentaje': reading.get('percentage'),
                'voltage': reading.get('voltage_v'),
                'current': reading.get('current_a'),
                'temperature': reading.get('temperature_c'),
                'status': reading.get('status'),
                
                # Timestamp
                'timestamp_origen': reading.get('timestamp')
            }

            # Send to Kinesis
            try:
                response = kinesis.put_record(
                    StreamName=STREAM_NAME,
                    Data=json.dumps(payload) + '\n',  
                    PartitionKey=dev_id
                )
                
                records_sent += 1
                if records_sent % 10 == 0:
                    logger.info(f"Sent total {records_sent} records...")
                
                # Rate limiting to simulate streaming
                time.sleep(0.05)
                
            except Exception as e:
                logger.error(f"Failed to send record: {e}")

    logger.success(f"Transmission complete. Total records sent: {records_sent}")

if __name__ == "__main__":
    run_producer()