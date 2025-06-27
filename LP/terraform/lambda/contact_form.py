import json
import os
import boto3
import logging
import uuid
from datetime import datetime
logger = logging.getLogger()
logger.setLevel(logging.INFO)

DEST_EMAIL = os.environ.get("DEST_EMAIL")
SOURCE_EMAIL = os.environ.get("SOURCE_EMAIL")

ses = boto3.client("ses")


def lambda_handler(event, context):
    try:
        if event["requestContext"]["http"]["method"] == "OPTIONS":
            return {
                "statusCode": 200,
                "headers": {
                    "Access-Control-Allow-Origin": "*",
                    "Access-Control-Allow-Methods": "POST, OPTIONS",
                    "Access-Control-Allow-Headers": "Content-Type",
                },
                "body": json.dumps({"message": "CORS preflight OK"}),
            }

        body = json.loads(event.get("body", "{}"))
        name = body.get("name", "")
        email = body.get("email", "")
        message = body.get("message", "")

        # 送信直前にログ出力
        logger.info(f"Sending email from {SOURCE_EMAIL} to {DEST_EMAIL}")
        
        response = ses.send_email(
            Source=SOURCE_EMAIL,
            Destination={"ToAddresses": [DEST_EMAIL]},
            Message={
                "Subject": {"Data": f"新しい問い合わせ：{name}"},
                "Body": {
                    "Text": {
                        "Data": f"名前: {name}\nメール: {email}\n\nメッセージ:\n{message}"
                    }
                },
            },
        )

        dynamodb = boto3.resource("dynamodb")
        table = dynamodb.Table("contact_messages")

        # 送信直前にDynamoDBに保存
        table.put_item(Item={
            "id": str(uuid.uuid4()),
            "timestamp": datetime.utcnow().isoformat(),
            "name": name,
            "email": email,
            "message": message
        })

        return {
            "statusCode": 200,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"message": "送信完了しました"}),
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)}),
        }
