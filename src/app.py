import boto3
import os
import json
import logging


logger = logging.getLogger()
logger.setLevel(logging.INFO)

def get_table_resource():
    dynamodb = boto3.resource('dynamodb', region_name=os.environ['AWS_REGION'])
    table_name = os.environ['DDB_TABLE']
    return dynamodb.Table(table_name)

# Updates the site visit count by 1 and returns the new value.
def update_db(body):
    table = get_table_resource()
    response = table.update_item(
        Key={
            'id': body['site']
        },
        UpdateExpression="ADD visits :incr",
        ExpressionAttributeValues={
            ':incr': 1
        },
        ReturnValues="UPDATED_NEW"
    )
    return response['Attributes']['visits']

def lambda_handler(event, context):
    logger.info(event)
    body = json.loads(event['body'])
    count = update_db(body)
    # TODO: update HTTP headers
    return {
        'statusCode': 200,
        'body': count
    }    