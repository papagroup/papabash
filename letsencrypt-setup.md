# Generate LetsEncrypt SSL with Nginx webserver

- Generate dhparam pem file
```
openssl dhparam -out /etc/nginx/ssl/dhparam-2048.pem 2048
```

- Change root in nginx conf file:
```
	...
	include /etc/nginx/conf/ssl.conf;
	...
```

- Change `ssl_dhparam` & `root` config lines in nginx/conf/ssl.conf
```
ssl_dhparam /etc/nginx/ssl/dhparam-2048.pem;
...
location ^~ /.well-known/acme-challenge/ {
    default_type "text/plain";
    root /var/www/letsencrypt;
}
...
```

- Restart nginx
```
nginx -t && service nginx restart
```

- (Optional) Make well-known & acme directories:
```
mkdir -p /var/www/letsencrypt/.well-known/acme-challenge
```

- (Optional) Creating testing file:
```
echo 'Testing' > /var/www/letsencrypt/.well-known/acme-challenge/test.html
```

- (Optional) Then go to /.well-known/acme-challenge/test.html to see if the page works.
If got 403 (nginx), the permissions of the folder .well-known should be checked.

### Generate certificates

```
certbot certonly --rsa-key-size 4096 \
	--webroot \
	-w /var/www/letsencrypt/ \
	--work-dir /var/www/letsencrypt/ \
	--config-dir /etc/nginx/ssl/ \
	--logs-dir /var/log/letsencrypt/ \
	--agree-tos \
	--no-eff-email \
	--force-renew \
	--email papagroup.net@gmail.com \
	-d awesomesite.com \
	-d www.awesomesite.com \
	--debug \
	--dry-run
```

- Add nginx conf file for ssl
```
cp /etc/nginx/sites-available/awesomesite.conf /etc/nginx/sites-available/awesomesite-https.conf
```

- Replace/Change configuration in awesomesite-https.conf:
```
...
    listen 443 ssl http2;
    listen [::]:443;
    ...
    ssl_certificate /etc/nginx/ssl/live/awesomesite.com/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/live/awesomesite.com/privkey.pem;
    include /etc/nginx/conf/ssl.conf;
    ...
...
```

- Restart nginx
```
nginx -t && service nginx restart
```