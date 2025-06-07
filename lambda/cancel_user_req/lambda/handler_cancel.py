import json
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("user_requests")

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "OPTIONS,POST,GET",
    "Access-Control-Allow-Headers": "Content-Type",
}


def lambda_handler(event, context):
    # プリフライトリクエスト対応
    if event.get("httpMethod", "") == "OPTIONS":
        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps({"message": "CORS preflight"}),
        }

    try:
        body = json.loads(event["body"])
        print("Received body:", body)

        table.update_item(
            Key={
                "busId": body["busId"],
                "requestId": body["requestId"],
            },
            UpdateExpression="SET #s = :canceled",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":canceled": "canceled"},
        )

        return {
            "headers": CORS_HEADERS,
            "statusCode": 200,
            "body": json.dumps({"message": "Canceled"}),
        }
    except Exception as e:
        return {
            "headers": CORS_HEADERS,
            "statusCode": 500,
            "body": json.dumps({"error": str(e)}),
        }
