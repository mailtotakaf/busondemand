import 'dotenv/config';

export default {
  expo: {
    name: 'GetRoutes',
    slug: 'getroutes',
    version: '1.0.0',
    sdkVersion: '50.0.0',
    extra: {
      COGNITO_REGION: process.env.COGNITO_REGION,
      COGNITO_USER_POOL_ID: process.env.COGNITO_USER_POOL_ID,
      COGNITO_CLIENT_ID: process.env.COGNITO_CLIENT_ID,
    },
  },
};
