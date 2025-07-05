import { useEffect, useRef, useState } from 'react';
import Geolocation from '@react-native-community/geolocation';

export function useLocationSender(
  busId: string,
  apiUrl: string,
  autoStart: boolean,
  status: string,
  time: string,
  quarter: string
) {
  const [isTracking, setIsTracking] = useState(autoStart);
  const [location, setLocation] = useState<{ coords: { latitude: number; longitude: number } } | null>(null);
  const [errorMsg, setErrorMsg] = useState('');
  const [lastSentTime, setLastSentTime] = useState<Date | null>(null);
  const watchIdRef = useRef<number | null>(null);

  const stopTracking = () => {
    if (watchIdRef.current !== null) {
      Geolocation.clearWatch(watchIdRef.current);
      watchIdRef.current = null;
    }
  };

  const getUntil = () => {
    if (!time || !quarter) return '';
    const [h, m] = time.split(':').map(Number);
    const untilMinute = String(Number(quarter)).padStart(2, '0');
    return `${String(h).padStart(2, '0')}:${untilMinute}`;
  };

  const sendLocation = async (coords: { latitude: number; longitude: number }) => {
    try {
      await fetch(apiUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          busId,
          latitude: coords.latitude,
          longitude: coords.longitude,
          status,
          until: getUntil(),
        }),
      });
      setLastSentTime(new Date());
    } catch (error) {
      console.error('送信失敗:', error);
    }
  };

  useEffect(() => {
    if (isTracking) {
      watchIdRef.current = Geolocation.watchPosition(
        (pos) => {
          setLocation(pos);
          sendLocation(pos.coords);
        },
        (error) => {
          console.error('位置情報取得エラー:', error);
          setErrorMsg(error.message);
        },
        {
          enableHighAccuracy: true,
          distanceFilter: 0,
          interval: 5000,
          fastestInterval: 2000,
        }
      );
    } else {
      stopTracking();
    }

    return () => {
      stopTracking();
    };
  }, [isTracking]);

  return {
    isTracking,
    setIsTracking,
    location,
    lastSentTime,
    errorMsg,
  };
}
