import json
import base64
import datetime

def lambda_handler(event, context):
    """
    Decodes Firehose records, adds 'processing_date' for partitioning,
    and re-encodes data.
    """
    output = []
    
    for record in event['records']:
        try:
            # 1. Decode (base64 -> json)
            payload = base64.b64decode(record['data']).decode('utf-8')
            data_json = json.loads(payload)
            
            # 2. Logic: Extract date for partition key
            processing_time = datetime.datetime.now(datetime.timezone.utc)
            partition_date = processing_time.strftime('%Y-%m-%d')

            # 3. Prepare output
            # Firehose expects data re-encoded in base64
            output_record = {
                'recordId': record['recordId'],
                'result': 'Ok',
                'data': base64.b64encode((json.dumps(data_json) + '\n').encode('utf-8')).decode('utf-8'),
                'metadata': {
                    'partitionKeys': {
                        'processing_date': partition_date
                    }
                }
            }
            output.append(output_record)
            
        except Exception as e:
            # Send to error bucket if failed
            print(f"Error processing record: {e}")
            output_record = {
                'recordId': record['recordId'],
                'result': 'ProcessingFailed',
                'data': record['data']
            }
            output.append(output_record)
    
    return {'records': output}