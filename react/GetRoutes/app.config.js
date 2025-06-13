// const dotenv = require("dotenv");
// dotenv.config();

export default {
  expo: {
    name: 'GetRoutes',
    slug: 'getroutes',
    version: '1.0.0',
    sdkVersion: '53.0.0',
    // extra: {
    //   POST_BUS_LOCATIONS_API_URL: process.env.POST_BUS_LOCATIONS_API_URL,
    //   USER_LOCATIONS_API: process.env.USER_LOCATIONS_API,
    //   // GET_ROUTES_API_URL: process.env.GET_ROUTES_API_URL,
    //   COGNITO_REGION: process.env.COGNITO_REGION,
    //   COGNITO_USER_POOL_ID: process.env.COGNITO_USER_POOL_ID,
    //   COGNITO_CLIENT_ID: process.env.COGNITO_CLIENT_ID,
    //   DRIVER_PROF_API: process.env.DRIVER_PROF_API,
    // },
    plugins: [
      "expo-font",
      "expo-router",
      "expo-secure-store"
    ],
    jsEngine: "jsc",
  },
};
