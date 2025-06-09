import boto3
import os
import json

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "OPTIONS,POST,GET",
    "Access-Control-Allow-Headers": "Content-Type",
}


def lambda_handler(event, context):
    email = event.get("queryStringParameters", {}).get("email")

    if not email:
        return {
            "headers": CORS_HEADERS,
            "statusCode": 400,
            "body": "Missing 'email' query parameter",
        }

    response = table.get_item(Key={"email": email})
    item = response.get("Item")

    if not item:
        return {"headers": CORS_HEADERS, "statusCode": 404, "body": "Driver not found"}

    return {"headers": CORS_HEADERS, "statusCode": 200, "body": json.dumps(item)}
