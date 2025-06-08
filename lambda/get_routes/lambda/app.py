import json
import boto3
from datetime import datetime, timedelta, timezone
from boto3.dynamodb.conditions import Key, Attr

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table("user_requests")


def lambda_handler(event, context):
    print("Received event:", json.dumps(event, indent=2))
    bus_id = event.get("queryStringParameters", {}).get("busId")

    if not bus_id:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Missing busId in query parameters"}),
        }

    try:
        # JST 現在時刻
        jst = timezone(timedelta(hours=9))
        now = datetime.now(jst)
        # today_prefix = now.strftime("%Y-%m-%d")  # 例: "2025-05-11"
        now_str = now.strftime("%Y-%m-%d %H:%M:%S")

        # # 現在日時（JSTをUTCに変換）
        jst = timezone(timedelta(hours=9))
        now_jst = datetime.now(jst)

        # 今日の開始と終了（JST）→ UTCの文字列で比較
        start_time = now_jst.replace(hour=0, minute=0, second=0, microsecond=0)
        end_time = start_time + timedelta(days=1)

        # フォーマット（ISO互換）
        start_str = start_time.strftime("%Y-%m-%d %H:%M:%S")
        end_str = end_time.strftime("%Y-%m-%d %H:%M:%S")
        print("start_str:", start_str)
        print("end_str:", end_str)

        response = table.scan(
            FilterExpression=Attr("busId").eq(bus_id)
            & Attr("pickupTime").between(start_str, end_str)
        )
        items = response.get("Items", [])
        print("items:", items)

        return {
            "statusCode": 200,
            "body": json.dumps(items, default=str),
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Headers": "*",
            },
        }

    except Exception as e:
        print("Error:", str(e))
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
