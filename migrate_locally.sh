#!/bin/bash

# NB! UPDATE ONLY bash

# Read FROM DOMAIN
#if [ "$1" != "" ]; then
#    FROM_DOMAIN="${1//[^a-zA-Z0-9\.\-_]/}"
#else
#    read -p "Enter domain to clone FROM > " VAR_INPUT
#    FROM_DOMAIN="${VAR_INPUT//[^a-zA-Z0-9\.\-_]/}"
#fi

#if [ "$2" != "" ]; then
#    DOMAIN="${2//[^a-zA-Z0-9\.\-_]/}"
#else
#    read -p "Enter NEW domain > " VAR_INPUT
#    DOMAIN="${VAR_INPUT//[^a-zA-Z0-9\.\-_]/}"
#fi

#read -p "Enter source 'DBNAME' > " VAR_INPUT
#FROM_DBNAME="${VAR_INPUT//[^a-zA-Z0-9\.\-_]/}"

#read -p "Enter source 'DBPREFIX' > " VAR_INPUT
#FROM_DBPREFIX="${VAR_INPUT//[^a-zA-Z0-9\.\-_]/}"

#read -p "Enter source 'PUBLIC_HTML_DIR' > " VAR_INPUT
#FROM_PUBLIC_HTML_DIR="${VAR_INPUT//[^a-zA-Z0-9\.\-_]/}"

# To save time...
#***********************
FROM_DOMAIN=medimay.papagroup.net
#***********************
FROM_USERNAME=medimaypapag
FROM_PASSWORD=8rcgFp6gRgICUikK
FROM_HOMEDIR=/home/medimay.papagroup.net
FROM_PUBLIC_HTML_DIR=/home/medimay.papagroup.net/public_html
#***********************
FROM_DBNAME=medimaypapag_6UM01
FROM_DBUSER=medimaypapag_dUoq1
FROM_DBPASS=i1k57jXfqWPerdRE
FROM_DBPREFIX=medimaypapag_FlZDu_
#***********************
FROM_WP_ADMIN_USER=medimaypapag_E4kix
FROM_WP_ADMIN_PASS=gP28XHfYqUtbWLm3
FROM_WP_ADMIN_EMAIL=no-reply@papagroup.net
#***********************

#***********************
DOMAIN=medimay.vn
#***********************
USERNAME=medimayvn
PASSWORD=fpaHcNxFo1aBjzET
HOMEDIR=/home/medimay.vn
PUBLIC_HTML_DIR=/home/medimay.vn/public_html
#***********************
DBNAME=medimayvn_tqMGa
DBUSER=medimayvn_3VQEv
DBPASS=EJ2B0RbL2qg96dYJ
DBPREFIX=medimayvn_NMWHz_
#***********************
WP_ADMIN_USER=medimayvn_SozHZ
WP_ADMIN_PASS=Fa24FHPdmO6vd34X
WP_ADMIN_EMAIL=no-reply@papagroup.net
#***********************

NGINX_USERNAME="www-data"
ENV_ROOT="/root/.genwpsites"
ENV_DIR="$ENV_ROOT/$DOMAIN"
ENV_FILE="$ENV_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    echo "env file exists ($ENV_FILE). Reading variables..."
    source "$ENV_FILE"
else
    echo "Not found env file ($ENV_FILE). Please run add_new_wp_site.sh first."
    echo "Exiting..."
    exit 6
fi

echo "#***********************"
echo "FROM_DOMAIN=$FROM_DOMAIN"
echo "FROM_USERNAME=$FROM_USERNAME"
echo "FROM_DBNAME=$FROM_DBNAME"
echo "FROM_DBPREFIX=$FROM_DBPREFIX"
echo "FROM_PUBLIC_HTML_DIR=$FROM_PUBLIC_HTML_DIR"
echo "#***********************"
#echo "#Adding new wp site for"
echo "DOMAIN=$DOMAIN"
echo "#***********************"
#echo "#New user..."
echo "USERNAME=$USERNAME"
echo "PASSWORD=$PASSWORD"
echo "HOMEDIR=$HOMEDIR"
echo "PUBLIC_HTML_DIR=$PUBLIC_HTML_DIR"
echo "#***********************"
#echo "#New DB..."
echo "DBNAME=$DBNAME"
echo "DBUSER=$DBUSER"
echo "DBPASS=$DBPASS"
echo "DBPREFIX=$DBPREFIX"
echo "#***********************"
#echo "#New WP admin..."
echo "WP_ADMIN_USER=$WP_ADMIN_USER"
echo "WP_ADMIN_PASS=$WP_ADMIN_PASS"
echo "WP_ADMIN_EMAIL=$WP_ADMIN_EMAIL"
echo "#***********************"

read -p "Everything is correct? (y/N) > " VAR_INPUT
if [ "$VAR_INPUT" != "y" ]; then
    echo "See you."
    exit 1
fi

echo "#Start LOCAL MIGRATING..."

