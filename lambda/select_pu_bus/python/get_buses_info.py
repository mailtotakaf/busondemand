import boto3
import json
import math
import os
import requests
from datetime import datetime, timedelta
from douglas_peucker import douglas_peucker
from math import radians, cos, sin, asin, sqrt
from typing import List, Dict, Any
import math
import re
from datetime import datetime, timedelta
from decimal import Decimal
from typing import List, Dict, Any, Optional

ORS_API_KEY = os.environ["ORS_API_KEY"]
dynamodb = boto3.resource("dynamodb")


def get_bus_locations() -> List[Dict[str, Any]]:
    table = dynamodb.Table("bus_locations")
    resp = table.scan()
    return resp.get("Items", [])


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


def _fmt(info):
    return {
        "arrival_from": info["arrival_from"].strftime("%Y-%m-%d %H:%M:%S"),
        "until": info["until"].strftime("%Y-%m-%d %H:%M:%S"),
    }


def parse_time(time_str: str) -> datetime:
    return datetime.strptime(time_str.strip(), "%Y-%m-%d %H:%M")


# ここから
# ────────────────────────────── 便利関数 ──────────────────────────────
_DT_FMT_OUT = "%Y-%m-%d %H:%M"
_SPEED_KMH = 20  # 平均走行速度
_RELOC_BUFFER_MIN = 10  # 追加で取る余裕（min）…必要なら調整してください


def _parse_dt(txt: str) -> datetime:
    txt = re.sub(r"\s{2,}", " ", txt.strip())
    txt = re.sub(r":\s+", ":", txt)
    if len(txt) == 16:  # 秒が無ければ :00
        txt += ":00"
    return datetime.strptime(txt, "%Y-%m-%d %H:%M:%S")


def _to_f(v):
    """
    Decimal, int, float, str いずれでも → float に変換。
    それ以外は TypeError を投げて気付けるようにする。
    """
    if isinstance(v, (Decimal, int, float)):
        return float(v)
    elif isinstance(v, str):
        return float(v.replace("：", ":").strip())  # 全角コロン対策だけお好みで
    else:
        raise TypeError(f"Unsupported type for lat/lon: {type(v)}")


def travel_min(lat1, lon1, lat2, lon2, speed=_SPEED_KMH) -> float:
    dx = (lon1 - lon2) * 111_000 * math.cos(math.radians((lat1 + lat2) / 2))
    dy = (lat1 - lat2) * 111_000
    dist_m = abs(dx) + abs(dy)
    speed_m_per_min = speed * 1000 / 60
    return dist_m / speed_m_per_min  # 分


# ────────────────────────────── メイン ──────────────────────────────
# ... 省略（共通 util は前回と同じ。_to_f() は str/Decimal 両対応版） ...

def _until_datetime(until_str: str, base_date: datetime) -> datetime:
    """
    '8:00' → base_date 当日の 08:00
    '23:30' → 同日の 23:30。
    依頼時刻より前の場合は「翌日」とみなす。
    """
    t = datetime.strptime(until_str.zfill(5), "%H:%M").time()
    dt = datetime.combine(base_date.date(), t)
    if dt < base_date:
        dt += timedelta(days=1)
    return dt


