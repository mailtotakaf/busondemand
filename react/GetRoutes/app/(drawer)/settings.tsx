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
      {/* ハンバーガーメニューボタン（右上） */}
      <TouchableOpacity
        style={styles.menuButton}
        onPress={() => navigation.openDrawer?.()}
      >
        <Ionicons name="menu-outline" size={28} />
      </TouchableOpacity>

      {/* 左上に「設定画面」 */}
      <Text style={styles.screenTitle}>設定画面</Text>

      {/* 以下は例：状態・時間・分のプルダウン */}
      <Text style={styles.label}>状態</Text>
      <View style={styles.pickerWrapper}>
        <Picker
          selectedValue={status}
          onValueChange={(itemValue) => setStatus(itemValue)}
          style={styles.picker}
        >
          <Picker.Item label="受付中" value="available" />
          <Picker.Item label="休憩中" value="break" />
          <Picker.Item label="本日受付終了" value="finish" />
        </Picker>
      </View>
      <View style={styles.row}>
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
        </View>
        <Text style={{ marginLeft: 8 }}>まで</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'flex-start', backgroundColor: '#fff', paddingTop: 40, paddingHorizontal: 20 },
  screenTitle: { fontSize: 22, fontWeight: 'bold', marginBottom: 24, marginTop: 0, alignSelf: 'flex-start' },
  label: { fontSize: 18, marginBottom: 8, alignSelf: 'flex-start' },
  pickerWrapper: { borderWidth: 1, borderColor: '#ccc', borderRadius: 8, width: 100 },
  picker: { width: 100, height: 44 },
  row: { flexDirection: 'row', alignItems: 'center', marginTop: 24 },
  menuButton: { position: 'absolute', top: 40, right: 20, zIndex: 10 }, // ← 右上に変更
});
