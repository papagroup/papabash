#!/bin/bash

# NB! UPDATE ONLY bash

# Read FROM DOMAIN
if [ "$1" != "" ]; then
    FROM_DOMAIN="${1//[^a-zA-Z0-9\.\-_]/}"
else
    read -p "Enter domain to clone FROM > " VAR_INPUT
    FROM_DOMAIN="${VAR_INPUT//[^a-zA-Z0-9\.\-_]/}"
fi

if [ ! -f "/etc/nginx/conf.d/$FROM_DOMAIN.conf" ]; then
    echo "Nginx conf file of $FROM_DOMAIN does NOT exists!"
    echo "Exiting..."
    exit 5
fi

if [ "$2" != "" ]; then
    DOMAIN="${2//[^a-zA-Z0-9\.\-_]/}"
else
    read -p "Enter NEW domain > " VAR_INPUT
    DOMAIN="${VAR_INPUT//[^a-zA-Z0-9\.\-_]/}"
fi

ENV_ROOT="/root/.genwpsites"

FROM_ENV_DIR="$ENV_ROOT/$FROM_DOMAIN"
FROM_ENV_FILE="$ENV_DIR/.env"

if [ -f "$FROM_ENV_FILE" ]; then
    echo "env file exists ($FROM_ENV_FILE). Reading variables..."
    source "$FROM_ENV_FILE"
    # Assign needed vars
    FROM_DBNAME="$DBNAME"
    FROM_DBPREFIX="$DBPREFIX"
    FROM_PUBLIC_HTML_DIR="$PUBLIC_HTML_DIR"
else
    echo "Not found env file ($FROM_ENV_FILE)."
    # exit 6
    read -p "Enter DATABASE NAME to clone from > " VAR_INPUT
    FROM_DBNAME="${VAR_INPUT//[^a-zA-Z0-9\.\-_]/}"

    read -p "Enter DATABASE PREFIX to clone from > " VAR_INPUT
    FROM_DBPREFIX="${VAR_INPUT//[^a-zA-Z0-9\.\-_]/}"
fi

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
echo "FROM_DBNAME=$FROM_DBNAME"
echo "FROM_DBPREFIX=$FROM_DBPREFIX"
echo "FROM_PUBLIC_HTML_DIR=$PUBLIC_HTML_DIR"
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

read -p "Everything is correct? (y/n) > " VAR_INPUT
if [ "$VAR_INPUT" != "y" ]; then
    echo "See you."
    exit 1
fi

echo "#Start MIGRATING..."

# Copy themes & plugins & uploads
# rsync -avh -e 'ssh -p 9033' root@45.32.60.198:/home/demo.papagroup.net/public_html/wp-content/themes ./wp-content/
rsync -avh "${FROM_PUBLIC_HTML_DIR}/wp-content/themes" "${PUBLIC_HTML_DIR}/wp-content/"
# rsync -avh -e 'ssh -p 9033' root@45.32.60.198:/home/demo.papagroup.net/public_html/wp-content/plugins ./wp-content/
rsync -avh "${FROM_PUBLIC_HTML_DIR}/wp-content/plugins" "${PUBLIC_HTML_DIR}/wp-content/"
# rsync -avh -e 'ssh -p 9033' root@45.32.60.198:/home/demo.papagroup.net/public_html/wp-content/uploads ./wp-content/
rsync -avh "${FROM_PUBLIC_HTML_DIR}/wp-content/uploads" "${PUBLIC_HTML_DIR}/wp-content/"

# Get db
# rsync -avh -e 'ssh -p 9033' root@45.32.60.198:/home/demo.papagroup.net/public_html/medimay.vn.20jan04.sql ./
echo "# Export database..."
# EXPORTED_DB_FILENAME="${FROM_DOMAIN}.latest.sql"
EXPORTED_DB_FILENAME="${FROM_DOMAIN}.$(date %Y-%m-%d).sql"
mkdir -p "${FROM_PUBLIC_HTML_DIR}/backup_db/"
mkdir -p "${PUBLIC_HTML_DIR}/backup_db/origin_db/"

sudo -u ${FROM_USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${FROM_PUBLIC_HTML_DIR} db export "${EXPORTED_DB_FILENAME}"
mv "${FROM_PUBLIC_HTML_DIR}/${EXPORTED_DB_FILENAME}" "${FROM_PUBLIC_HTML_DIR}/backup_db/"

# Copy/Backup
cp "${FROM_PUBLIC_HTML_DIR}/backup_db/${EXPORTED_DB_FILENAME}" "${PUBLIC_HTML_DIR}/backup_db/origin_db/"
# cp "${EXPORTED_DB}" "${EXPORTED_DB}.bak"
EXPORTED_DB_FILE="${PUBLIC_HTML_DIR}/backup_db/origin_db/${EXPORTED_DB_FILENAME}"

echo "# Change database prefix..."
sed -i "s/$FROM_DOMAIN/$DOMAIN/g" ${EXPORTED_DB_FILE}
# sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} 
# Change database domain
sed -i "s/$FROM_DBPREFIX/$DBPREFIX/g" ${EXPORTED_DB_FILE}
# sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} search-replace "${FROM_DBPREFIX}" "${DBPREFIX}"
# Import database
sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} db import ${EXPORTED_DB_FILE}
# Flush
sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} rewrite flush
# sed -i "s/demopapagrou_cwo93_/medimaypapag_FlZDu_/g" medimay.vn.20jan04.sql

echo "All done."
exit 0
