#!/bin/bash

# deploy.sh
# 部署AI英语口语练习Pro版购买页面
# 使用方法: 
# 1. ./deploy.sh <ip_or_domain> <stripe_secret_key> <stripe_publishable_key> <stripe_webhook_secret> <extension_id>
# 或者
# 2. ./deploy.sh -e /path/to/.env

# 输出彩色信息的函数
print_info() {
    echo -e "\e[1;34m[INFO] $1\e[0m"
}

print_success() {
    echo -e "\e[1;32m[SUCCESS] $1\e[0m"
}

print_error() {
    echo -e "\e[1;31m[ERROR] $1\e[0m"
}

print_warning() {
    echo -e "\e[1;33m[WARNING] $1\e[0m"
}

# 检查依赖项
check_dependencies() {
    local deps=("curl" "wget" "git")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            print_info "Installing $dep..."
            apt-get install -y "$dep"
        fi
    done
}

# 检查MongoDB状态
check_mongodb() {
    if ! systemctl is-active --quiet mongod; then
        print_warning "MongoDB is not running. Attempting to start..."
        systemctl start mongod || {
            print_error "Failed to start MongoDB. Please check the logs:"
            journalctl -u mongod
            exit 1
        }
    fi
}

# 检查输入是IP还是域名
is_ip() {
    if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

# 从.env文件读取变量
load_env() {
    local env_file=$1
    if [[ ! -f "$env_file" ]]; then
        print_error "ENV file not found: $env_file"
        exit 1
    fi

    # 读取并导出环境变量
    while IFS='=' read -r key value; do
        # 忽略注释和空行
        if [[ $key =~ ^[^#] && ! -z "$key" ]]; then
            # 去除值中的引号和空格
            value=$(echo "$value" | tr -d '"' | tr -d "'")
            # 导出变量
            declare -g "$key=$value"
        fi
    done < "$env_file"

    # 检查必需的变量
    local required_vars=("IP_OR_DOMAIN" "STRIPE_SECRET_KEY" "STRIPE_PUBLISHABLE_KEY" "STRIPE_WEBHOOK_SECRET" "EXTENSION_ID")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            print_error "Required variable $var not found in $env_file"
            exit 1
        fi
    done
}

# 错误处理
set -e
trap 'print_error "An error occurred during deployment. Check the error message above."' ERR

# 检查是否是root用户
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root"
    exit 1
fi

# 检查输入参数
if [[ "$1" == "-e" ]]; then
    if [[ -z "$2" ]]; then
        print_error "Please provide the path to .env file"
        echo "Usage: $0 -e /path/to/.env"
        exit 1
    fi
    print_info "Loading configuration from $2"
    load_env "$2"
elif [[ "$#" -eq 5 ]]; then
    IP_OR_DOMAIN=$1
    STRIPE_SECRET_KEY=$2
    STRIPE_PUBLISHABLE_KEY=$3
    STRIPE_WEBHOOK_SECRET=$4
    EXTENSION_ID=$5
else
    print_error "Invalid arguments"
    echo "Usage: "
    echo "  $0 <ip_or_domain> <stripe_secret_key> <stripe_publishable_key> <stripe_webhook_secret> <extension_id>"
    echo "  or"
    echo "  $0 -e /path/to/.env"
    exit 1
fi

APP_DIR="/var/www/purchase"
NGINX_CONF="/etc/nginx/sites-available/purchase"

# 更新系统并安装依赖
print_info "Updating system..."
apt-get update
apt-get upgrade -y

# 检查基础依赖
check_dependencies

# 安装必要的软件
print_info "Installing required packages..."
apt-get install -y nginx software-properties-common gnupg

# 如果是域名，则安装SSL相关包
if ! is_ip "$IP_OR_DOMAIN"; then
    apt-get install -y certbot python3-certbot-nginx
fi

# 安装Node.js
print_info "Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
    apt-get install -y nodejs
fi

# 安装PM2
print_info "Installing PM2..."
if ! command -v pm2 &> /dev/null; then
    npm install -g pm2
fi

# 安装MongoDB
print_info "Installing MongoDB..."
if ! command -v mongod &> /dev/null; then
    wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    apt-get update
    apt-get install -y mongodb-org
fi

# 创建应用目录
print_info "Creating application directory..."
mkdir -p $APP_DIR
cd $APP_DIR

# 配置MongoDB
print_info "Configuring MongoDB..."
systemctl daemon-reload
systemctl enable mongod
systemctl start mongod || {
    print_error "Failed to start MongoDB. Checking service status..."
    systemctl status mongod
    exit 1
}

# 等待MongoDB启动
sleep 5

# 验证MongoDB运行状态
check_mongodb

# 创建并初始化Node.js项目
print_info "Initializing Node.js project..."

# 创建主要目录结构
mkdir -p $APP_DIR/views
mkdir -p $APP_DIR/public/{css,js,images}
mkdir -p $APP_DIR/models
mkdir -p $APP_DIR/routes

# 创建package.json
cat > $APP_DIR/package.json << 'EOF'
{
  "name": "ai-english-purchase",
  "version": "1.0.0",
  "description": "Purchase server for AI English Speaking Practice Pro",
  "main": "app.js",
  "private": true,
  "scripts": {
    "start": "node app.js"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "express": "^4.18.2",
    "mongoose": "^7.6.3",
    "stripe": "^14.1.0",
    "winston": "^3.11.0",
    "ejs": "^3.1.9",
    "helmet": "^7.1.0"
  }
}
EOF

# 创建主应用文件
cat > $APP_DIR/app.js << 'EOF'
require('dotenv').config();
const express = require('express');
const path = require('path');
const cors = require('cors');
const mongoose = require('mongoose');
const helmet = require('helmet');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const app = express();

// 安全中间件
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            ...helmet.contentSecurityPolicy.getDefaultDirectives(),
            "script-src": ["'self'", "https://js.stripe.com", "'unsafe-inline'"],
            "frame-src": ["'self'", "https://js.stripe.com"],
        },
    },
}));

