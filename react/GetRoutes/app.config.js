import 'dotenv/config';

export default {
  expo: {
    name: 'GetRoutes',
    slug: 'getroutes',
    version: '1.0.0',
    sdkVersion: '50.0.0',
    extra: {
      POST_BUS_LOCATIONS_API_URL: process.env.POST_BUS_LOCATIONS_API_URL,
    //   API_KEY: process.env.API_KEY,
    //   DB_PASSWORD: process.env.DB_PASSWORD,
    },
  },
};
