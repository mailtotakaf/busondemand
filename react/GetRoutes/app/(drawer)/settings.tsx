import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { Picker } from '@react-native-picker/picker';
import { Ionicons } from '@expo/vector-icons';
import { useNavigation } from 'expo-router';

export default function SettingsScreen() {
  const [status, setStatus] = useState('online');
  const [time, setTime] = useState('08:00');
  const [quarter, setQuarter] = useState('00');
  const navigation = useNavigation();

  // 15分単位の選択肢
  const quarterOptions = [
    { label: '00分', value: '00' },
    { label: '15分', value: '15' },
    { label: '30分', value: '30' },
    { label: '45分', value: '45' },
  ];

  return (
    <View style={styles.container}>
      {/* ハンバーガーメニューボタン */}
      <TouchableOpacity
        style={styles.menuButton}
        onPress={() => navigation.openDrawer?.()}
      >
        <Ionicons name="menu-outline" size={28} />
      </TouchableOpacity>

      <Text style={styles.screenTitle}>設定画面</Text>

    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' },
  screenTitle: { fontSize: 22, fontWeight: 'bold', marginBottom: 24, marginTop: 24 },
  row: { flexDirection: 'row', alignItems: 'center', marginTop: 24 },
  menuButton: { position: 'absolute', top: 40, left: 20, zIndex: 10 },
});
