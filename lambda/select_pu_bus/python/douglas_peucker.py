from typing import List, Dict
from decimal import Decimal, getcontext
getcontext().prec = 12  # 任意の精度（12桁など）


# Douglas-Peucker 用の距離計算（緯度経度）
def perpendicular_distance(point, start, end):
    if start == end:
        return Decimal((Decimal(point["latitude"]) - Decimal(start["latitude"]))**2 + 
                       (Decimal(point["longitude"]) - Decimal(start["longitude"]))**2).sqrt()

    x0, y0 = Decimal(point["latitude"]), Decimal(point["longitude"])
    x1, y1 = Decimal(start["latitude"]), Decimal(start["longitude"])
    x2, y2 = Decimal(end["latitude"]), Decimal(end["longitude"])

    num = abs((y2 - y1) * x0 - (x2 - x1) * y0 + x2 * y1 - y2 * x1)
    den = ((y2 - y1) ** 2 + (x2 - x1) ** 2).sqrt()  # Decimal同士の √ 演算

    return num / den if den != 0 else Decimal("0")


def douglas_peucker(points: List[Dict[str, float]], epsilon: float) -> List[Dict[str, float]]:
    print("douglas_peucker called")
    
    if len(points) < 3:
        return points

    # 最大距離の点を探す
    dmax = 0.0
    index = 0
    for i in range(1, len(points) - 1):
        d = perpendicular_distance(points[i], points[0], points[-1])
        if d > dmax:
            index = i
            dmax = d

    # 最大距離がしきい値を超えていれば再帰
    if dmax >= epsilon:
        rec_results1 = douglas_peucker(points[:index+1], epsilon)
        rec_results2 = douglas_peucker(points[index:], epsilon)
        return rec_results1[:-1] + rec_results2  # 重複除去して結合
    else:
        return [points[0], points[-1]]
