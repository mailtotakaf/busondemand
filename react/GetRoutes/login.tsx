import React, { useState } from 'react';
import { View, TextInput, Button, Alert } from 'react-native';
import { signIn } from 'aws-amplify/auth';
import { Amplify } from 'aws-amplify';
import config from './src/aws-exports'; // 適宜パスを調整してください

Amplify.configure(config);

export default function Login() {
  const [user, setUser] = useState('');
  const [pass, setPass] = useState('');

  const handleLogin = async () => {
    try {
      const res = await signIn({ username: user, password: pass });
      console.log('login ok', res);
      Alert.alert('ログイン成功');
    } catch (e: any) {
      console.error('login ng', e);
      Alert.alert('ログイン失敗', e.message || 'エラーが発生しました');
    }
  };

  return (
    <View>
      <TextInput placeholder="username" onChangeText={setUser} />
      <TextInput placeholder="password" secureTextEntry onChangeText={setPass} />
      <Button title="login" onPress={handleLogin} />
    </View>
  );
}
