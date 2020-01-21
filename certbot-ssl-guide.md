DOMAIN="defood.vn"
PAPABASH_ROOT="/home/root"

openssl dhparam -out /etc/nginx/ssl/dhparam-2048.pem 2048

cp $PAPABASH_ROOT/nginx/conf/* /etc/nginx/conf/

### Add below line to /etc/nginx/conf.d/${DOMAIN}.conf

include /etc/nginx/conf/ssl.conf;

### Restart nginx

nginx -t && service nginx restart

### Run certbot

certbot certonly --rsa-key-size 4096 \
	--webroot \
	-w /var/www/letsencrypt/ \
	--work-dir /var/www/letsencrypt/ \
	--config-dir /etc/nginx/ssl/ \
	--logs-dir /var/www/letsencrypt/logs/ \
	--agree-tos \
	--no-eff-email \
	--force-renew \
	--email papagroup.net@gmail.com \
	-d defood.vn \
	--debug \
	--dry-run

!!! Continue only after certbot run successfully (without --dry-run)

### Copy /etc/nginx/conf.d/${DOMAIN}.conf to /etc/nginx/conf.d/${DOMAIN}_https.conf

### Replace/Add these lines

    listen 443 ssl http2;
    listen [::]:443;
    ...
    ssl_certificate /etc/nginx/ssl/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/live/$DOMAIN/privkey.pem;
    include /etc/nginx/conf/ssl.conf;

### Restart nginx

nginx -t && service nginx restart