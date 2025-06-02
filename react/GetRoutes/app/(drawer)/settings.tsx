import React, { useState } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Picker } from '@react-native-picker/picker';

export default function SettingsScreen() {
  const [status, setStatus] = useState('online');
  const [time, setTime] = useState('08:00');
  const [quarter, setQuarter] = useState('00');

  // 15分単位の選択肢
  const quarterOptions = [
    { label: '00分', value: '00' },
    { label: '15分', value: '15' },
    { label: '30分', value: '30' },
    { label: '45分', value: '45' },
  ];

  return (
    <View style={styles.container}>
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
        <br/>
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
        </View>&nbsp;まで
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center', backgroundColor: '#fff' },
  label: { fontSize: 18, marginBottom: 8 },
  pickerWrapper: { borderWidth: 1, borderColor: '#ccc', borderRadius: 8, width: 100 },
  picker: { width: 100, height: 44 },
  row: { flexDirection: 'row', alignItems: 'center' },
});
