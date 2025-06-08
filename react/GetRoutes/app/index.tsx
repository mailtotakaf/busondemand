import React, { useEffect, useState } from 'react';
import { Button, View, Linking, FlatList, Text, StyleSheet, SafeAreaView } from 'react-native';
import { useLocationSender } from '../hooks/useLocationSender';
import Constants from 'expo-constants';
import { Picker } from '@react-native-picker/picker';

const { POST_BUS_LOCATIONS_API_URL } = Constants.expoConfig?.extra || {};

// データの型定義
interface PickupLocation {
  pickupTime: string;
  latitude: string;
  longitude: string;
}

interface DropoffLocation {
  dropoffTime: string;
  latitude: string;
  longitude: string;
}

interface RouteItem {
  pickupTime: string;
  selectedType: string;
  pickup: PickupLocation;
  dropoff: DropoffLocation;
  userId: string;
  status: string;
  passengerCount: string;
  busId: string;
  dropoffTime: string;
  requestId: string;
}

export default function Index() {
  const [busId, setBusId] = useState('bus_003');
  const [data, setData] = useState<RouteItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [locationStatus, setLocationStatus] = useState('stop');
  const [time, setTime] = useState('08:00');
  const [quarter, setQuarter] = useState('00');

  // 位置情報送信機能を統合
  const {
    setIsTracking,
    location,
    errorMsg
  } = useLocationSender(
    busId,
    POST_BUS_LOCATIONS_API_URL,
    false,
    locationStatus, // ← 追加
    time,           // ← 追加
    quarter         // ← 追加
  );

  const fetchData = async () => {
    try {
      console.log('データ取得開始:', busId);
      const response = await fetch(`https://hgbu7mkzsk.execute-api.us-west-2.amazonaws.com/bus?busId=${busId}`);
      const json = await response.json();
      console.log('json:', json);
      setData(json);
    } catch (error) {
      console.error('データ取得エラー:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, [busId]);

  // Google Mapsで位置表示
  const openGoogleMaps = (lat: number, lng: number) => {
    const url = `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;
    Linking.openURL(url).catch(err => console.error('Google Maps 起動エラー:', err));
  };

  // 各アイテムの表示 + ボタン
  const renderItem = ({ item }: { item: RouteItem }) => (
    console.log("item:", item),
    <View style={styles.item}>
      <View style={styles.section}>
        <Text>
          乗客数: {item.passengerCount}人（車椅子：<Text style={{ fontWeight: 'bold' }}>〇台</Text>）
        </Text>
      </View>

      <View style={styles.hr} />

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>
          乗車予定時間:
          {item.pickup?.pickupTime
            ? `${new Date(item.pickup.pickupTime).getHours()}時${String(new Date(item.pickup.pickupTime).getMinutes()).padStart(2, '0')}分頃`
            : '不明'}
        </Text>
        <Button
          title="乗車地点"
          onPress={() =>
            openGoogleMaps(parseFloat(item.pickup.latitude), parseFloat(item.pickup.longitude))
          }
          color="#4285F4"
        />
      </View>

      <View style={styles.buttonContainer}>
        <Text style={styles.sectionTitle}>
          到着予定時間: {new Date(item.dropoffTime).getHours()}時
          {String(new Date(item.dropoffTime).getMinutes()).padStart(2, '0')}分頃
        </Text>
        <Button
          title="乗車→降車のルート表示"
          onPress={() => {
            const url = `https://www.google.com/maps/dir/${item.pickup.latitude},${item.pickup.longitude}/${item.dropoff.latitude},${item.dropoff.longitude}/`;
            Linking.openURL(url).catch(err =>
              console.error('Google Maps ルート表示エラー:', err)
            );
          }}
          color="#aaa"
        />
      </View>
    </View>
  );

  // 15分単位の選択肢
  const quarterOptions = [
    { label: '00分', value: '00' },
    { label: '15分', value: '15' },
    { label: '30分', value: '30' },
    { label: '45分', value: '45' },
  ];

  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.busIdLabel}>{busId}</Text>
      <View style={styles.locationControlArea}>
        <View style={{ flex: 1 }}>
          <View style={styles.switchContainer}>
            <View style={{ borderWidth: 1, borderColor: '#ccc', borderRadius: 8, width: 120 }}>
              <Picker
                selectedValue={locationStatus}
                onValueChange={(value) => {
                  setLocationStatus(value);
                  setIsTracking(value === 'avairable');
                }}
                style={{ width: 120, height: 40 }}
              >
                <Picker.Item label="停止中" value="stop" />
                <Picker.Item label="受付中" value="avairable" />
                <Picker.Item label="休憩中" value="rest" />
                <Picker.Item label="受付終了" value="stopped" />
              </Picker>
            </View>
            {locationStatus === 'avairable' && location?.coords && (
              <Text style={[styles.locationText, { marginLeft: 12 }]}>
                位置送信中： {location.coords.latitude.toFixed(5)}, {location.coords.longitude.toFixed(5)}
              </Text>
            )}
          </View>
          {(locationStatus === 'avairable' || locationStatus === 'rest') && (
            <View style={[styles.row, { marginTop: 16 }]}>
              <View style={[styles.pickerWrapper, { marginRight: 8 }]}>
                <Picker
                  selectedValue={time}
                  onValueChange={(itemValue) => setTime(itemValue)}
                  style={styles.picker}
                >
                  <Picker.Item label="08:00" value="08:00" />
                  <Picker.Item label="09:00" value="09:00" />
                  <Picker.Item label="10:00" value="10:00" />
                  <Picker.Item label="11:00" value="11:00" />
                  <Picker.Item label="12:00" value="12:00" />
                  <Picker.Item label="13:00" value="13:00" />
                  <Picker.Item label="14:00" value="14:00" />
                  <Picker.Item label="15:00" value="15:00" />
                  <Picker.Item label="16:00" value="16:00" />
                  <Picker.Item label="17:00" value="17:00" />
                  <Picker.Item label="18:00" value="18:00" />
                  <Picker.Item label="19:00" value="19:00" />
                  <Picker.Item label="20:00" value="20:00" />
                </Picker>
              </View>
              <View style={styles.pickerWrapper}>
                <Picker
                  selectedValue={quarter}
                  onValueChange={(itemValue) => setQuarter(itemValue)}
                  style={styles.picker}
                >
                  {quarterOptions.map((opt) => (
                    <Picker.Item key={opt.value} label={opt.label} value={opt.value} />
                  ))}
                </Picker>
              </View>&nbsp;まで
            </View>
          )}
          {errorMsg && <Text style={styles.errorText}>{errorMsg}</Text>}
        </View>
      </View>
      <Text style={styles.header}>リクエスト一覧</Text>

      {/* リクエスト一覧表示エリア */}
      {loading ? (
        <View style={styles.loadingContainer}>
          <Text style={styles.loadingText}>データ読み込み中...</Text>
        </View>
      ) : data.length === 0 ? (
        <View style={styles.emptyContainer}>
          <Text style={styles.emptyText}>リクエストがありません</Text>
        </View>
      ) : (
        <FlatList
          data={data}
          keyExtractor={(item) => item.requestId}
          renderItem={renderItem}
          contentContainerStyle={styles.listContent}
        />
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    paddingTop: 50,
    backgroundColor: '#dde',
  },
  locationControlArea: {
    backgroundColor: 'white',
    padding: 10,
    margin: 10,
    borderRadius: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    // padding: 10,
  },
  switchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 5,
  },
  locationStatus: {
    marginLeft: 10,
    fontWeight: '500',
    color: '#333',
  },
  locationText: {
    fontSize: 12,
    color: '#666',
  },
  errorText: {
    fontSize: 12,
    color: 'red',
    marginTop: 5,
  },
  header: {
    fontSize: 20,
    fontWeight: 'bold',
    textAlign: 'center',
    marginVertical: 10,
    color: '#333',
  },
  listContent: {
    paddingBottom: 20,
  },
  item: {
    backgroundColor: '#fff',
    borderRadius: 10,
    padding: 16,
    margin: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
    borderColor: '#333',
    borderWidth: 1,
  },
  title: {
    fontWeight: 'bold',
    fontSize: 16,
    marginBottom: 10,
    color: '#333',
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
    paddingBottom: 8,
  },
  section: {
    // marginVertical: 8,
    // paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  sectionTitle: {
    fontWeight: 'bold',
    fontSize: 15,
    marginBottom: 5,
    color: '#555',
  },
  buttonContainer: {
    marginTop: 10,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  loadingText: {
    fontSize: 16,
    color: '#666',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyText: {
    fontSize: 16,
    color: '#666',
  },
  hr: {
    borderBottomColor: '#333', // 線の色
    borderBottomWidth: 1,      // 線の太さ
    marginVertical: 8,         // 上下の余白
  },
  row: { flexDirection: 'row', alignItems: 'center' },
  pickerWrapper: { borderWidth: 1, borderColor: '#ccc', borderRadius: 8, width: 100 },
  picker: { width: 100, height: 44 },
  busIdLabel: {
    position: 'absolute',
    top: 20,
    left: 20,
    fontSize: 18,
    fontWeight: 'bold',
    zIndex: 10,
  },
});