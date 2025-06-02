import React, { useState } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Picker } from '@react-native-picker/picker';

export default function SettingsScreen() {
  const [status, setStatus] = useState('online');

  return (
    <View style={styles.container}>
      <Text style={styles.label}>状態</Text>
      <View style={styles.pickerWrapper}>
        <Picker
          selectedValue={status}
          onValueChange={(itemValue) => setStatus(itemValue)}
          style={styles.picker}
        >
          <Picker.Item label="オンライン" value="online" />
          <Picker.Item label="オフライン" value="offline" />
          <Picker.Item label="休憩中" value="break" />
        </Picker>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  label: { fontSize: 18, marginBottom: 8 },
  pickerWrapper: { borderWidth: 1, borderColor: '#ccc', borderRadius: 8, width: 200 },
  picker: { width: 200, height: 44 },
});
