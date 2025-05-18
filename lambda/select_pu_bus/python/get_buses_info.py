import boto3
import json
import math
import os
import requests
from datetime import datetime, timedelta
from douglas_peucker import douglas_peucker
from math import radians, cos, sin, asin, sqrt

ORS_API_KEY = os.environ["ORS_API_KEY"]
dynamodb = boto3.resource("dynamodb")


def get_bus_status():
    table = dynamodb.Table("bus_status")
    response = table.scan()
    return response.get("Items", [])


def euclidean_distance(lat1, lon1, lat2, lon2):
    return math.sqrt((lat1 - lat2) ** 2 + (lon1 - lon2) ** 2)


def euclidean(lat1, lon1, lat2, lon2):
    dx = (lon1 - lon2) * 111000 * math.cos(math.radians((lat1 + lat2) / 2))
    dy = (lat1 - lat2) * 111000
    return math.sqrt(dx**2 + dy**2)  # m


def haversine(lon1, lat1, lon2, lat2):
    # 地球半径（メートル）
    R = 6371000
    lon1, lat1, lon2, lat2 = map(radians, [lon1, lat1, lon2, lat2])
    dlon = lon2 - lon1
    dlat = lat2 - lat1
    a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    c = 2 * asin(sqrt(a))
    return R * c


def estimate_boarding_and_dropoff_point(bus, user_pickup, user_dropoff):
    route = bus.get("simplified_route", [])
    if not route or len(route) < 2:
        return None

    pickup_time = datetime.strptime(bus["pickupTime"], "%Y-%m-%d %H:%M:%S")
    dropoff_time = datetime.strptime(str(bus["dropoffTime"]), "%Y-%m-%d %H:%M:%S")
    total_seconds = (dropoff_time - pickup_time).total_seconds()

    # print("route:", route)
    points = [(float(p["longitude"]), float(p["latitude"])) for p in route]
    # print("points:", points)

    # ルート距離計算
    cum_distances = [0]
    total_dist = 0
    for i in range(1, len(points)):
        d = haversine(*points[i - 1], *points[i])
        total_dist += d
        cum_distances.append(total_dist)

    def get_closest_info(target_point):
        min_idx = min(
            range(len(points)),
            key=lambda i: haversine(
                points[i][0],
                points[i][1],  # (lon, lat)
                target_point[0],
                target_point[1],  # (lon, lat)
            ),
        )
        dist = haversine(
            points[min_idx][0],
            points[min_idx][1],
            target_point[0],
            target_point[1],
        )
        ratio = cum_distances[min_idx] / total_dist if total_dist else 0
        time = pickup_time + timedelta(seconds=ratio * total_seconds)
        return {
            "index": min_idx,
            "point": (points[min_idx][1], points[min_idx][0]),  # lat, lonに戻すなら
            "distance": dist,
            "time": time.strftime("%H:%M:%S"),
        }

    pickup_info = get_closest_info(user_pickup)
    dropoff_info = get_closest_info(user_dropoff)
    print("user_pickup:", user_pickup)
    print("pickup_info:", pickup_info)
    print("user_dropoff:", user_dropoff)
    print("dropoff_info:", dropoff_info)

    return {
        "busId": bus["busId"],
        "pickup_candidate": pickup_info,
        "dropoff_candidate": dropoff_info,
    }


# 距離[m]をkm/h速度で移動したと仮定し、必要な時間（分）を返す
def estimate_travel_time_min(lat1, lon1, lat2, lon2, speed_kmh=20):
    # print("estimate_travel_time_min start.")
    # 1度 ≒ 111km として近似（大阪周辺ならまあまあOK）
    dx = (lon1 - lon2) * 111000 * math.cos(math.radians((lat1 + lat2) / 2))
    dy = (lat1 - lat2) * 111000
    # distance_m = math.sqrt(dx**2 + dy**2) # 直線距離[m]
    distance_m = dx + dy  # 直角に移動した場合の距離[m]
    speed_mps = speed_kmh * 1000 / 3600  # m/s
    # print("estimate_travel_time_min end.")
    return distance_m / 60 / speed_mps  # 分