// 配置视图引擎
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(express.static('public'));

// 配置CORS
app.use(cors({
    origin: process.env.ALLOWED_ORIGINS.split(','),
    credentials: true
}));

// body解析中间件
app.use(express.json());

// 连接MongoDB
mongoose.connect(process.env.MONGODB_URI)
    .then(() => console.log('Connected to MongoDB'))
    .catch(err => console.error('MongoDB connection error:', err));

// 订阅模型
const subscriptionSchema = new mongoose.Schema({
    customerId: { type: String, required: true, unique: true },
    status: { type: String, required: true },
    planType: { type: String, required: true },
    createdAt: { type: Date, default: Date.now },
    expiresAt: { type: Date, required: true }
});

const Subscription = mongoose.model('Subscription', subscriptionSchema);

// 路由处理
app.get('/', (req, res) => {
    res.render('index', {
        stripePublicKey: process.env.STRIPE_PUBLISHABLE_KEY,
        extensionId: process.env.EXTENSION_ID
    });
});

app.post('/api/stripe/create-checkout-session', async (req, res) => {
    try {
        const session = await stripe.checkout.sessions.create({
            payment_method_types: ['card'],
            line_items: [{
                price: process.env.STRIPE_PRICE_ID,
                quantity: 1,
            }],
            mode: 'subscription',
            success_url: `${process.env.BASE_URL}/success?session_id={CHECKOUT_SESSION_ID}`,
            cancel_url: `${process.env.BASE_URL}/cancel`,
            client_reference_id: process.env.EXTENSION_ID,
            metadata: {
                extension_id: process.env.EXTENSION_ID
            }
        });
        res.json({ url: session.url });
    } catch (error) {
        console.error('Create checkout session error:', error);
        res.status(500).json({ error: 'Failed to create checkout session' });
    }
});

