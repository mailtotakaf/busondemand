import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/nominatim_service.dart';
import '../widgets/map_view.dart';
import '../widgets/address_input.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart'
    as picker;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../env.dart' as env;

final API_GW_URL = env.API_GW_URL;
final SELECT_PU_BUS_API_URL = env.SELECT_PU_BUS_API_URL;
final CANCEL_USER_REQ_API_URL = env.CANCEL_USER_REQ_API_URL;

class RequestScreen extends StatefulWidget {
  @override
  _RequestScreenState createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final MapController _mapController = MapController();
  final _pickupAddressController = TextEditingController();
  final _dropoffAddressController = TextEditingController();

  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;
  LatLng? _userDropoffLatLng;

  String _pickupAddress = '';
  String _dropoffAddress = '';
  DateTime? _requestDateTime;

  List<LatLng> _simplifiedRoute = [];
  List<List<LatLng>> _otherRoutePoints = [];

  int _passengerCount = 1;
  bool _wheelchair = false;
  String _requests = '';
  int _wheelchairCount = 1;
  String _selectedType = "";
  int apploxDurationMin = 0;
  // String pickupTime = "";
  // String dropoffTime = "";

  Map<String, dynamic> _busesInfoMap = {};

  Widget _buildRouteCard(String title, Color color, busesInfo, String key, {bool isConfirmed = false}) {
    String deptTimeText = formatTime(busesInfo?['pickupTime']);
    String arrivalTimeText = formatTime(busesInfo?['dropoffTime']);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isConfirmed ? "予約確定" : title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("出発： $deptTimeText 頃"),
                    Text("到着： $arrivalTimeText 頃"),
                    const SizedBox(height: 8),
                    Text("乗車人数: $_passengerCount 名"),
                    Text("車椅子での乗車: ${_wheelchair ? "あり" : "なし"}"),
                    if (_wheelchair) Text("車椅子の台数: $_wheelchairCount 台"),
                    if (_requests.isNotEmpty) Text("その他ご要望: $_requests"),
                  ],
                ),
              ),
            ],
          ),
          if (isConfirmed)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('キャンセル確認'),
                          content: const Text('この予約をキャンセルしますか？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('いいえ'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('はい'),
                            ),
                          ],
                        );
                      },
                    );
                    if (result == true) {
                      final requestId = busesInfo?['requestId'];
                      final busId = busesInfo?['busId'];
                      print("requestId: $requestId, busId: $busId");
                      try {
                        final response = await http.post(
                          Uri.parse(CANCEL_USER_REQ_API_URL),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({'requestId': requestId, 'busId': busId}),
                        );
                        if (response.statusCode == 200) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('予約をキャンセルしました')),
                          );
                          setState(() {
                            _busesInfoMap.clear();
                            _otherRoutePoints.clear();
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('キャンセルに失敗しました')),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('通信エラーが発生しました')),
                        );
                      }
                    }
                  },
                  icon: Icon(Icons.cancel),
                  label: Text('キャンセル'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 110, 110, 171),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          if (!isConfirmed)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('確認'),
                          content: const Text('この条件で予約してもよろしいですか？'),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(false);
                              },
                              child: const Text('キャンセル'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(true);
                              },
                              child: const Text('予約する'),
                            ),
                          ],
                        );
                      },
                    );

                    if (result == true) {
                      _confirmRoute(
                        busesInfo?['pickupTime'],
                        busesInfo?['dropoffTime'],
                        selectedKey: key,
                        busId: busesInfo?['busId'], // ここでbusIdを渡す
                      );
                    }
                  },
                  child: const Text('この条件で予約する'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("❌ 位置情報の権限が拒否されました");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final currentLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _pickupLatLng ??= currentLatLng;
        _pickupAddress = "現在地（仮）";
      });

      _mapController.move(currentLatLng, 15);
    } catch (e) {
      print("現在地の取得に失敗しました: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("現在地を取得できませんでした")));
    }
  }

  Future<LatLng?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("⚠️ 位置情報サービスが無効です");
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("❌ 位置情報の権限が拒否されました");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("❌ 永続的に拒否されています");
      return null;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final currentLatLng = LatLng(position.latitude, position.longitude);

    setState(() {
      _pickupLatLng ??= currentLatLng;
      _pickupAddress = "現在地（仮）";
    });

    // 地図を現在地に移動
    _mapController.move(currentLatLng, 15);
    return currentLatLng;
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ja');
    _getCurrentLocation();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String formatTime(String? timeStr, {String prefix = ''}) {
    final formatTimeStr = DateTime.tryParse(timeStr ?? '');
    return formatTimeStr != null
        ? "$prefix${DateFormat('M月d日（EEE）H時mm分', 'ja').format(formatTimeStr)}"
        : "$prefix不明";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sample')),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: Stack(
              children: [
                MapView(
                  mapController: _mapController,
                  pickupLatLng: _pickupLatLng,
                  dropoffLatLng: _dropoffLatLng,
                  userDropoffLatLng: _userDropoffLatLng,
                  routePoints: _simplifiedRoute,
                  otherRoutePoints: _otherRoutePoints,
                  onMapTap: _onMapTap,
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FloatingActionButton.small(
                    onPressed: _moveToCurrentLocation,
                    child: Icon(Icons.my_location),
                    tooltip: "現在地に移動",
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  AddressInput(
                    pickupController: _pickupAddressController,
                    dropoffController: _dropoffAddressController,
                    pickupLabel: _pickupAddress,
                    dropoffLabel: _dropoffAddress,
                    onPickupSearch: (text) => _searchAddressJP(text, isPickup: true),
                    onDropoffSearch: (text) => _searchAddressJP(text, isPickup: false),
                  ),
                  const SizedBox(height: 8),
                  if (_busesInfoMap.isNotEmpty) ...[
                    if (_busesInfoMap['earlier'] != null)
                      _buildRouteCard(
                        'もっと早い時間',
                        Colors.blue,
                        _busesInfoMap['earlier'],
                        'earlier',
                        isConfirmed: _busesInfoMap.length == 1,
                      ),
                    if (_busesInfoMap['on_time'] != null)
                      _buildRouteCard(
                        '指定した時間',
                        Colors.green,
                        _busesInfoMap['on_time'],
                        'on_time',
                        isConfirmed: _busesInfoMap.length == 1,
                      ),
                    const SizedBox(height: 8),
                    // 「予約確定」時は「条件をキャンセルする」ボタンを非表示にする
                    if (_busesInfoMap.length != 1)
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _busesInfoMap.clear();
                            _otherRoutePoints.clear();
                          });
                        },
                        icon: Icon(Icons.cancel),
                        label: Text('条件をキャンセルする'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _searchAddressJP(String query, {required bool isPickup}) async {
    final result = await NominatimService.searchAddressJP(query);
    if (result != null) {
      final latLng = LatLng(
        double.parse(result['lat']),
        double.parse(result['lon']),
      );
      print("latLng: $latLng");
      final label = result['display_name'];

      setState(() {
        if (isPickup) {
          _pickupLatLng = latLng;
          _pickupAddress = label;
          _pickupAddressController.text = label;
        } else {
          _userDropoffLatLng = latLng;
          _dropoffAddress = label;
          _dropoffAddressController.text = label;
        }
      });

      _mapController.move(latLng, 15);
    }
  }

  void _onMapTap(LatLng latLng) {
    showModalBottomSheet(
      context: context,
      builder:
          (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text("🚖 乗車場所に設定"),
                onTap: () {
                  Navigator.pop(context);
                  _getAddressFromLatLng(latLng, isPickup: true);
                },
              ),
              ListTile(
                title: Text("🏁 目的地に設定"),
                onTap: () async {
                  Navigator.pop(context);
                  await _getAddressFromLatLng(latLng, isPickup: false);
                  _openCustomDateTimePicker();
                },
              ),
            ],
          ),
    );
  }

  Future<void> _getAddressFromLatLng(
    LatLng latLng, {
    required bool isPickup,
  }) async {
    final result = await NominatimService.reverseGeocode(latLng);
    if (result != null && result['display_name'] != null) {
      final label = result['display_name'];

      setState(() {
        if (isPickup) {
          _pickupLatLng = latLng;
          _pickupAddress = label;
          _pickupAddressController.text = label;
        } else {
          _userDropoffLatLng = latLng;
          _dropoffAddress = label;
          _dropoffAddressController.text = label;
        }
      });
    }
  }

  void _confirmRoute(pickupTime, dropoffTime, {String? selectedKey, String? busId}) async {
    if (_pickupLatLng == null || _userDropoffLatLng == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("乗車位置と到着位置の両方を入力してください")));
      return;
    }

    final url = Uri.parse(API_GW_URL);

    final data = {
      "pickup": {
        "latitude": _pickupLatLng!.latitude,
        "longitude": _pickupLatLng!.longitude,
        "pickupTime": pickupTime,
      },
      "dropoff": {
        "latitude": _userDropoffLatLng!.latitude,
        "longitude": _userDropoffLatLng!.longitude,
        "dropoffTime": dropoffTime,
      },
      "userId": "user121", // TODO:
      "busId": busId ?? "bus_003", // TODO:
      "simplified_route":
          _simplifiedRoute
              .map(
                (latLng) => {
                  "latitude": latLng.latitude,
                  "longitude": latLng.longitude,
                },
              )
              .toList(),
      "selectedType": _selectedType,
      "passengerCount": _passengerCount,
      // "wheelchair": true, // TODO: 以下情報後回し
      // "wheelchair": _wheelchair,
      // "wheelchairCount": _wheelchairCount,
      // "requests": _requests,
    };
    // print("_simplifiedRoute: $_simplifiedRoute");
    // print("encoded route: ${json.encode(data["simplified_route"])}");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("バスの予約が完了しました。")));

        // RouteCardを1つだけ残す
        setState(() {
          if (selectedKey != null) {
            // 指定したRouteCardのみ残す
            _busesInfoMap.removeWhere((key, value) => key != selectedKey);
          } else {
            // 何も指定がなければ全て消す
            _busesInfoMap.clear();
          }
          // _simplifiedRoute.clear();
          _otherRoutePoints.clear();
        });
      } else {
        print("失敗: ${response.statusCode} - ${response.body}");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("送信に失敗しました")));
      }
    } catch (e) {
      print("エラー: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("通信エラーが発生しました")));
    }
  }

  Future<void> _openCustomDateTimePicker() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CustomDateTimePickerDialog(),
    );

    if (result != null) {
      setState(() {
        _selectedType = result['type'];
        _requestDateTime = result['dateTime'];
      });

      // そのまま詳細モーダルへ
      final details = await showDialog<Map<String, dynamic>>(
        context: context,
        builder:
            (context) => RideDetailsDialog(
              passengerCount: _passengerCount,
              wheelchair: _wheelchair,
              requests: _requests,
              pickupLatLng: _pickupLatLng,
              userDropoffLatLng: _userDropoffLatLng,
              arrivalDateTime: _requestDateTime,
              selectedType: _selectedType,
            ),
      );

      if (details != null) {
        if (details['isBack'] == true) {
          _openCustomDateTimePicker(); // 戻るボタンなら再度開く
        } else {
          setState(() {
            _passengerCount = details['passengerCount'];
            _wheelchair = details['wheelchair'];
            _wheelchairCount = details['wheelchairCount'] ?? 1;
            _requests = details['requests'];
            _simplifiedRoute = details['routePoints'] ?? [];
            _otherRoutePoints = details['otherRoutePoints'] ?? [];
            apploxDurationMin = details['apploxDurationMin'] ?? 0;
            _busesInfoMap = details['buses_info_map'] ?? {};
          });
        }
      }
    }
  }
}

