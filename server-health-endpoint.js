// Example health endpoint for your Render.com server
// Add this to your existing server code (e.g., Express.js)

// If you're using Express.js:
app.get('/api/health', (req, res) => {
  // Simple health check
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'happiness-game-backend',
    uptime: process.uptime()
  });
});

// If you want a more comprehensive health check:
app.get('/api/health', async (req, res) => {
  try {
    // Check database connection (example)
    // await db.ping();
    
    // Check external services if needed
    const healthStatus = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'happiness-game-backend',
      uptime: process.uptime(),
      memory: {
        used: process.memoryUsage().heapUsed / 1024 / 1024,
        total: process.memoryUsage().heapTotal / 1024 / 1024
      },
      environment: process.env.NODE_ENV || 'production'
    };
    
    res.status(200).json(healthStatus);
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Middleware to log keep-alive requests (optional)
app.use((req, res, next) => {
  if (req.path === '/api/health') {
    console.log(`[Keep-Alive] Health check from ${req.ip} at ${new Date().toISOString()}`);
  }
  next();
});

// For other server frameworks:

// Fastify
fastify.get('/api/health', async (request, reply) => {
  return {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'happiness-game-backend'
  };
});

// Koa
router.get('/api/health', async (ctx) => {
  ctx.body = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'happiness-game-backend'
  };
});

// Basic Node.js HTTP server
const http = require('http');
const url = require('url');

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  
  if (parsedUrl.pathname === '/api/health' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'happiness-game-backend'
    }));
  }
  // ... other routes
});