// login.tsx ────────
import React, { useState } from 'react';
import { View, TextInput, Button } from 'react-native';
import { Auth } from 'aws-amplify';

export default function Login() {
  const [user, setUser] = useState('');
  const [pass, setPass] = useState('');

  const handleLogin = async () => {
    try {
      const res = await Auth.signIn(user, pass);
      console.log('login ok', res);
    } catch (e) {
      console.error('login ng', e);
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