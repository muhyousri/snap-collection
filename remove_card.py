import json
import boto3

ddb = boto3.resource('dynamodb')


def lambda_handler(event, context):

    table = ddb.Table('snap-collection')
    table.delete_item(
        Key={
            'card_id': event['card_id']
        })
    return {'statusCode': 200}
