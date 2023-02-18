import pytest
import moto
import boto3
import json
import os

lambda_event = {'version': '1.0', 'resource': '/count', 'path': '/v1/count', 'httpMethod': 'POST', 'headers': {'Content-Length': '12', 'Content-Type': 'application/json', 'Host': 'api.williamm.me', 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/109.0', 'X-Amzn-Trace-Id': 'Root=1-63f11a32-3607fd8914bbaa987332460e', 'X-Forwarded-For': '24.207.46.118, 172.71.147.146', 'X-Forwarded-Port': '443', 'X-Forwarded-Proto': 'https', 'accept': 'application/json', 'accept-encoding': 'gzip', 'accept-language': 'en-US,en;q=0.5', 'cdn-loop': 'cloudflare', 'cf-connecting-ip': '24.207.46.118', 'cf-ipcountry': 'CA', 'cf-ray': '79b8db58dbeb281c-SEA', 'cf-visitor': '{"scheme":"https"}', 'dnt': '1', 'origin': 'https://williamm.me', 'referer': 'https://williamm.me/', 'sec-fetch-dest': 'empty', 'sec-fetch-mode': 'cors', 'sec-fetch-site': 'same-site', 'sec-gpc': '1'}, 'multiValueHeaders': {'Content-Length': ['12'], 'Content-Type': ['application/json'], 'Host': ['api.williamm.me'], 'User-Agent': ['Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/109.0'], 'X-Amzn-Trace-Id': ['Root=1-63f11a32-3607fd8914bbaa987332460e'], 'X-Forwarded-For': ['24.207.46.118, 172.71.147.146'], 'X-Forwarded-Port': ['443'], 'X-Forwarded-Proto': ['https'], 'accept': ['application/json'], 'accept-encoding': ['gzip'], 'accept-language': ['en-US,en;q=0.5'], 'cdn-loop': ['cloudflare'], 'cf-connecting-ip': ['24.207.46.118'], 'cf-ipcountry': ['CA'], 'cf-ray': ['79b8db58dbeb281c-SEA'], 'cf-visitor': ['{"scheme":"https"}'], 'dnt': ['1'], 'origin': ['https://williamm.me'], 'referer': ['https://williamm.me/'], 'sec-fetch-dest': ['empty'], 'sec-fetch-mode': ['cors'], 'sec-fetch-site': ['same-site'], 'sec-gpc': ['1']}, 'queryStringParameters': None, 'multiValueQueryStringParameters': None, 'requestContext': {'accountId': '102317976783', 'apiId': '5qq2syjpff', 'domainName': 'api.williamm.me', 'domainPrefix': 'api', 'extendedRequestId': 'AjEH4hX0oAMEMTg=', 'httpMethod': 'POST', 'identity': {'accessKey': None, 'accountId': None, 'caller': None, 'cognitoAmr': None, 'cognitoAuthenticationProvider': None, 'cognitoAuthenticationType': None, 'cognitoIdentityId': None, 'cognitoIdentityPoolId': None, 'principalOrgId': None, 'sourceIp': '172.71.147.146', 'user': None, 'userAgent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/109.0', 'userArn': None}, 'path': '/count', 'protocol': 'HTTP/1.1', 'requestId': 'AjEH4hX0oAMEMTg=', 'requestTime': '18/Feb/2023:18:34:26 +0000', 'requestTimeEpoch': 1676745266103, 'resourceId': 'POST /count', 'resourcePath': '/count', 'stage': '$default'}, 'pathParameters': None, 'stageVariables': None, 'body': '{"site":"/"}', 'isBase64Encoded': False}

@pytest.fixture(scope="function")
def aws_credentials():
    """ Mocked AWS credentials for moto. """
    os.environ["AWS_ACCESS_KEY_ID"] = "testing"
    os.environ["AWS_SECRET_ACCESS_KEY"] = "testing"
    os.environ["AWS_SECURITY_TOKEN"] = "testing"
    os.environ["AWS_SESSION_TOKEN"] = "testing"
    os.environ["AWS_DEFAULT_REGION"] = "us-east-1"
    os.environ["AWS_REGION"] = "us-east-1"
    os.environ["DDB_TABLE"] = "count-table"

@pytest.fixture(scope="function")
def data_table(aws_credentials):
    TABLE_NAME = "count-table"
    with moto.mock_dynamodb():
        ddb = boto3.resource("dynamodb", region_name="us-east-1")
        ddb.create_table(
            AttributeDefinitions=[
                {"AttributeName": "id", "AttributeType": "S"}
            ],
            TableName=TABLE_NAME,
            KeySchema=[
                {"AttributeName": "id", "KeyType": "HASH"}
            ],
            BillingMode="PROVISIONED",
            ProvisionedThroughput={
                "ReadCapacityUnits":20, "WriteCapacityUnits":20
            },
            
        )
        yield TABLE_NAME

@pytest.fixture(scope="function")
def data_table_with_data(data_table):
    table = boto3.resource("dynamodb").Table(data_table)
    items = [
        {"id": "/", "visits": 2},
    ]
    table.put_item(Item={
        'id': "/",
        'visits': 2
    })

def test_lambda(data_table_with_data):
    import app
    key = json.loads(lambda_event['body'])
    count = app.update_db(key)
    assert count == 3
    