class RideDetailsDialog extends StatefulWidget {
  final int passengerCount;
  final bool wheelchair;
  final String requests;
  final LatLng? pickupLatLng;
  final LatLng? userDropoffLatLng;
  final DateTime? arrivalDateTime;
  final String selectedType;

  const RideDetailsDialog({
    required this.passengerCount,
    required this.wheelchair,
    required this.requests,
    required this.pickupLatLng,
    required this.userDropoffLatLng,
    required this.arrivalDateTime,
    required this.selectedType,
  });

  @override
  _RideDetailsDialogState createState() => _RideDetailsDialogState();
}

class _RideDetailsDialogState extends State<RideDetailsDialog> {
  late int _passengerCount;
  late bool _wheelchair;
  late TextEditingController _requestsController;
  late int _wheelchairCount = 0;

  @override
  void initState() {
    super.initState();
    _passengerCount = widget.passengerCount;
    _wheelchair = widget.wheelchair;
    _requestsController = TextEditingController(text: widget.requests);
  }

  @override
  void dispose() {
    _requestsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('乗車人数'),
              Spacer(),
              SizedBox(
                width: 100,
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _passengerCount,
                  items:
                      [1, 2, 3, 4, 5, 6]
                          .map(
                            (num) => DropdownMenuItem(
                              value: num,
                              child: Center(child: Text('$num')),
                            ),
                          )
                          .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _passengerCount = val;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          SwitchListTile(
            title: Text('車椅子での乗車'),
            value: _wheelchair,
            onChanged: (val) {
              setState(() {
                _wheelchair = val;
              });
            },
          ),
          if (_wheelchair)
            Row(
              children: [
                Text('車椅子の台数'),
                Spacer(),
                SizedBox(
                  width: 100,
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _wheelchairCount,
                    items:
                        [0, 1, 2, 3].map((count) {
                          return DropdownMenuItem(
                            value: count,
                            child: Center(child: Text('$count')),
                          );
                        }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _wheelchairCount = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          TextField(
            controller: _requestsController,
            decoration: InputDecoration(labelText: 'その他ご要望'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, {
              'passengerCount': _passengerCount,
              'wheelchair': _wheelchair,
              'wheelchairCount': _wheelchairCount,
              'requests': _requestsController.text,
              'isBack': true,
            });
          },
          child: Text('戻る'),
        ),
        ElevatedButton(
          onPressed: () async {
            final requestData = {
              'passengerCount': _passengerCount,
              'wheelchair': _wheelchair,
              'wheelchairCount': _wheelchairCount,
              'requests': _requestsController.text,
              'selectedType': widget.selectedType,
              'requestDateTime':
                  widget.arrivalDateTime?.toLocal().toString().substring(
                    0,
                    16,
                  ) ??
                  "設定した時間",
              'pickup': [
                widget.pickupLatLng?.longitude ?? 0,
                widget.pickupLatLng?.latitude ?? 0,
              ],
              'dropoff': [
                widget.userDropoffLatLng?.longitude ?? 0,
                widget.userDropoffLatLng?.latitude ?? 0,
              ],
            };

            try {
              final response = await http.post(
                Uri.parse(SELECT_PU_BUS_API_URL),
                headers: {'Content-Type': 'application/json'},
                body: json.encode(requestData),
              );

              if (response.statusCode == 200) {
                // print('API送信成功: ${response.body}');

                // simplified_route を取り出して LatLng に変換
                final decoded = json.decode(response.body);
                final simplifiedRoute =
                    decoded['simplified_route'] as List<dynamic>;
                final otherRoutes = decoded['other_routes'] as List<dynamic>;
                final buses_info_map =
                    decoded['buses_info_map'] as Map<String, dynamic>;
                print("buses_info_map: $buses_info_map");
                // print("");
                // print("otherRoutes: $otherRoutes");
                List<List<LatLng>> otherRoutesList =
                    otherRoutes.map((entry) {
                      final points = entry['simplified_route'] as List;
                      return points.map((point) {
                        return LatLng(point['latitude'], point['longitude']);
                      }).toList();
                    }).toList();
                // print("otherRoutesList: $otherRoutesList");

                List<List<LatLng>> recomendRoutesList =
                    otherRoutes.map((entry) {
                      final points = entry['simplified_route'] as List;
                      return points.map((point) {
                        return LatLng(point['latitude'], point['longitude']);
                      }).toList();
                    }).toList();
                // print("otherRoutesList: $otherRoutesList");

                final routePoints =
                    simplifiedRoute.map((point) {
                      return LatLng(point['latitude'], point['longitude']);
                    }).toList();

                final apploxDurationMin = decoded['apploxDurationMin'] as int;
                // print("apploxDurationMin: $apploxDurationMin");

                // 親画面に返す値
                Navigator.pop(context, {
                  'passengerCount': _passengerCount,
                  'wheelchair': _wheelchair,
                  'wheelchairCount': _wheelchairCount,
                  'requests': _requestsController.text,
                  'routePoints': routePoints,
                  'otherRoutePoints': otherRoutesList,
                  'apploxDurationMin': apploxDurationMin,
                  'isBack': false,
                  'buses_info_map': buses_info_map,
                });
              } else {
                print('API送信失敗: ${response.statusCode}');
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('API送信に失敗しました')));
              }
            } catch (e) {
              print('通信エラー: $e');
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('通信エラーが発生しました')));
            }
          },
          child: Text('確認する'),
        ),
      ],
    );
  }
}

