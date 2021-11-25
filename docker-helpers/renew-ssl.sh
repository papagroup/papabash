#!/bin/sh

set -e

DOCKER=$(which docker)

SITE=$1
NOW=`date +"%Y-%m-%d %H:%M:%S"`
echo "[INFO] $NOW - Start renew ssl for '$SITE'..."

PROJECT_ROOT=$2
EMAIL=papagroup.net@gmail.com
if [ -z $3 ]; then
    EMAIL=$3
fi

echo "[INFO] Project root: '$PROJECT_ROOT'"
echo "[INFO] Email: '$EMAIL'"

if [ ! -z $SITE || ! -z $PROJECT_ROOT ];then
    echo ""
    echo "[ERROR] SITE & PROJECT_ROOT are required."
    echo "[INFO] Exit."
    echo ""
    exit 1
fi

$DOCKER run \
    -i --rm \
    -v $PROJECT_ROOT/certbot/certs/:/etc/nginx/certbot/certs \
    -v $PROJECT_ROOT/certbot/.well-known/acme-challenge:/etc/nginx/certbot/.well-known/acme-challenge \
    -v /var/log/letsencrypt:/var/log/letsencrypt \
    certbot/certbot certonly --webroot \
    -w /etc/nginx/certbot \
    --config-dir /etc/nginx/certbot/certs \
    --agree-tos \
    --no-eff-email \
    --force-renew \
    --email $EMAIL \
    -d $SITE \
    --debug
    --dry-run
#<-- add this option for testing (important!)

NOW=`date +"%Y-%m-%d %H:%M:%S"`
echo "[INFO] $NOW - Done renew ssl for '$SITE' ./."
echo ""

echo "[INFO] Usage# crontab:"
echo "[INFO] 11 20 1 * * bash `pwd`/renew-ssl.sh '$SITE' '$PROJECT_ROOT' >> /var/log/letsencrypt/$SITE.log"
echo ""
echo "[INFO] Done. Exit."
echo ""