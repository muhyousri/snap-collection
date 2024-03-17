import json
import boto3

ddb = boto3.resource('dynamodb')


def lambda_handler(event, context):
    payload = event['body']
    payload_dict = json.loads(payload)
    table = ddb.Table('snap-collection')
    table.delete_item(
        Key={
            'card_id': payload_dict['card_id']
        })
    return {'statusCode': 200}
