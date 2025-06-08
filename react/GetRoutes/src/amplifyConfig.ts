import { Amplify } from 'aws-amplify';
import Constants from 'expo-constants';

const { COGNITO_REGION, COGNITO_USER_POOL_ID, COGNITO_CLIENT_ID } = Constants.expoConfig?.extra || {};

Amplify.configure({
  Auth: {
    region: COGNITO_REGION,
    userPoolId: COGNITO_USER_POOL_ID,
    userPoolWebClientId: COGNITO_CLIENT_ID,
  },
});