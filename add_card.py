import json
import boto3

ddb = boto3.resource('dynamodb')


def lambda_handler(event, context):

    table = ddb.Table('snap-collection')
    add = table.put_item(Item=event)
    return {
        'statusCode': 200
    }
