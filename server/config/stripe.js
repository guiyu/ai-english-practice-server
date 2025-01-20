const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

// 需要替换的值:
// * PRICE_ID_MONTHLY: 从Stripe后台获取的月付价格ID
// * PRICE_ID_YEARLY: 从Stripe后台获取的年付价格ID
const PRICE_IDS = {
    monthly: 'PRICE_ID_MONTHLY',  // 替换为实际的Stripe月付价格ID
    yearly: 'PRICE_ID_YEARLY'     // 替换为实际的Stripe年付价格ID
};

const stripeConfig = {
    createCheckoutSession: async (options) => {
        const { planType = 'monthly', customerId = null } = options;
        
        return await stripe.checkout.sessions.create({
            mode: 'subscription',
            payment_method_types: ['card'],
            line_items: [
                {
                    price: PRICE_IDS[planType],
                    quantity: 1,
                },
            ],
            success_url: `${process.env.BASE_URL}/success?session_id={CHECKOUT_SESSION_ID}`,
            cancel_url: `${process.env.BASE_URL}/cancel`,
            customer: customerId,
            client_reference_id: options.extensionId,
            metadata: {
                extensionId: options.extensionId
            }
        });
    },

    createPortalSession: async (customerId) => {
        return await stripe.billingPortal.sessions.create({
            customer: customerId,
            return_url: process.env.BASE_URL,
        });
    },

    // 添加其他Stripe相关的辅助函数
    verifyWebhookSignature: (payload, signature) => {
        try {
            return stripe.webhooks.constructEvent(
                payload,
                signature,
                process.env.STRIPE_WEBHOOK_SECRET
            );
        } catch (err) {
            throw new Error(`Webhook verification failed: ${err.message}`);
        }
    }
};

module.exports = {
    stripe,
    stripeConfig,
    PRICE_IDS
};