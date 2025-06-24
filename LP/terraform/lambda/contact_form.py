import json
import os
import boto3

DEST_EMAIL = os.environ.get("DEST_EMAIL")
SOURCE_EMAIL = os.environ.get("SOURCE_EMAIL")

ses = boto3.client("ses")


def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))
        name = body.get("name", "")
        email = body.get("email", "")
        message = body.get("message", "")

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
