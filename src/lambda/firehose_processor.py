import json
import base64
import datetime

def lambda_handler(event, context):
    """
    Recibe registros de Firehose, decodifica, agrega fecha de procesamiento
    y define la partition key para S3.
    """
    output = []
    
    for record in event['records']:
        try:
            # 1. Decodificar data (viene en base64)
            payload = base64.b64decode(record['data']).decode('utf-8')
            data_json = json.loads(payload)
            
            # 2. Lógica de negocio: Obtener fecha para partición
            processing_time = datetime.datetime.now(datetime.timezone.utc)
            partition_date = processing_time.strftime('%Y-%m-%d')


            # 3. Preparar registro de salida
            # Firehose necesita que devolvamos los datos codificados de nuevo
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
            # Si falla, mandamos a bucket de error
            print(f"Error processing record: {e}")
            output_record = {
                'recordId': record['recordId'],
                'result': 'ProcessingFailed',
                'data': record['data']
            }
            output.append(output_record)
    
    return {'records': output}