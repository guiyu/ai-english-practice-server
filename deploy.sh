#!/bin/bash

# deploy.sh
# 部署AI英语口语练习Pro版购买页面
# 使用方法: 
# 1. ./deploy.sh <ip_or_domain> <stripe_secret_key> <stripe_publishable_key> <stripe_webhook_secret> <extension_id>
# 或者
# 2. ./deploy.sh -e /path/to/.env

# 函数：从.env文件读取变量
load_env() {
    local env_file=$1
    if [[ ! -f "$env_file" ]]; then
        print_error "ENV file not found: $env_file"
        exit 1
    }

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

# 彩色输出函数
print_info() {
    echo -e "\e[1;34m[INFO] $1\e[0m"
}

print_success() {
    echo -e "\e[1;32m[SUCCESS] $1\e[0m"
}

print_error() {
    echo -e "\e[1;31m[ERROR] $1\e[0m"
}

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

if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <ip_or_domain> <stripe_secret_key> <stripe_publishable_key> <stripe_webhook_secret> <extension_id>"
    exit 1
fi

IP_OR_DOMAIN=$1
STRIPE_SECRET_KEY=$2
STRIPE_PUBLISHABLE_KEY=$3
STRIPE_WEBHOOK_SECRET=$4
EXTENSION_ID=$5
APP_DIR="/var/www/purchase"
NGINX_CONF="/etc/nginx/sites-available/purchase"

# 检查输入是IP还是域名
is_ip() {
    if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

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

# 错误处理
set -e
trap 'print_error "An error occurred during deployment. Check the error message above."' ERR

# 检查是否是root用户
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root"
    exit 1
fi

# 更新系统
print_info "Updating system..."
apt-get update
apt-get upgrade -y

# 安装必要的软件
print_info "Installing required packages..."
apt-get install -y curl git nginx software-properties-common mongodb

# 如果是域名，则安装SSL相关包
if ! is_ip "$IP_OR_DOMAIN"; then
    apt-get install -y certbot python3-certbot-nginx
fi

# 安装Node.js
print_info "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
apt-get install -y nodejs

# 安装PM2
print_info "Installing PM2..."
npm install -g pm2

# 创建应用目录
print_info "Creating application directory..."
mkdir -p $APP_DIR
cd $APP_DIR

# 配置MongoDB
print_info "Configuring MongoDB..."
systemctl enable mongodb
systemctl start mongodb

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

# 安装依赖
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