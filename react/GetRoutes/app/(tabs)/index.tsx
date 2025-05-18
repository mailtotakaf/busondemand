import React, { useEffect, useState } from 'react';
import { Button, View, Linking, FlatList, Text, StyleSheet, Switch, SafeAreaView } from 'react-native';
import { useLocationSender } from '../../hooks/useLocationSender';

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
  const [data, setData] = useState<RouteItem[]>([]);
  const [loading, setLoading] = useState(true);

  // バスID - 実際の環境に合わせて変更してください
  const busId = 'bus_003';

  // 位置情報送信機能を統合
  const {
    isTracking,
    setIsTracking,
    location,
    lastSentTime,
    status,
    errorMsg
  } = useLocationSender(
    busId,
    'https://y6ajbpn5wa.execute-api.us-west-2.amazonaws.com/location',
    false // アプリ起動時に自動で位置情報の送信を開始するかどうか
  );

  const fetchData = async () => {
    try {
      const response = await fetch(`https://hgbu7mkzsk.execute-api.us-west-2.amazonaws.com/bus?busId=${busId}`);
      const json = await response.json();
      setData(json);
    } catch (error) {
      console.error('データ取得エラー:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();

    // 60秒ごとにデータを再取得
    const intervalId = setInterval(() => {
      fetchData();
    }, 60000);

    return () => clearInterval(intervalId);
  }, []);

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

  return (
    <SafeAreaView style={styles.container}>
      {/* 位置情報送信コントロールエリア */}
      <View style={styles.locationControlArea}>
        <View style={styles.switchContainer}>
          <Text>位置情報送信: </Text>
          <Switch
            value={isTracking}
            onValueChange={setIsTracking}
            trackColor={{ false: '#767577', true: '#81b0ff' }}
            thumbColor={isTracking ? '#f5dd4b' : '#f4f3f4'}
          />
          {/* 常にTextで囲む */}
          <Text style={styles.locationStatus}>
            {isTracking ? '送信中' : '停止中'}
          </Text>
        </View>

        {location?.coords && (
          <Text style={styles.locationText}>
            位置: {location.coords.latitude.toFixed(5)}, {location.coords.longitude.toFixed(5)}
          </Text>
        )}

        {errorMsg && (
          <Text style={styles.errorText}>{errorMsg}</Text>
        )}
      </View>

      <Text style={styles.header}>{busId} リクエスト一覧</Text>

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
  }
});