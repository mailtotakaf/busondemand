import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Platform,
  Button,
  Linking,
  FlatList,
  SafeAreaView,
  Alert,
} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { Picker } from '@react-native-picker/picker';
import { useLocationSender } from './hooks/useLocationSender'; // 相対パスに合わせて調整

// 手動で定義（Constants.expoConfig?.extra の代わり）
const POST_BUS_LOCATIONS_API_URL = 'https://your-api.example.com/endpoint';

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

const App = () => {
  const [idToken, setIdToken] = useState<string | null>(null);
  const [busId, setBusId] = useState('bus_001');
  const [data, setData] = useState<RouteItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [locationStatus, setLocationStatus] = useState('stop');
  const [time, setTime] = useState('08:00');
  const [quarter, setQuarter] = useState('00');

  const { setIsTracking, location, errorMsg } = useLocationSender(
    busId,
    POST_BUS_LOCATIONS_API_URL,
    false,
    locationStatus,
    time,
    quarter
  );

  const quarterOptions = [
    { label: '00分', value: '00' },
    { label: '15分', value: '15' },
    { label: '30分', value: '30' },
    { label: '45分', value: '45' },
  ];

  const openGoogleMaps = (lat: number, lng: number) => {
    const url = `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;
    Linking.openURL(url).catch(err => console.error('Google Maps 起動エラー:', err));
  };

  const handleLogout = async () => {
    await AsyncStorage.removeItem('idToken');
    Alert.alert('ログアウトしました', 'ログイン画面に戻ってください。');
  };

  const handleLocationStatusChange = (value: string) => {
    if (value === 'stopped') {
      Alert.alert(
        '確認',
        '受付を終了してログアウトしますか？',
        [
          { text: 'いいえ', style: 'cancel' },
          {
            text: 'はい',
            onPress: () => {
              setLocationStatus(value);
              setIsTracking(false);
              handleLogout();
            },
          },
        ],
        { cancelable: false }
      );
    } else {
      setLocationStatus(value);
      setIsTracking(value === 'avairable');
    }
  };

  const fetchData = async () => {
    try {
      const response = await fetch(
        `https://hgbu7mkzsk.execute-api.us-west-2.amazonaws.com/bus?busId=${busId}`
      );
      const json = await response.json();
      console.log('Lambdaからのデータ:', json);
      setData(json);
    } catch (error) {
      console.error('データ取得エラー:', error);
    } finally {
      setLoading(false);
    }
  };

  // useEffect(() => {
  //   const checkAuth = async () => {
  //     const token = await AsyncStorage.getItem('idToken');
  //     setIdToken(token);
  //     if (!token) {
  //       Alert.alert('未ログインです', 'ログイン画面に遷移してください。');
  //     }
  //   };
  //   checkAuth();
  //   fetchData();
  // }, []);

  const renderItem = ({ item }: { item: RouteItem }) => (
    <View style={styles.item}>
      <Text>乗客数: {item.passengerCount}人</Text>
      <Button
        title="乗車地点"
        onPress={() => openGoogleMaps(parseFloat(item.pickup.latitude), parseFloat(item.pickup.longitude))}
      />
    </View>
  );

  // if (!idToken) {
  //   return (
  //     <View style={styles.container}>
  //       <Text>認証確認中...</Text>
  //     </View>
  //   );
  // }

  return (
    <SafeAreaView style={styles.container}>
      <Text>{busId}</Text>
      <Picker selectedValue={locationStatus} onValueChange={handleLocationStatusChange}>
        <Picker.Item label="停止中" value="stop" />
        <Picker.Item label="受付中" value="avairable" />
        <Picker.Item label="休憩中" value="rest" />
        <Picker.Item label="受付終了" value="stopped" />
      </Picker>
      {loading ? (
        <Text>読み込み中...</Text>
      ) : (
        <FlatList data={data} keyExtractor={(item) => item.requestId} renderItem={renderItem} />
      )}
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 24,
  },
  item: {
    backgroundColor: '#fff',
    marginBottom: 12,
    padding: 16,
    borderRadius: 8,
  },
});

export default App;
