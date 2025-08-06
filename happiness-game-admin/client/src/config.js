const config = {
  API_BASE_URL: process.env.NODE_ENV === 'production' 
    ? 'https://happiness-game-api.vercel.app' // デプロイ済みのサーバーURL
    : 'http://localhost:5002'
};

export default config;