#!/bin/bash

# 安装依赖
sudo apt update && sudo apt install -y nodejs npm nginx

# 配置Nginx
sudo tee /etc/nginx/sites-available/chinese-helper <<EOF
server {
    listen 80;
    server_name yourdomain.com;
    
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

# 启用配置
sudo ln -s /etc/nginx/sites-available/chinese-helper /etc/nginx/sites-enabled/
sudo systemctl restart nginx

# 安装PM2
sudo npm install pm2 -g

# 项目依赖安装
npm install

# 构建项目
npm run build

# 启动应用
pm2 start npm --name "chinese-helper" -- start

# 设置开机启动
pm2 save
pm2 startup
