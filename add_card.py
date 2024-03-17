import json
import boto3

ddb = boto3.resource('dynamodb')


def lambda_handler(event, context):

    item = event['body']
    item_dict = json.loads(item)
    table = ddb.Table('snap-collection')
    add = table.put_item(Item=item_dict)
    return {
        'statusCode': 200
    }
