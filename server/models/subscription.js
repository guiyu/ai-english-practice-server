const mongoose = require('mongoose');

const subscriptionSchema = new mongoose.Schema({
    customerId: {
        type: String,
        required: true,
        unique: true
    },
    extensionId: {  // 对应Chrome扩展的ID
        type: String,
        required: true
    },
    stripeSubscriptionId: {
        type: String,
        required: true,
        unique: true
    },
    status: {
        type: String,
        enum: ['active', 'canceled', 'past_due', 'unpaid'],
        default: 'active'
    },
    email: {
        type: String,
        required: true
    },
    planType: {
        type: String,
        enum: ['monthly', 'yearly'],
        default: 'monthly'
    },
    createdAt: {
        type: Date,
        default: Date.now
    },
    expiresAt: {
        type: Date,
        required: true
    }
});

module.exports = mongoose.model('Subscription', subscriptionSchema);