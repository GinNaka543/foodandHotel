# Happiness Game Admin Server

Backend API server for the Happiness Game admin panel.

## Features

- User subscription management
- Device-based payment tracking
- Stripe payment integration
- Firebase Firestore database
- Admin dashboard statistics

## Setup

### Local Development

1. Install dependencies:
```bash
npm install
```

2. Create environment variables:
```bash
cp .env.example .env
```

3. Configure environment variables in `.env`:
- Add your Stripe secret key
- Add your Stripe publishable key
- Add your Stripe webhook secret

4. Add Firebase service account:
- Place your `serviceAccountKey.json` file in the server directory

5. Start the server:
```bash
npm start
```

### Vercel Deployment

1. Install Vercel CLI:
```bash
npm install -g vercel
```

2. Deploy to Vercel:
```bash
vercel --prod
```

3. Set environment variables in Vercel dashboard:
- `STRIPE_SECRET_KEY`
- `STRIPE_PUBLISHABLE_KEY` 
- `STRIPE_WEBHOOK_SECRET`

4. Upload `serviceAccountKey.json` as a Vercel environment file

## API Endpoints

- `GET /api/subscriptions` - Get all user subscriptions
- `GET /api/subscriptions/stats` - Get subscription statistics
- `POST /api/subscriptions/toggle` - Toggle user subscription status
- `POST /api/create-payment-intent` - Create Stripe payment intent
- `POST /api/stripe-webhook` - Handle Stripe webhooks

## Environment Variables

| Variable | Description |
|----------|-------------|
| `STRIPE_SECRET_KEY` | Stripe secret key for payments |
| `STRIPE_PUBLISHABLE_KEY` | Stripe publishable key |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook endpoint secret |
| `PORT` | Server port (default: 5002) |