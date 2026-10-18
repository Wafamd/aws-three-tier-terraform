#!/bin/bash
set -euxo pipefail

dnf -y update
dnf -y install nginx mariadb105 jq awscli

# App-tier config that a real application would read from.
cat >/etc/app.env <<EOF
DB_HOST=${db_host}
DB_NAME=${db_name}
DB_SECRET_ARN=${db_secret_arn}
ASSETS_BUCKET=${bucket}
AWS_REGION=${region}
EOF
chmod 600 /etc/app.env

TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
IID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

# /health must return 200 or the ALB will keep cycling the instance.
mkdir -p /usr/share/nginx/html
echo "ok" >/usr/share/nginx/html/health

cat >/usr/share/nginx/html/index.html <<EOF
<!doctype html>
<html><head><meta charset="utf-8"><title>Three-Tier Demo</title>
<style>body{font-family:system-ui,sans-serif;margin:4rem auto;max-width:40rem;line-height:1.6}
code{background:#f4f4f5;padding:.15rem .35rem;border-radius:4px}</style></head>
<body>
<h1>Three-tier app is up</h1>
<p>Served by <code>$IID</code> in <code>$AZ</code></p>
<p>Database endpoint: <code>${db_host}</code></p>
<p>Assets bucket: <code>${bucket}</code></p>
</body></html>
EOF

# Serve /health without an extension and keep logs quiet for it.
cat >/etc/nginx/conf.d/app.conf <<'EOF'
server {
    listen 80 default_server;
    root /usr/share/nginx/html;

    location = /health {
        access_log off;
        default_type text/plain;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF
rm -f /etc/nginx/conf.d/default.conf

nginx -t
systemctl enable --now nginx

# Prove the DB path works end to end; failure here is logged, not fatal.
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "${db_secret_arn}" --region "${region}" \
  --query SecretString --output text 2>/var/log/db-check.log || true)

if [ -n "$${SECRET:-}" ]; then
  DB_USER=$(echo "$SECRET" | jq -r .username)
  DB_PASS=$(echo "$SECRET" | jq -r .password)
  mysql -h "${db_host}" -u "$DB_USER" -p"$DB_PASS" \
    -e "SELECT 1;" "${db_name}" >>/var/log/db-check.log 2>&1 || true
fi
