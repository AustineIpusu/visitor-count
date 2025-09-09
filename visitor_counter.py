import json
import boto3
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('VisitorCount')

def lambda_handler(event, context):
    try:
        logger.info("Event: " + json.dumps(event))
        
        site_name = "MyPortfolio"
        
        # Try to get the current count
        response = table.get_item(Key={'SiteName': site_name})
        current_count = response.get('Item', {}).get('Count', 0)
        
        # Increment the count
        new_count = current_count + 1
        logger.info(f"Old count: {current_count}, New count: {new_count}")
        
        # Store the new count
        table.put_item(Item={'SiteName': site_name, 'Count': new_count})
        
        # Return a successful response
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({
                "message": "Welcome to my site!",
                "visitor_count": new_count
            })
        }
        
    except Exception as e:
        logger.error("Error: " + str(e))
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Internal server error. Check logs."})
        }