const config = {
  API_BASE_URL: process.env.NODE_ENV === 'production' 
    ? '' // Vercelでは同じドメインを使用
    : 'http://localhost:5002'
};

export default config;