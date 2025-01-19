const stripeService = require('../services/stripeService');
const PaymentModel = require('../models/Payment');

exports.createCheckoutSession = async (req, res) => {
  try {
    const { userId } = req.body;
    const session = await stripeService.createCheckoutSession(userId);
    res.json({ sessionId: session.id });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.handleWebhook = async (req, res) => {
  try {
    await stripeService.handleWebhookEvent(req);
    res.json({ received: true });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};