# Generate LetsEncrypt SSL with Nginx webserver

```
export SITE=example.com
export EMAIL=papagroup.net@gmail.com
export PROJECT_ROOT=/home/$USER/$SITE
```

- Mount nginx volumes
```
- $PROJECT_ROOT:/var/www
- $PROJECT_ROOT/nginx/nginx.conf:/etc/nginx/nginx.conf
- $PROJECT_ROOT/nginx/conf/gzip.conf:/etc/nginx/conf/gzip.conf
- $PROJECT_ROOT/nginx/conf/ssl.conf:/etc/nginx/conf/ssl.conf
- $PROJECT_ROOT/nginx/sites:/etc/nginx/sites-available
- $PROJECT_ROOT/certbot/dhparam-2048.pem:/var/certbot/dhparam-2048.pem
- $PROJECT_ROOT/certbot/certs/:/var/certbot/certs
- $PROJECT_ROOT/certbot/.well-known/acme-challenge:/var/certbot/.well-known/acme-challenge
```

- Generate dhparam pem file
```
openssl dhparam -out $PROJECT_ROOT/certbot/dhparam-2048.pem 2048
```

- Change root in dashboard nginx conf file ($PROJECT_ROOT/nginx/sites/$SITE.conf):
```
	...
	root /var/www/; # django, java, ...
	...
	include /etc/nginx/conf/ssl.conf;
	...
```

- Check `ssl_dhparam` & `root` config lines in nginx/conf/ssl.conf
```
ssl_dhparam /var/certbot/dhparam-2048.pem;
...
location ^~ /.well-known/acme-challenge/ {
    default_type "text/plain";
    root /var/certbot;
}
...
```

- Restart nginx
```
# Docker
docker restart $NGINX_CONTAINER_NAME
```

- (Optional) Creating testing file:
```
echo 'Testing' > $PROJECT_ROOT/certbot/.well-known/acme-challenge/test.html
```
- (Optional) Then go to /.well-known/acme-challenge/test.html to see if the page works.
If got 403 (nginx), the permissions of the folder .well-known should be checked.

### Generate certificates
#### Certbot in docker
```
docker run -it --rm \
    -v $PROJECT_ROOT/certbot/certs/:/var/certbot/certs \
    -v $PROJECT_ROOT/certbot/.well-known/acme-challenge:/var/certbot/.well-known/acme-challenge \
    certbot/certbot certonly --webroot \
    -w /var/certbot \
    --config-dir /var/certbot/certs \
    --agree-tos \
    --no-eff-email \
    --force-renew \
    --email $EMAIL \
    -d $SITE \
    --debug \
    --dry-run
```

E.g:
docker run -it --rm \
    -v $PROJECT_ROOT/certbot/certs/:/var/certbot/certs \
    -v $PROJECT_ROOT/certbot/.well-known/acme-challenge:/var/certbot/.well-known/acme-challenge \
    certbot/certbot certonly --webroot \
    -w /var/certbot \
    --config-dir /var/certbot/certs \
    --agree-tos \
    --no-eff-email \
    --force-renew \
    --email papagroup.net@gmail.com \
    -d mes.papagroup.net \
    --debug \
    --dry-run


- Add nginx conf file for ssl
```
cp $PROJECT_ROOT/home/$USER/$SITE/nginx/sites/$SITE.conf $PROJECT_ROOT/nginx/sites/$SITE-https.conf
```

- Replace/Change configuration:
```
...
    listen 443 ssl http2;
    listen [::]:443;
    ...
    ssl_certificate /var/certbot/certs/live/$SITE/fullchain.pem;
    ssl_certificate_key /var/certbot/certs/live/$SITE/privkey.pem;
    include /etc/nginx/conf/ssl.conf;
    ...
...
```

- Restart nginx ...
docker restart $NGINX_CONTAINER_NAME