def buses_info(buses: List[Dict[str, Any]], user_req: Dict[str, Any]) -> Dict[str, Any]:
    if buses:                      # 既存予約がある場合は旧ロジックへ
        return _legacy_schedule_logic(buses, user_req)

    # ───────────────── 空＝“現在地ベース” ─────────────────
    req_drop = _parse_dt(user_req["requestDateTime"])
    pu_lon, pu_lat = user_req["pickup"]
    do_lon, do_lat = user_req["dropoff"]
    pu2do_min = travel_min(pu_lat, pu_lon, do_lat, do_lon)
    latest_pick = req_drop - timedelta(minutes=pu2do_min)

    # 稼働バスの現在地
    locs = [l for l in get_bus_locations() if l.get("status") == "avairable"]
    if not locs:
        return {"earlier": None, "on_time": None, "next_available": None}

    # バスごとの可動ウィンドウを求める
    windows = []
    for loc in locs:
        bus_id = loc["busId"]
        loc_lat = _to_f(loc["latitude"])
        loc_lon = _to_f(loc["longitude"])
        until_dt = _until_datetime(str(loc["until"]), req_drop)

        to_pick_min  = travel_min(loc_lat, loc_lon, pu_lat, pu_lon)
        earliest_pick = datetime.now() + timedelta(minutes=to_pick_min)   # “今すぐ出れば”
        earliest_drop = earliest_pick + timedelta(minutes=pu2do_min)

        latest_drop   = until_dt                         # 勤務終了直前
        latest_pick   = latest_drop - timedelta(minutes=pu2do_min)

        if earliest_drop > latest_drop:                  # 物理的に無理
            continue

        windows.append({
            "busId": bus_id,
            "from_pick": earliest_pick,
            "from_drop": earliest_drop,
            "until_pick": latest_pick,
            "until_drop": latest_drop,
        })

    # on_time 候補： window が req_drop を挟めるもの
    on_pool = [w for w in windows if w["from_drop"] <= req_drop <= w["until_drop"]]
    on_choice = min(on_pool, key=lambda w: w["from_pick"], default=None)

    if on_choice:
        on_time = {
            "busId":       on_choice["busId"],
            "pickupTime":  latest_pick.strftime(_DT_FMT_OUT),
            "dropoffTime": req_drop.strftime(_DT_FMT_OUT)
        }
        chosen_id = on_choice["busId"]
    else:
        on_time   = None
        chosen_id = None

    # earlier: until_drop < req_drop で最も req_drop に近いもの
    earlier_pool = [
        w for w in windows if w["until_drop"] < req_drop and w["busId"] != chosen_id
    ]
    earlier = None
    if earlier_pool:
        e = max(earlier_pool, key=lambda w: w["until_drop"])
        earlier = {
            "from": {
                "busId":      e["busId"],
                "pickupTime": e["from_pick"].strftime(_DT_FMT_OUT),
                "dropoffTime":e["from_drop"].strftime(_DT_FMT_OUT)
            },
            "until": {
                "busId":      e["busId"],
                "pickupTime": e["until_pick"].strftime(_DT_FMT_OUT),
                "dropoffTime":e["until_drop"].strftime(_DT_FMT_OUT)
            }
        }

    # next_available: from_drop > req_drop で最も近いもの
    next_pool = [
        w for w in windows if w["from_drop"] > req_drop and w["busId"] != chosen_id
    ]
    next_available = None
    if next_pool:
        n = min(next_pool, key=lambda w: w["from_drop"])
        next_available = {
            "from": {
                "busId":      n["busId"],
                "pickupTime": n["from_pick"].strftime(_DT_FMT_OUT),
                "dropoffTime":n["from_drop"].strftime(_DT_FMT_OUT)
            },
            "until": {
                "busId":      n["busId"],
                "pickupTime": n["until_pick"].strftime(_DT_FMT_OUT),
                "dropoffTime":n["until_drop"].strftime(_DT_FMT_OUT)
            }
        }

    return {"earlier": earlier, "on_time": on_time, "next_available": next_available}


