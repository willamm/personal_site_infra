
import boto3
import os
import json
import logging

table_name = os.environ['DDB_TABLE']

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    logger.info(event)
    body = json.loads(event['body'])
    response = table.update_item(
        Key={
            'id': body['site']
        },
        UpdateExpression='ADD ' + 'visits' + ':incr',
        ExpressionAttributeValues={
            ':incr': 1
        },
        ReturnValues="UPDATED_NEW"
    )
    count = response['Attributes']['visits']
    # TODO: update HTTP headers
    return {
        'statusCode': 200,
        'body': count
    }    