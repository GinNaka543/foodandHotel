const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

module.exports = async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const { amount, userId, pointAmount, type } = req.body;
    
    // サブスクリプション支払いの場合はpointAmountは不要
    if (type === 'app_subscription') {
      if (!amount || !userId) {
        return res.status(400).json({ error: 'サブスクリプション支払いには amount と userId が必要です' });
      }
    } else {
      // ポイント購入の場合
      if (!amount || !userId || !pointAmount) {
        return res.status(400).json({ error: '必須パラメータが不足しています' });
      }
    }
    
    // Create payment intent
    const metadata = {
      userId: userId,
      type: type || 'point_purchase'
    };
    
    // ポイント購入の場合のみpointAmountを追加
    if (pointAmount) {
      metadata.pointAmount = pointAmount.toString();
    }
    
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount, // 金額（円）
      currency: 'jpy',
      statement_descriptor_suffix: 'HAPPINESS',
      metadata: metadata
    });
    
    res.json({
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
      publishableKey: process.env.STRIPE_PUBLISHABLE_KEY
    });
  } catch (error) {
    console.error('Payment intent creation error:', error);
    res.status(500).json({ error: error.message });
  }
}