def _legacy_schedule_logic(
    buses: List[Dict[str, Any]], user_req: Dict[str, Any]
) -> Dict[str, Any]:
    """
    返却例:
    {
        'earlier': {'anytime': True},
        'on_time': {'busId': 'bus_003', 'pickupTime': '...', 'dropoffTime': '...'},
        'next_available': {'until': '...'} | {'anytime': True} | None
    }
    """
    print("get_bus_locations():", get_bus_locations())

    # ── 新規依頼 ─────────────────────────────
    req_drop = _parse_dt(user_req["requestDateTime"])
    pu_lon, pu_lat = user_req["pickup"]
    do_lon, do_lat = user_req["dropoff"]

    pu2do_min = travel_min(pu_lat, pu_lon, do_lat, do_lon)
    latest_pick = req_drop - timedelta(minutes=pu2do_min)

    # バスごとに「直前ジョブ」「直後ジョブ」を抽出（無ければ None）
    candidates = []
    for bus in buses:
        job_pick = _parse_dt(bus["pickupTime"])
        job_drop = _parse_dt(bus["dropoffTime"])

        # 直前／直後の区分
        prev_job = None
        next_job = None
        if job_drop <= latest_pick:
            prev_job = bus  # ジョブ全体が前に終わる
        elif job_pick >= req_drop:
            next_job = bus  # ジョブ全体が後に控える
        else:
            # 依頼と重なるジョブがある場合は今回は対象外
            continue

        # 前ジョブ終了地点 → 新規ピック地点
        if prev_job:
            prev_do_lat = _to_f(prev_job["dropoff"]["latitude"])
            prev_do_lon = _to_f(prev_job["dropoff"]["longitude"])
            prev_do_dt = _parse_dt(prev_job["dropoffTime"])
            to_pick_min = travel_min(prev_do_lat, prev_do_lon, pu_lat, pu_lon)
            earliest_pick = prev_do_dt + timedelta(minutes=to_pick_min)
        else:
            earliest_pick = datetime.min  # いつでも行ける

        # 新規ドロップ → 次ジョブのピック地点
        if next_job:
            next_pi_lat = _to_f(next_job["pickup"]["latitude"])
            next_pi_lon = _to_f(next_job["pickup"]["longitude"])
            next_pi_dt = _parse_dt(next_job["pickupTime"])
            do_to_next_min = travel_min(do_lat, do_lon, next_pi_lat, next_pi_lon)
            latest_drop = next_pi_dt - timedelta(
                minutes=do_to_next_min + _RELOC_BUFFER_MIN
            )
        else:
            latest_drop = datetime.max  # その後も空き

        candidates.append(
            {
                "busId": bus["busId"],
                "earliest_pick": earliest_pick,
                "latest_drop": latest_drop,
            }
        )

    # ── 分類 ─────────────────────────────
    earlier: Optional[Dict[str, Any]] = None
    on_time: Optional[Dict[str, Any]] = None
    next_available: Optional[Dict[str, Any]] = None

    # 1) on-time をまず確保（最短距離のバス）
    on_pool = [
        c
        for c in candidates
        if c["earliest_pick"] <= latest_pick and req_drop <= c["latest_drop"]
    ]
    if on_pool:
        on_choice = min(on_pool, key=lambda c: c["earliest_pick"])
        on_time = {
            "busId": on_choice["busId"],
            "pickupTime": latest_pick.strftime(_DT_FMT_OUT),
            "dropoffTime": req_drop.strftime(_DT_FMT_OUT),
        }

    # 2) earlier:
    if any(c["earliest_pick"] == datetime.min for c in candidates):
        earlier = {"anytime": True}
    else:
        earlier_pool = [c for c in candidates if c["earliest_pick"] < latest_pick]
        if earlier_pool:
            e = min(earlier_pool, key=lambda c: c["earliest_pick"])
            earlier = {
                "busId": e["busId"],
                "pickupTime": e["earliest_pick"].strftime(_DT_FMT_OUT),
                "dropoffTime": (
                    e["earliest_pick"] + timedelta(minutes=pu2do_min)
                ).strftime(_DT_FMT_OUT),
            }

    # 3) next_available:
    remaining = [c for c in candidates if not on_time or c["busId"] != on_time["busId"]]
    if remaining:
        # 締切が最も早いバス
        nxt = min(remaining, key=lambda c: c["latest_drop"])
        if nxt["latest_drop"] != datetime.max:
            next_available = {"until": nxt["latest_drop"].strftime(_DT_FMT_OUT)}
        else:
            next_available = {"anytime": True}

    return {
        "earlier": earlier,
        "on_time": on_time,
        "next_available": next_available,
    }


# ここまで


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