app.post('/api/stripe/webhook', express.raw({type: 'application/json'}), async (req, res) => {
    const sig = req.headers['stripe-signature'];
    try {
        const event = stripe.webhooks.constructEvent(
            req.body,
            sig,
            process.env.STRIPE_WEBHOOK_SECRET
        );

        switch (event.type) {
            case 'checkout.session.completed':
                const session = event.data.object;
                await Subscription.create({
                    customerId: session.customer,
                    status: 'active',
                    planType: 'monthly',
                    expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
                });
                break;
        }

        res.json({received: true});
    } catch (err) {
        console.error('Webhook error:', err.message);
        res.status(400).send(`Webhook Error: ${err.message}`);
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
EOF

# 创建视图模板
cat > $APP_DIR/views/index.ejs << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Upgrade to Pro - AI English Speaking Practice</title>
    <link rel="stylesheet" href="/css/style.css">
    <script src="https://js.stripe.com/v3/"></script>
</head>
<body>
    <div class="container">
        <div class="pricing-card">
            <h1>Upgrade to Pro</h1>
            <div class="price">
                <span class="amount">$6.99</span>
                <span class="period">/month</span>
            </div>
            <ul class="features">
                <li>Unlimited Practice Sessions</li>
                <li>AI Voice Synthesis</li>
                <li>Advanced Speech Analysis</li>
                <li>Priority Support</li>
            </ul>
            <button id="checkout-button" class="checkout-btn">Subscribe Now</button>
            <div class="guarantee">30-day money-back guarantee</div>
        </div>
    </div>
    <script src="/js/purchase.js"></script>
</body>
</html>
EOF

# 创建样式文件
cat > $APP_DIR/public/css/style.css << 'EOF'
/* 基础样式 */
:root {
    --primary: #2563eb;
    --primary-hover: #1d4ed8;
    --surface: #ffffff;
    --background: #f8fafc;
    --text: #0f172a;
    --border: #e2e8f0;
}

body {
    margin: 0;
    padding: 20px;
    font-family: -apple-system, system-ui, sans-serif;
    background: var(--background);
    color: var(--text);
    line-height: 1.5;
}

.container {
    max-width: 480px;
    margin: 40px auto;
    padding: 0 20px;
}

.pricing-card {
    background: var(--surface);
    border-radius: 16px;
    padding: 32px;
    box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
    text-align: center;
}

.price {
    margin: 24px 0;
}

.amount {
    font-size: 48px;
    font-weight: 700;
    color: var(--primary);
}

.period {
    color: #64748b;
}

.features {
    list-style: none;
    padding: 0;
    margin: 32px 0;
}

.features li {
    padding: 8px 0;
    color: #475569;
}

.features li:before {
    content: "✓";
    color: var(--primary);
    margin-right: 8px;
}

.checkout-btn {
    width: 100%;
    padding: 16px;
    border: none;
    border-radius: 8px;
    background: var(--primary);
    color: white;
    font-size: 18px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
}

.checkout-btn:hover {
    background: var(--primary-hover);
}

.guarantee {
    margin-top: 24px;
    color: #64748b;
    font-size: 14px;
}
EOF

# 创建前端JavaScript
cat > $APP_DIR/public/js/purchase.js << 'EOF'
document.addEventListener('DOMContentLoaded', () => {
    const stripe = Stripe(window.stripePublicKey);
    const checkoutButton = document.getElementById('checkout-button');

    checkoutButton.addEventListener('click', async () => {
        try {
            checkoutButton.disabled = true;
            checkoutButton.textContent = 'Processing...';

            const response = await fetch('/api/stripe/create-checkout-session', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            });

            if (!response.ok) {
                throw new Error('Network response was not ok');
            }

            const { url } = await response.json();
            window.location = url;
        } catch (error) {
            console.error('Error:', error);
            checkoutButton.disabled = false;
            checkoutButton.textContent = 'Try again';
        }
    });
});
EOF

# 创建.env文件
print_info "Creating environment file..."
if is_ip "$IP_OR_DOMAIN"; then
    BASE_URL="http://$IP_OR_DOMAIN"
else
    BASE_URL="https://$IP_OR_DOMAIN"
fi

cat > $APP_DIR/.env << EOF
PORT=3000
NODE_ENV=production
MONGODB_URI=mongodb://localhost:27017/ai_english_pro
STRIPE_SECRET_KEY=$STRIPE_SECRET_KEY
STRIPE_PUBLISHABLE_KEY=$STRIPE_PUBLISHABLE_KEY
STRIPE_WEBHOOK_SECRET=$STRIPE_WEBHOOK_SECRET
EXTENSION_ID=$EXTENSION_ID
BASE_URL=$BASE_URL
ALLOWED_ORIGINS=chrome-extension://$EXTENSION_ID
EOF

# 配置Nginx
print_info "Configuring Nginx..."
cat > $NGINX_CONF << EOF
server {
    listen 80;
    server_name $IP_OR_DOMAIN;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' https://js.stripe.com; script-src 'self' https://js.stripe.com 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; frame-src https://js.stripe.com;" always;
}
EOF

# 启用站点配置
ln -sf $NGINX_CONF /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# 如果是域名，则配置SSL
if ! is_ip "$IP_OR_DOMAIN"; then
    print_info "Configuring SSL with Let's Encrypt..."
    certbot --nginx -d $IP_OR_DOMAIN --non-interactive --agree-tos --email webmaster@$IP_OR_DOMAIN
fi

# 安装项目依赖
print_info "Installing Node.js dependencies..."
cd $APP_DIR
npm install --production

# 设置文件权限
print_info "Setting file permissions..."
chown -R www-data:www-data $APP_DIR
chmod -R 755 $APP_DIR

# 启动应用
print_info "Starting application with PM2..."
pm2 start app.js --name "purchase-server"
pm2 save
pm2 startup

# 如果是域名，则配置自动更新SSL证书
if ! is_ip "$IP_OR_DOMAIN"; then
    print_info "Configuring automatic SSL renewal..."
    echo "0 0 1 * * certbot renew --quiet" | crontab -
fi

# 输出总结信息
print_success "Deployment completed successfully!"
echo "================================================================="
echo "Website URL: $BASE_URL"
echo "MongoDB URI: mongodb://localhost:27017/ai_english_pro"
echo "PM2 status command: pm2 status"
echo "Application logs: pm2 logs purchase-server"
echo "Nginx logs:"
echo "  - Access: tail -f /var/nginx/access.log"
echo "  - Error: tail -f /var/nginx/error.log"
echo "================================================================="
echo "Don't forget to:"
echo "1. Set up Stripe webhook endpoint: $BASE_URL/api/stripe/webhook"
echo "2. Update Chrome extension with new address"
echo "3. Test the payment flow with Stripe test cards"
echo "4. Monitor the logs for any errors"
echo "================================================================="