# Backup wp-config.php
mv ${PUBLIC_HTML_DIR}/wp-config.php ${PUBLIC_HTML_DIR}/wp-config.php.new
# Copy themes & plugins & uploads
# rsync -avh ${FROM_PUBLIC_HTML_DIR}/wp-content/themes ${PUBLIC_HTML_DIR}/wp-content/
# rsync -avh ${FROM_PUBLIC_HTML_DIR}/wp-content/plugins ${PUBLIC_HTML_DIR}/wp-content/
# rsync -avh ${FROM_PUBLIC_HTML_DIR}/wp-content/uploads ${PUBLIC_HTML_DIR}/wp-content/
rsync -avh ${FROM_PUBLIC_HTML_DIR}/* ${PUBLIC_HTML_DIR}/
# Restore wp-config.php
mv ${PUBLIC_HTML_DIR}/wp-config.php ${PUBLIC_HTML_DIR}/wp-config.php.old
mv ${PUBLIC_HTML_DIR}/wp-config.php.new ${PUBLIC_HTML_DIR}/wp-config.php

# Get db
echo "# Export database..."
# EXPORTED_DB_FILENAME="${FROM_DOMAIN}.latest.sql"
EXPORTED_DB_FILENAME="${FROM_DOMAIN}.$(date +\%Y-\%m-\%d).sql"
# ssh -p ${SSH_PORT} ${SSH_USER}@${SSH_HOST} sudo -u ${FROM_USERNAME} -i "mkdir -p ${FROM_PUBLIC_HTML_DIR}/backup_db/"
# make sure follow command allowed
sudo chown ${FROM_USERNAME} ${FROM_PUBLIC_HTML_DIR}
sudo chown ${USERNAME} ${PUBLIC_HTML_DIR}
sudo -u ${FROM_USERNAME} -i -- mkdir -p "${FROM_PUBLIC_HTML_DIR}/backup_db/"
sudo -u ${USERNAME} -i -- mkdir -p "${PUBLIC_HTML_DIR}/backup_db/origin_db/"

# ssh -p ${SSH_PORT} ${SSH_USER}@${SSH_HOST} "sudo -u ${FROM_USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${FROM_PUBLIC_HTML_DIR} db export '${FROM_PUBLIC_HTML_DIR}/backup_db/${EXPORTED_DB_FILENAME}'"
sudo -u ${FROM_USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${FROM_PUBLIC_HTML_DIR} db export "${FROM_PUBLIC_HTML_DIR}/backup_db/${EXPORTED_DB_FILENAME}"
echo "# Exported ${FROM_PUBLIC_HTML_DIR}/backup_db/${EXPORTED_DB_FILENAME} on host."

# Copy/Backup
echo "# Copy to ${PUBLIC_HTML_DIR}/backup_db/origin_db/${EXPORTED_DB_FILENAME} ..."
# rsync -avh -e "ssh -p ${SSH_PORT}" ${SSH_USER}@${SSH_HOST}:${FROM_PUBLIC_HTML_DIR}/backup_db/${EXPORTED_DB_FILENAME} "${PUBLIC_HTML_DIR}/backup_db/origin_db/"
rsync -avh ${FROM_PUBLIC_HTML_DIR}/backup_db/${EXPORTED_DB_FILENAME} "${PUBLIC_HTML_DIR}/backup_db/origin_db/"
# cp "${EXPORTED_DB}" "${EXPORTED_DB}.bak"
EXPORTED_DB_FILE="${PUBLIC_HTML_DIR}/backup_db/origin_db/${EXPORTED_DB_FILENAME}"

# echo "# Change database domain..."
# sed -i "s/$FROM_DOMAIN/$DOMAIN/g" ${EXPORTED_DB_FILE}
# sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} 
echo "# Change database prefix..."
sed -i "s/$FROM_DBPREFIX/$DBPREFIX/g" ${EXPORTED_DB_FILE}
# sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} search-replace "${FROM_DBPREFIX}" "${DBPREFIX}"
echo "# Clean old database (drop tables)..."
sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} db clean --yes
echo "# Import database..."
sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} db import ${EXPORTED_DB_FILE}
echo "# Change database domain..."
sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} search-replace "$FROM_DOMAIN" "$DOMAIN"

echo "# Fix permission..."
find $PUBLIC_HTML_DIR -type d -exec chmod 755 '{}' \;
find $PUBLIC_HTML_DIR -type f -exec chmod 644 '{}' \;
chown -R ${NGINX_USERNAME}:${NGINX_USERNAME} $PUBLIC_HTML_DIR
chown ${NGINX_USERNAME}:${NGINX_USERNAME} $PUBLIC_HTML_DIR/..

echo "# Flush..."
sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} rewrite flush

echo '# Checking nginx syntax...'
nginx -t
# Failed checking nginx -> exit
[ $? -eq 0 ] || exit 3
echo '# Restarting nginx...'
service nginx restart

echo "All done."
exit 0
