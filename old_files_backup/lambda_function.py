import json

def lambda_handler(event, context):
    # This is your function logic
    response = {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps({
            "message": "Hello from your first serverless function!",
            "input": event
        })
    }
    return response