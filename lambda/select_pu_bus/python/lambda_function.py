import boto3
import json
from decimal import Decimal
import get_buses_info
from boto3.dynamodb.conditions import Attr


ORS_BASE_URL = "https://api.openrouteservice.org/v2/matrix/driving-car"

dynamodb = boto3.resource("dynamodb")

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "OPTIONS,POST,GET",
    "Access-Control-Allow-Headers": "Content-Type",
}


def get_all_bus_locations():
    table = dynamodb.Table("bus_locations")
    response = table.scan()
    return response.get("Items", [])


def get_other_user_requests():
    dynamodb = boto3.resource("dynamodb")
    table = dynamodb.Table("user_requests")
    # "status"が"complete"、"incident"以外のレコードを取得
    response = table.scan(
        FilterExpression=Attr("status").ne("complete") & Attr("status").ne("incident")
    )
    return response["Items"]


def lambda_handler(event, context):
    try:
        if isinstance(event.get("body"), str):
            event = json.loads(event["body"])

        json_str = json.dumps(event, ensure_ascii=False)
        print("json_str:", json_str)

        passengerCount = event["passengerCount"]
        wheelchair = event["wheelchair"]
        wheelchairCount = event["wheelchairCount"]
        requests = event["requests"]
        selectedType = event["selectedType"]
        requestDateTime = event["requestDateTime"]
        pickup = event["pickup"]
        dropoff = event["dropoff"]

        apploxDurationMin, simplified_route = get_buses_info.get_ors_info(
            pickup, dropoff
        )

        other_user_requests = get_other_user_requests()
        # buses_info_map = get_buses_info.buses_info(
        #     other_user_requests, event, apploxDurationMin
        # )
        print("other_user_requests:", other_user_requests)

        buses_info_map = get_buses_info.buses_info(other_user_requests, event)
        print("buses_info_map:", buses_info_map)

        other_routes = []
        for item in other_user_requests:
            other_routes.append(
                {
                    "requestId": item["requestId"],
                    "simplified_route": [
                        {
                            "latitude": float(point["latitude"]),
                            "longitude": float(point["longitude"]),
                        }
                        for point in item["simplified_route"]
                    ],
                }
            )

        # apploxDurationMin, simplified_route = get_buses_info.get_ors_2(pickup, dropoff)
        print("lambda_handler end.")
        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps(
                {
                    "simplified_route": simplified_route,
                    "other_routes": other_routes,
                    "apploxDurationMin": apploxDurationMin,
                    "buses_info_map": buses_info_map,
                },
            ),
        }
    except Exception as e:
        print("Error:", str(e))
        # print("ORS Error:", response.text if response else str(e))
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
