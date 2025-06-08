import boto3
import os
import json

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    email = event.get("queryStringParameters", {}).get("email")

    if not email:
        return {"statusCode": 400, "body": "Missing 'email' query parameter"}

    response = table.get_item(Key={"email": email})
    item = response.get("Item")

    if not item:
        return {"statusCode": 404, "body": "Driver not found"}

    return {"statusCode": 200, "body": json.dumps(item)}
