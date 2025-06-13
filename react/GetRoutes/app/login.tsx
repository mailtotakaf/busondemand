import React, { useState } from 'react';
import { View, Text, TextInput, Button, StyleSheet, Platform } from 'react-native';
import { CognitoUserPool, CognitoUser, AuthenticationDetails } from 'amazon-cognito-identity-js';
import { useRouter } from 'expo-router';
import Constants from 'expo-constants';
import * as SecureStore from 'expo-secure-store';

// const { COGNITO_USER_POOL_ID, COGNITO_CLIENT_ID } = Constants.expoConfig?.extra || {};
// const { DRIVER_PROF_API } = Constants.expoConfig?.extra || {};
const DRIVER_PROF_API = "https://u98gvtrphh.execute-api.us-west-2.amazonaws.com/driver";

const poolData = {
  // UserPoolId: COGNITO_USER_POOL_ID,
  // ClientId: COGNITO_CLIENT_ID,
  UserPoolId: "us-west-2_uoaxagXJ3",
  ClientId: "lqtg505ssbpf9bo3dbr5halmi",
};
const userPool = new CognitoUserPool(poolData);

export default function LoginScreen() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const router = useRouter();

  const handleLogin = () => {
    const user = new CognitoUser({ Username: email, Pool: userPool });
    const authDetails = new AuthenticationDetails({ Username: email, Password: password });

    user.authenticateUser(authDetails, {
      onSuccess: async () => {
        try {
          // driver-apiにGETパラメータでメールアドレスを送信
          const res = await fetch(`${DRIVER_PROF_API}?email=${encodeURIComponent(email)}`);
          // console.log('res', res);
          if (res.status === 200) {
            user.getSession((err, session) => {
              if (session && session.isValid()) {
                const idToken = session.getIdToken().getJwtToken();
                if (Platform.OS === 'web') {
                  localStorage.setItem('idToken', idToken);
                } else {
                  SecureStore.setItemAsync('idToken', idToken);
                }
                router.replace('/');
              }
            });
          } else {
            setError('認証に失敗しました');
          }
        } catch (e) {
          setError('API通信エラー');
        }
      },
      onFailure: (err) => {
        setError(err.message || 'ログイン失敗');
      },
    });
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>ログイン</Text>
      <TextInput
        style={styles.input}
        placeholder="メールアドレス"
        value={email}
        onChangeText={setEmail}
        autoCapitalize="none"
      />
      <TextInput
        style={styles.input}
        placeholder="パスワード"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
      />
      {error ? <Text style={styles.error}>{error}</Text> : null}
      <Button title="ログイン" onPress={handleLogin} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, justifyContent: 'center', padding: 24, backgroundColor: '#dde' },
  title: { fontSize: 24, fontWeight: 'bold', marginBottom: 24, textAlign: 'center' },
  input: { borderWidth: 1, borderColor: '#ccc', borderRadius: 8, padding: 12, marginBottom: 16, backgroundColor: '#fff' },
  error: { color: 'red', marginBottom: 16, textAlign: 'center' },
});