
import boto3
import os
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb_client = boto3.client('dynamodb')

def lambda_handler(event, context):
  table = os.environ.get('DDB_TABLE')
   
  http_method = event.get('httpMethod')
  if http_method == 'POST':
    if event['path'] == '/currentCount':
    
        response = dynamodb_client.describe_table(TableName=table)['Table']['ItemCount']
        return {
            'statusCode': 200,
            'body': response
        }
    elif event['path'] == '/incrementCount':
        response = dynamodb_client.put_item(TableName=table, Item={'stat': 'test'})
        return {
            'statusCode': 200,
            'body': response
        }

