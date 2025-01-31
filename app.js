require('dotenv').config();
const express = require('express');
const path = require('path');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const mongoose = require('mongoose');

const indexRoutes = require('./server/routes/index');
const stripeRoutes = require('./server/routes/stripe');

const app = express();

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI)
    .then(() => console.log('Connected to MongoDB'))
    .catch(err => console.error('MongoDB connection error:', err));

// Security middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            ...helmet.contentSecurityPolicy.getDefaultDirectives(),
            "script-src": ["'self'", "https://js.stripe.com"],
            "frame-src": ["'self'", "https://js.stripe.com"],
        },
    },
}));

// CORS configuration
app.use(cors({
    origin: process.env.ALLOWED_ORIGINS.split(','),
    credentials: true
}));

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100 // limit each IP to 100 requests per windowMs
});
app.use('/api/', limiter);

// Body parsing
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Static files
app.use(express.static(path.join(__dirname, 'public')));

// View engine setup
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Routes
app.use('/', indexRoutes);
app.use('/api/stripe', stripeRoutes);

// Error handling
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).render('error', {
        message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
    });
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});

app.post('/create-checkout-session', async (req, res) => {
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [{
        price_data: {
          currency: 'usd',
          product_data: { name: 'AI English Pro' },
          unit_amount: 699,
        },
        quantity: 1,
      }],
      mode: 'payment',
      success_url: `${process.env.BASE_URL}/success.html`,
      cancel_url: `${process.env.BASE_URL}/cancel.html`,
    });
  
    res.json({ id: session.id });
  });