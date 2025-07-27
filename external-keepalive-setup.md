# External Keep-Alive Setup for Render.com

## Alternative Solutions to Keep Your Server Warm

### 1. UptimeRobot (Recommended)
- **Website**: https://uptimerobot.com
- **Free Plan**: Monitor up to 50 URLs with 5-minute intervals
- **Setup**:
  1. Sign up for a free account
  2. Add a new monitor
  3. Set URL: `https://happiness-game.onrender.com/api/health`
  4. Set interval: 5 minutes
  5. Enable the monitor

### 2. Cron-job.org
- **Website**: https://cron-job.org
- **Free Plan**: Unlimited jobs with minimum 1-minute interval
- **Setup**:
  1. Create a free account
  2. Create a new cron job
  3. Set URL: `https://happiness-game.onrender.com/api/health`
  4. Set schedule: `*/14 * * * *` (every 14 minutes)
  5. Enable the job

### 3. GitHub Actions (Free)
Create `.github/workflows/keep-alive.yml`:

```yaml
name: Keep Server Alive

on:
  schedule:
    # Run every 14 minutes
    - cron: '*/14 * * * *'
  workflow_dispatch: # Allow manual trigger

jobs:
  ping:
    runs-on: ubuntu-latest
    steps:
      - name: Ping server
        run: |
          curl -s -o /dev/null -w "%{http_code}" https://happiness-game.onrender.com/api/health
          echo "Server pinged at $(date)"
```

### 4. Cloudflare Workers (Free tier)
```javascript
// Cloudflare Worker script
addEventListener('scheduled', event => {
  event.waitUntil(handleScheduled())
})

async function handleScheduled() {
  const response = await fetch('https://happiness-game.onrender.com/api/health')
  console.log(`Pinged server: ${response.status}`)
}
```

Set up a cron trigger: `*/14 * * * *`

### 5. Better Uptime
- **Website**: https://betteruptime.com
- **Free Plan**: 10 monitors, 3-minute checks
- **Benefits**: Also provides status page

## Why 14 Minutes?
Render.com's free tier spins down services after 15 minutes of inactivity. By pinging every 14 minutes, we ensure the server never reaches the timeout threshold.

## Combining Solutions
For maximum reliability, you can use multiple solutions:
1. iOS app's built-in KeepAliveManager (primary)
2. UptimeRobot (backup)
3. GitHub Actions (secondary backup)

This ensures your server stays warm even if one method fails.