class CustomDateTimePickerDialog extends StatefulWidget {
  @override
  _CustomDateTimePickerDialogState createState() =>
      _CustomDateTimePickerDialogState();
}

class _CustomDateTimePickerDialogState
    extends State<CustomDateTimePickerDialog> {
  DateTime _selectedDateTime = DateTime.now();
  final List<Map<String, String>> _dropdownItems = [
    // {'label': '出発時間を設定', 'value': 'departure'},
    {'label': '到着時間を設定', 'value': 'arrival'},
  ];
  String _selectedType = 'arrival';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // title: Text('日時を設定'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<String>(
            isExpanded: true,
            value: _selectedType,
            items:
                _dropdownItems.map((item) {
                  return DropdownMenuItem<String>(
                    value: item['value'],
                    child: Text(item['label']!),
                  );
                }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedType = val;
                });
              }
            },
          ),
          SizedBox(height: 16),
          ElevatedButton(
            child: Text(
              "${DateFormat('M月d日（EEE）H時mm分', 'ja').format(_selectedDateTime)}",
            ),
            onPressed: () {
              _showInlineDateTimePicker(context);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'type': _selectedType,
              'dateTime': _selectedDateTime,
            });
          },
          child: Text('決定'),
        ),
      ],
    );
  }

  void _showInlineDateTimePicker(BuildContext context) {
    // flutter_datetime_picker_plus を使って直接更新
    picker.DatePicker.showDateTimePicker(
      context,
      currentTime: _selectedDateTime,
      locale: picker.LocaleType.jp,
      showTitleActions: true,
      onConfirm: (dateTime) {
        setState(() {
          _selectedDateTime = dateTime;
        });
      },
    );
  }
}
