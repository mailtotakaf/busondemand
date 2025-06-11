import * as Location from 'expo-location';
import { useEffect, useRef, useState } from 'react';

export function useLocationSender(
  busId,
  apiUrl,
  autoStart,
  status,
  time,
  quarter
) {
  const [isTracking, setIsTracking] = useState(autoStart);
  const [location, setLocation] = useState<Location.LocationObject | null>(null);
  const [errorMsg, setErrorMsg] = useState('');
  const [lastSentTime, setLastSentTime] = useState<Date | null>(null);
  const subscriptionRef = useRef<any>(null); // ← Location.LocationSubscription だと remove() の型エラーになる場合があるため any にしておく

  const stopTracking = () => {
    try {
      if (subscriptionRef.current) {
        subscriptionRef.current.remove?.(); // ← optional chaining で安全に呼ぶ
        subscriptionRef.current = null;
      }
    } catch (err) {
      console.error('位置情報の解除に失敗:', err);
    }
  };

  useEffect(() => {
    const startTracking = async () => {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        setErrorMsg('位置情報の権限がありません');
        return;
      }

      const subscription = await Location.watchPositionAsync(
        {
          accuracy: Location.Accuracy.High,
          timeInterval: 5000,
          distanceInterval: 0,
        },
        (loc) => {
          setLocation(loc);
          sendLocation(loc.coords);
        }
      );

      subscriptionRef.current = subscription;
    };

    if (isTracking) {
      startTracking();
    } else {
      stopTracking();
    }

    return () => {
      stopTracking(); // ← アンマウント時も安全に解除
    };
  }, [isTracking]);

  // untilを生成
  const getUntil = () => {
    if (!time || !quarter) return '';
    const [h, m] = time.split(':').map(Number);
    const untilMinute = String(Number(quarter)).padStart(2, '0');
    return `${String(h).padStart(2, '0')}:${untilMinute}`;
  };

  const sendLocation = async (coords) => {
    try {
      await fetch(apiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          busId,
          latitude: coords.latitude,
          longitude: coords.longitude,
          status,
          until: getUntil(), // ← ここだけ送信
        }),
      });
      setLastSentTime(new Date());
    } catch (error) {
      console.error('送信失敗:', error);
    }
  };

  return {
    isTracking,
    setIsTracking,
    location,
    lastSentTime,
    errorMsg,
  };
};