def buses_info(buses, userRequest, apploxDurationMin):
    MAX_CAPACITY = 6
    print("userRequest:", userRequest)

    req_dt = datetime.strptime(userRequest["requestDateTime"], "%Y-%m-%d %H:%M")
    selected_type = userRequest["selectedType"]
    requested_passengers = userRequest["passengerCount"]

    req_pu_dt = req_dt - timedelta(minutes=apploxDurationMin)
    print("req_pu_dt:", req_pu_dt)

    # バスIDをキーにして、apploxDurationMin, simplified_routeをMapに格納
    buses_info_map = {}
    for bus in buses:
        print("=====================================bus:", bus)

        dropoff_dt = datetime.strptime(
            bus["dropoffTime"], "%Y-%m-%d %H:%M:%S"
        )

        # print("dropoff_dt:", dropoff_dt)
        # bus["dropoff"]場所からuserRequest["pickup"]場所までの時間
        arrival_min = estimate_travel_time_min(
            float(bus["dropoff"]["latitude"]),
            float(bus["dropoff"]["longitude"]),
            float(userRequest["pickup"][1]),
            float(userRequest["pickup"][0]),
            20,
        )

        arrival_from = dropoff_dt + timedelta(minutes=arrival_min)
        until = arrival_from + timedelta(minutes=apploxDurationMin)
        same_bus_info_map = buses_info_map.get(bus["busId"])
        # print("same_bus_info_map:", same_bus_info_map)
        # if same_bus_info_map is not None:
        #     print("same_bus_info_map.get(arrival_from):", same_bus_info_map.get("arrival_from"))
        # print("arrival_from:", arrival_from)
        if same_bus_info_map:
            print("おなじbusId:", bus["busId"])
            if same_bus_info_map.get("arrival_from") < arrival_from:
                print("このarrival_fromのほうが遅い：")
                print("このbus[pickup]時間に間に合うか")
                pickup_dt = datetime.strptime(
                    bus["pickupTime"], "%Y-%m-%d %H:%M:%S"
                )
                if pickup_dt > same_bus_info_map.get("until"):
                    print("間に合うので、buses_info_map更新なし。スキップします。")
                    continue
                else:
                    print("間に合わないのでbuses_info_mapから削除")
                    del buses_info_map[bus["busId"]]
                    print("削除しました。:", bus["busId"])
            else:
                print("このarrival_fromのほうが早い：")
                print(
                    "ここに差し込んだ場合に、元のbuses_info_mapにあった予定に間に合うか"
                )
                base_pickup = same_bus_info_map.get("base_pickup")
                # print("base_pickup:", base_pickup)
                until_to_base_pu = estimate_travel_time_min(
                    float(bus["dropoff"]["latitude"]),
                    float(bus["dropoff"]["longitude"]),
                    float(base_pickup["latitude"]),
                    float(base_pickup["longitude"]),
                    20,
                )
                base_pickup_time = datetime.strptime(
                    base_pickup.get("pickupTime"), "%Y-%m-%d %H:%M:%S"
                )
                print("base_pickup_time", base_pickup_time)
                # print("until_to_base_pu:", until_to_base_pu)
                print("until + timedelta(minutes=until_to_base_pu:", until + timedelta(minutes=until_to_base_pu))
                if base_pickup_time < (until + timedelta(minutes=until_to_base_pu)):
                    print(
                        "base_pickupに間に合わないので、buses_info_map更新なし。スキップします。"
                    )
                    continue

        if req_pu_dt > arrival_from:
            print(
                "bus[dropoff]時間後にリクエストpu時間に間に合う：buses_info_map更新します。"
            )
            buses_info_map[bus["busId"]] = {
                "base_pickup": bus[
                    "pickup"
                ],  # このpickupに間に合わない場合はbuses_info_map更新禁止！
                "arrival_from": arrival_from,
                "until": until,
            }
            print("buses_info_map更新しました。busId：", bus["busId"])

    # "base_pickup" は不要なので消す
    for bus_id in buses_info_map:
        buses_info_map[bus_id].pop("base_pickup", None)

    # strftime()でstrに変換する
    for bus_id, info in buses_info_map.items():
        info["arrival_from"] = info["arrival_from"].strftime("%Y-%m-%d %H:%M:%S")
        info["until"] = info["until"].strftime("%Y-%m-%d %H:%M:%S")

    return buses_info_map


def get_ors_info(pickup, dropoff):
    if pickup == dropoff:
        print("Same point detected")
        summary = {"distance": 0.0, "duration": 0.0}
        simplified_route = None
        apploxDurationMin = 0
        return apploxDurationMin, simplified_route

    ors = get_ors(pickup, dropoff)
    summary = ors["features"][0]["properties"]["summary"]

    # distance_m = summary["distance"]
    duration_s = summary["duration"]

    # print(f"ORS距離: {distance_m} m")
    # print(f"ORS所要時間: {duration_s / 60:.2f} 分")
    # print(f"ORS時速: {distance_m / duration_s * 3.6:.2f} km/h")
    apploxDurationMin = math.ceil(duration_s / 60 * 2 + 10)

    route_points = ors["features"][0]["geometry"]["coordinates"]
    simplified_route = douglas_peucker(
        convert_coordinates_to_latlng(route_points), epsilon=0.0005
    )

    return apploxDurationMin, simplified_route


def get_ors(pickup, dropoff):
    response = None  # 先に初期化
    body = {
        "coordinates": [pickup, dropoff],
        "format": "geojson",
    }

    headers = {"Authorization": ORS_API_KEY, "Content-Type": "application/json"}

    response = requests.post(
        "https://api.openrouteservice.org/v2/directions/driving-car/geojson",
        headers=headers,
        json=body,
    )
    # print("response:", response)
    response.raise_for_status()
    return response.json()


def convert_coordinates_to_latlng(points):
    result = []
    for lon, lat in points:
        result.append(
            {
                "latitude": float(lat),
                "longitude": float(lon),
            }
        )
    return result
