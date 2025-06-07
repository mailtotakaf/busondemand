import json
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("user_requests")


def lambda_handler(event, context):
    print("Received event:", event)
    try:
        body = json.loads(event["body"])

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
            "statusCode": 200,
            "body": json.dumps({"message": "Canceled"}),
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)}),
        }
