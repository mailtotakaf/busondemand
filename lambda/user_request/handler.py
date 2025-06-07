import json
import boto3
from decimal import Decimal
from douglas_peucker import douglas_peucker
from datetime import datetime, timezone

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("user_requests")

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "OPTIONS,POST,GET",
    "Access-Control-Allow-Headers": "Content-Type",
}


def lambda_handler(event, context):
    if event.get("requestContext", {}).get("http", {}).get("method") == "OPTIONS":
        return {"statusCode": 200, "headers": CORS_HEADERS, "body": ""}

    try:
        body = json.loads(event["body"]) if "body" in event else event
        print("Received body:", body)

        item = {
            "requestId": body["requestId"],
            "userId": body["userId"],
            "selectedType": body["selectedType"],
            "passengerCount": body["passengerCount"],
            "pickup": convert_floats_to_decimals(body["pickup"]),
            "dropoff": convert_floats_to_decimals(body["dropoff"]),
            "pickupTime": body["pickup"]["pickupTime"],
            "dropoffTime": body["dropoff"]["dropoffTime"],
            "busId": body["busId"],
            "simplified_route": convert_floats_to_decimals(body["simplified_route"]),
            "status": "pending",
        }
        # print("item:", item)

        table.put_item(Item=item)
        print("Item added to DynamoDB.")

        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Success", "requestId": item["requestId"]}),
            "headers": CORS_HEADERS,
        }
    except Exception as e:
        print("Error:", e)
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Server Error", "error": str(e)}),
            "headers": CORS_HEADERS,
        }


def convert_floats_to_decimals(obj):
    if isinstance(obj, list):
        return [convert_floats_to_decimals(item) for item in obj]
    elif isinstance(obj, dict):
        return {k: convert_floats_to_decimals(v) for k, v in obj.items()}
    elif isinstance(obj, float):
        return Decimal(str(obj))
    else:
        return obj
