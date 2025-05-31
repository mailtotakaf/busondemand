import json
import boto3
from datetime import datetime

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("bus_locations")

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
}


def lambda_handler(event, context):
    method = event.get("requestContext", {}).get("http", {}).get("method", "")

    if method == "OPTIONS":
        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": "",
        }

    try:
        body_str = event.get("body", "{}")
        body = json.loads(body_str)

        print("body:", body)
        bus_id = body["busId"]
        latitude = body["latitude"]
        longitude = body["longitude"]
        timestamp = body.get("timestamp", datetime.utcnow().isoformat())

        table.put_item(
            Item={
                "busId": bus_id,
                "latitude": str(latitude),
                "longitude": str(longitude),
                "timestamp": timestamp,
            }
        )

        print("🚍 位置情報を保存しました:", bus_id, latitude, longitude, timestamp)
        return {
            "statusCode": 200,
            "body": json.dumps({"message": "位置情報を保存しました"}),
            "headers": CORS_HEADERS,
        }

    except Exception as e:
        print("Internal Server Error:", e)
        return {
            "statusCode": 405,
            "body": json.dumps({"error": "Method not allowed"}),
            "headers": CORS_HEADERS,
        }
