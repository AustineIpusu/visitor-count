import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('VisitorCount')

def lambda_handler(event, context):
    try:
        # Parse data from the API request
        body = json.loads(event['body'])
        site_name = body['siteName']
        count = body['count']
        
        # Put item into DynamoDB
        table.put_item(
            Item={
                'SiteName': site_name,
                'Count': count
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Data stored successfully!'})
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }