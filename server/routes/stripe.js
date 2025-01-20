const express = require('express');
const router = express.Router();
const { stripe, stripeConfig } = require('../config/stripe');
const Subscription = require('../models/subscription');

// Stripe webhook 处理
router.post('/webhook', express.raw({type: 'application/json'}), async (req, res) => {
    try {
        const event = stripeConfig.verifyWebhookSignature(
            req.body,
            req.headers['stripe-signature']
        );

        switch (event.type) {
            case 'checkout.session.completed': {
                const session = event.data.object;
                
                await Subscription.create({
                    customerId: session.customer,
                    extensionId: session.metadata.extensionId,
                    stripeSubscriptionId: session.subscription,
                    email: session.customer_email,
                    status: 'active',
                    expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days
                });

                // 通知Chrome扩展
                // 这里需要实现通知扩展的逻辑
                break;
            }
            case 'customer.subscription.updated':
            case 'customer.subscription.deleted': {
                const subscription = event.data.object;
                
                await Subscription.updateOne(
                    { stripeSubscriptionId: subscription.id },
                    { 
                        status: subscription.status,
                        expiresAt: new Date(subscription.current_period_end * 1000)
                    }
                );
                break;
            }
        }

        res.json({received: true});
    } catch (err) {
        console.error('Webhook error:', err);
        res.status(400).send(`Webhook Error: ${err.message}`);
    }
});

// 创建结账会话
router.post('/create-checkout-session', async (req, res) => {
    try {
        const { planType, extensionId } = req.body;
        
        const session = await stripeConfig.createCheckoutSession({
            planType,
            extensionId
        });

        res.json({ url: session.url });
    } catch (err) {
        console.error('Create checkout session error:', err);
        res.status(500).json({ error: 'Failed to create checkout session' });
    }
});

// 验证订阅状态
router.post('/verify-subscription', async (req, res) => {
    try {
        const { extensionId } = req.body;
        
        const subscription = await Subscription.findOne({ 
            extensionId,
            status: 'active'
        });

        res.json({ 
            valid: !!subscription,
            subscription: subscription ? {
                status: subscription.status,
                expiresAt: subscription.expiresAt
            } : null
        });
    } catch (err) {
        res.status(500).json({ error: 'Verification failed' });
    }
});

module.exports = router;