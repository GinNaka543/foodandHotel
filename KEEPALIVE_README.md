# Keep-Alive Implementation for Render.com

This implementation provides multiple methods to keep your Render.com free-tier server active and prevent cold starts.

## Overview

Render.com's free tier automatically spins down services after 15 minutes of inactivity. This causes "cold starts" where the first request after inactivity takes 30-60 seconds while the server restarts. Our keep-alive solution pings the server every 14 minutes to prevent this.

## Implementation Components

### 1. iOS App Integration (Primary Method)

**Files Added:**
- `HappinessGameSwift/KeepAliveManager.swift` - Main keep-alive manager class
- `HappinessGameSwift/ServerStatusView.swift` - Debug/monitoring UI

**Features:**
- Automatic server pinging every 14 minutes
- Background task support for pinging when app is in background
- Server health monitoring UI (Debug builds only)
- Intelligent retry and error handling

**Integration Steps Completed:**
1. Created `KeepAliveManager` singleton that starts automatically on app launch
2. Added background modes to `Info.plist` for background execution
3. Integrated with existing `PointPurchaseView` prewarm functionality
4. Added Server Status button in HomeScreen (Debug builds only)

### 2. External Keep-Alive Scripts

**Shell Script:** `keep-alive-cronjob.sh`
```bash
# Run every 14 minutes via cron:
*/14 * * * * /path/to/keep-alive-cronjob.sh
```

**Python Script:** `keep-alive.py`
```bash
# Run with Python 3:
python3 keep-alive.py
```

### 3. External Services Setup

See `external-keepalive-setup.md` for detailed instructions on setting up:
- UptimeRobot (recommended)
- Cron-job.org
- GitHub Actions
- Cloudflare Workers

## Server-Side Requirements

Your Render.com server needs a health endpoint at `/api/health`. Example implementation provided in `server-health-endpoint.js`.

## Usage

### In the iOS App

The keep-alive service starts automatically when the app launches. No user action required.

**To monitor server status (Debug builds):**
1. Go to Home screen
2. Tap the "Server" button
3. View server status and manually trigger pings

### Using External Scripts

**One-time ping:**
```bash
./keep-alive-cronjob.sh
# or
python3 keep-alive.py
```

**Scheduled (macOS/Linux):**
```bash
# Add to crontab
crontab -e
# Add this line:
*/14 * * * * /full/path/to/keep-alive-cronjob.sh
```

## Monitoring

The iOS app provides real-time monitoring through the ServerStatusView:
- Current server status (Online/Offline)
- Last ping time
- Response time
- Manual ping and warm-up controls

## Best Practices

1. **Use Multiple Methods**: Combine iOS app pinging with at least one external service for redundancy
2. **Monitor Logs**: Check server logs to ensure pings are being received
3. **Adjust Timing**: 14-minute interval provides a safety margin for Render's 15-minute timeout
4. **Test Thoroughly**: Verify background pinging works on actual iOS devices

## Troubleshooting

**Server still has cold starts:**
- Verify the health endpoint is returning 200 OK
- Check that background modes are properly configured in Xcode
- Ensure at least one external service is also pinging

**Background pinging not working:**
- Enable "Background App Refresh" in iOS Settings
- Test on a real device (simulator limitations)
- Check BGTaskScheduler logs in Xcode console

**High server costs:**
- The keep-alive will prevent the free tier from spinning down
- Consider scheduling keep-alive only during active hours
- Use Render's paid tier for production apps

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   iOS App       │     │ External Service│     │  Render Server  │
│ KeepAliveManager├────►│  (UptimeRobot)  ├────►│  /api/health    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                                                │
         └────────────────────────────────────────────────┘
                     Every 14 minutes
```

## Important Notes

- Keep-alive prevents the free tier from saving resources
- Consider environmental impact of keeping servers always-on
- For production apps, upgrade to Render's paid tier
- The iOS app method alone may not be sufficient if no users have the app open

## Support

For issues or questions:
1. Check Render.com status page
2. Verify server logs in Render dashboard
3. Test health endpoint manually: `curl https://happiness-game.onrender.com/api/health`