import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';

class MapView extends StatelessWidget {
  final MapController mapController;
  final LatLng? pickupLatLng;
  final LatLng? dropoffLatLng;
  final LatLng? userDropoffLatLng;
  final List<LatLng> routePoints;
  final List<List<LatLng>> otherRoutePoints;
  final void Function(LatLng latLng) onMapTap;

  const MapView({
    Key? key,
    required this.mapController,
    required this.pickupLatLng,
    required this.dropoffLatLng,
    required this.userDropoffLatLng,
    required this.routePoints,
    required this.otherRoutePoints,
    required this.onMapTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // print("MapView に渡された otherRoutePoints: $otherRoutePoints");
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: LatLng(35.681236, 139.767125),
        initialZoom: 15,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (tapPos, latLng) {
          bool tappedAny = false;

          // メインルート（青）
          if (handleMapTap(context, latLng, routePoints, "メインルートす")) {
            tappedAny = true;
          }

          // 他ルート（オレンジ）
          for (final route in otherRoutePoints) {
            if (handleMapTap(context, latLng, route, "他ルートす")) {
              tappedAny = true;
              break;
            }
          }

          if (!tappedAny) {
            onMapTap(latLng); // どのルートにも近くない場合のみモーダル表示
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate:
              "https://cyberjapandata.gsi.go.jp/xyz/pale/{z}/{x}/{y}.png",
          userAgentPackageName: 'com.example.fluttergsiapp',
          tileProvider: CancellableNetworkTileProvider(),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '地図データ © 国土地理院',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ),
        PolylineLayer(
          polylines: [
            if (routePoints.isNotEmpty)
              Polyline(points: routePoints, strokeWidth: 4, color: Colors.blue),
            ...otherRoutePoints
                .where((route) => route.isNotEmpty)
                .map(
                  (route) => Polyline(
                    points: route,
                    strokeWidth: 4,
                    color: Colors.grey,
                  ),
                ),
          ],
        ),
        MarkerLayer(
          markers: [
            if (pickupLatLng != null)
              Marker(
                point: pickupLatLng!,
                width: 40,
                height: 40,
                child: Icon(Icons.location_on, color: Colors.blueAccent),
              ),
            if (userDropoffLatLng != null)
              Marker(
                point: userDropoffLatLng!,
                width: 40,
                height: 40,
                child: Icon(Icons.location_pin, color: Colors.purpleAccent),
              ),
            ...otherRoutePoints.expand((route) {
              if (route.isEmpty) return [];
              return [
                Marker(
                  point: route.first,
                  width: 30,
                  height: 30,
                  child: Icon(Icons.circle, color: Colors.blueAccent, size: 16),
                ),
                Marker(
                  point: route.last,
                  width: 30,
                  height: 30,
                  child: Icon(
                    Icons.circle,
                    color: Colors.purpleAccent,
                    size: 16,
                  ),
                ),
              ];
            }),
          ],
        ),
      ],
    );
  }
}

bool handleMapTap(
  BuildContext context,
  LatLng tappedLatLng,
  List<LatLng> routePoints,
  String routeName,
) {
  const thresholdMeters = 30.0;
  final distance = Distance();

  for (int i = 0; i < routePoints.length - 1; i++) {
    final p1 = routePoints[i];
    final p2 = routePoints[i + 1];

    final d = _distanceToSegmentMeters(tappedLatLng, p1, p2, distance);

    if (d < thresholdMeters) {
      // 線の近くをタップしたので処理する
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text("ルート線がタップされました: $routeName"),
              content: Text("線分 $i に近い\n距離: ${d.toStringAsFixed(2)} m"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("OK"),
                ),
              ],
            ),
      );
      return true; // ✅ タップ位置はルート線の近くだった
    }
  }

  return false; // ❌ ルート線とは関係なかった
}

double _distanceToSegmentMeters(
  LatLng p, // タップされた点
  LatLng v, // 線分の始点
  LatLng w, // 線分の終点
  Distance distance,
) {
  final double l2 = pow(distance.as(LengthUnit.Meter, v, w), 2).toDouble();

  if (l2 == 0.0) {
    return distance.as(LengthUnit.Meter, p, v);
  }

  final double t = _clamp(_project(p, v, w), 0.0, 1.0);

  // 線分上の最近接点を求める
  final projection = LatLng(
    v.latitude + t * (w.latitude - v.latitude),
    v.longitude + t * (w.longitude - v.longitude),
  );

  return distance.as(LengthUnit.Meter, p, projection);
}

double _project(LatLng p, LatLng v, LatLng w) {
  final latDiff = w.latitude - v.latitude;
  final lonDiff = w.longitude - v.longitude;

  final numerator =
      (p.latitude - v.latitude) * latDiff +
      (p.longitude - v.longitude) * lonDiff;
  final denominator = latDiff * latDiff + lonDiff * lonDiff;

  return numerator / denominator;
}

double _clamp(double val, double min, double max) {
  return val < min ? min : (val > max ? max : val);
}
