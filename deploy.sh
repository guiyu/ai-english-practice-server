#!/bin/bash
# 完整部署脚本（需以root权限执行）

set -e # 遇到错误立即退出

# 基础配置
DOMAIN="yourdomain.com"
DB_NAME="chinese_helper"
DB_USER="helper"
DB_PASS="SecurePassword123"
JWT_SECRET=$(openssl rand -hex 32)

echo "=== 开始部署 Chinese Helper ==="

# 安装系统依赖
echo "安装系统依赖..."
apt update && apt upgrade -y
apt install -y nodejs npm nginx postgresql postgresql-contrib redis certbot python3-certbot-nginx

# 配置PostgreSQL
echo "配置数据库..."
sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME};"
sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"

# 创建应用目录
echo "创建应用目录..."
APP_DIR="/opt/chinese-helper"
mkdir -p ${APP_DIR}
chown -R deployer:deployer ${APP_DIR}

# 切换到部署用户
su - deployer << EOSU
set -e

# 克隆代码库
echo "克隆代码库..."
git clone https://github.com/your-repo/chinese-helper.git ${APP_DIR}
cd ${APP_DIR}

# 安装项目依赖
echo "安装Node.js依赖..."
npm install
npx prisma generate

# 配置环境变量
echo "配置环境变量..."
cat > .env.local << EOF
DATABASE_URL="postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}?schema=public"
STRIPE_SECRET_KEY="your_stripe_key"
STRIPE_WEBHOOK_SECRET="your_webhook_secret"
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY="your_publishable_key"
JWT_SECRET="${JWT_SECRET}"
TTS_API_KEY="your_tts_key"
NEXT_PUBLIC_BASE_URL="https://${DOMAIN}"
EOF

# 数据库迁移
echo "执行数据库迁移..."
npx prisma migrate deploy

# 构建应用
echo "构建生产版本..."
npm run build
EOSU

# 配置Nginx
echo "配置Nginx..."
cat > /etc/nginx/sites-available/chinese-helper << EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

ln -s /etc/nginx/sites-available/chinese-helper /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# 获取SSL证书
echo "申请SSL证书..."
certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m admin@${DOMAIN}

# 配置PM2
echo "配置PM2..."
npm install -g pm2
sudo -u deployer pm2 start npm --name "chinese-helper" -- start --prefix ${APP_DIR}
pm2 save
pm2 startup systemd -u deployer --hp /home/deployer

# 配置定时任务
echo "配置定时任务..."
(crontab -l 2>/dev/null; echo "0 0 * * * curl -X POST https://${DOMAIN}/api/usage/reset") | crontab -

echo "=== 部署完成！访问 https://${DOMAIN} ==="
