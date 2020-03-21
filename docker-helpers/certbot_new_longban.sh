#!/bin/bash

set -e

docker run -it --rm \
    -v /home/longban/nginx/ssl/:/etc/nginx/ssl/ \
    -v /home/longban/certbot/certs/:/var/certs/ \
    -v /home/longban/certbot/letsencrypt/.well-known/acme-challenge/:/var/www/letsencrypt/.well-known/acme-challenge/ \
    certbot/certbot certonly --webroot \
    -w /var/www/letsencrypt \
    --config-dir /etc/nginx/ssl \
    --agree-tos \
    --no-eff-email \
    --force-renew \
    --email papagroup.net@gmail.com \
    -d admin.danangkitchen.vn \
    --debug \
    --dry-run