import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';


/// Nominatim APIを使用して住所検索と逆ジオコーディングを行うサービスクラス
class NominatimService {
  static const _base = 'https://nominatim.openstreetmap.org';
  static const _headers = {'User-Agent': 'flutter_gsi_app'};

  static Future<Map<String, dynamic>?> searchAddressJP(String query) async {
    final url = Uri.parse(
        '$_base/search?format=json&accept-language=ja&q=$query&limit=1');

    try {
      final res = await http.get(url, headers: _headers);
      final data = json.decode(res.body);
      return (data.isNotEmpty) ? data[0] : null;
    } catch (e) {
      print("❌ Nominatim検索エラー: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> reverseGeocode(LatLng latLng) async {
    final url = Uri.parse(
        '$_base/reverse?format=json&lat=${latLng.latitude}&lon=${latLng.longitude}&accept-language=ja');

    try {
      final res = await http.get(url, headers: _headers);
      final data = json.decode(res.body);
      return data;
    } catch (e) {
      print("❌ 逆ジオコエラー: $e");
      return null;
    }
  }
}
