export const CONFIG = {
  baseUrl: process.env.MOTCHILL_BASE_URL || 'https://motchilltv.taxi',
  playerKey: process.env.MOTCHILL_PLAYER_KEY || 'sB7hP!c9X3@rVn$5mGqT1eLzK!fU8dA2',
  webSourceKey: process.env.MOTCHILL_WEB_SOURCE_KEY || '13354665901265567120123456777992',
  webSourceIv: process.env.MOTCHILL_WEB_SOURCE_IV || '1254566897125456',
  port: Number.parseInt(process.env.PORT || '3000', 10),
};
