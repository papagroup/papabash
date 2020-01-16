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
FROM_DOMAIN="defood.papagroup.net"
FROM_USERNAME="defoodpapagr"
FROM_DBNAME="defoodpapagr_29zpW"
FROM_DBPREFIX="defoodpapagr_fY3h9_"
FROM_PUBLIC_HTML_DIR="/home/defood.papagroup.net/public_html"

SSH_PORT=9033
SSH_USER="root"
SSH_HOST="45.32.60.198"

DOMAIN="defood.vn"

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

read -p "Everything is correct? (y/N) > " VAR_INPUT
if [ "$VAR_INPUT" != "y" ]; then
    echo "See you."
    exit 1
fi

echo "#Start REMOTE MIGRATING..."

# Copy themes & plugins & uploads
rsync -avh -e "ssh -p ${SSH_PORT}" ${SSH_USER}@${SSH_HOST}:${FROM_PUBLIC_HTML_DIR}/wp-content/themes ${PUBLIC_HTML_DIR}/wp-content/
#rsync -avh "${FROM_PUBLIC_HTML_DIR}/wp-content/themes" "${PUBLIC_HTML_DIR}/wp-content/"
rsync -avh -e "ssh -p ${SSH_PORT}" ${SSH_USER}@${SSH_HOST}:${FROM_PUBLIC_HTML_DIR}/wp-content/plugins ${PUBLIC_HTML_DIR}/wp-content/
#rsync -avh "${FROM_PUBLIC_HTML_DIR}/wp-content/plugins" "${PUBLIC_HTML_DIR}/wp-content/"
rsync -avh -e "ssh -p ${SSH_PORT}" ${SSH_USER}@${SSH_HOST}:${FROM_PUBLIC_HTML_DIR}/wp-content/uploads ${PUBLIC_HTML_DIR}/wp-content/
#rsync -avh "${FROM_PUBLIC_HTML_DIR}/wp-content/uploads" "${PUBLIC_HTML_DIR}/wp-content/"

# Get db
echo "# Export database..."
# EXPORTED_DB_FILENAME="${FROM_DOMAIN}.latest.sql"
EXPORTED_DB_FILENAME="${FROM_DOMAIN}.$(date +\%Y-\%m-\%d).sql"
ssh -p ${SSH_PORT} ${SSH_USER}@${SSH_HOST} sudo -u ${FROM_USERNAME} -i "mkdir -p ${FROM_PUBLIC_HTML_DIR}/backup_db/"
#mkdir -p "${FROM_PUBLIC_HTML_DIR}/backup_db/"
mkdir -p "${PUBLIC_HTML_DIR}/backup_db/origin_db/"

ssh -p ${SSH_PORT} ${SSH_USER}@${SSH_HOST} "sudo -u ${FROM_USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${FROM_PUBLIC_HTML_DIR} db export '${FROM_PUBLIC_HTML_DIR}/backup_db/${EXPORTED_DB_FILENAME}'"
#sudo -u ${FROM_USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${FROM_PUBLIC_HTML_DIR} db export "${EXPORTED_DB_FILENAME}"
#mv "${FROM_PUBLIC_HTML_DIR}/${EXPORTED_DB_FILENAME}" "${FROM_PUBLIC_HTML_DIR}/backup_db/"
echo "# Exported ${FROM_PUBLIC_HTML_DIR}/backup_db/${EXPORTED_DB_FILENAME} on host."

# Copy/Backup
echo "# Copy to ${PUBLIC_HTML_DIR}/backup_db/origin_db/${EXPORTED_DB_FILENAME} ..."
rsync -avh -e "ssh -p ${SSH_PORT}" ${SSH_USER}@${SSH_HOST}:${FROM_PUBLIC_HTML_DIR}/backup_db/${EXPORTED_DB_FILENAME} "${PUBLIC_HTML_DIR}/backup_db/origin_db/"
#cp "${FROM_PUBLIC_HTML_DIR}/backup_db/${EXPORTED_DB_FILENAME}" "${PUBLIC_HTML_DIR}/backup_db/origin_db/"
# cp "${EXPORTED_DB}" "${EXPORTED_DB}.bak"
EXPORTED_DB_FILE="${PUBLIC_HTML_DIR}/backup_db/origin_db/${EXPORTED_DB_FILENAME}"

echo "# Change database prefix..."
sed -i "s/$FROM_DOMAIN/$DOMAIN/g" ${EXPORTED_DB_FILE}
# sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} 
echo "# Change database domain..."
sed -i "s/$FROM_DBPREFIX/$DBPREFIX/g" ${EXPORTED_DB_FILE}
# sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} search-replace "${FROM_DBPREFIX}" "${DBPREFIX}"
echo "# Import database..."
sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} db import ${EXPORTED_DB_FILE}
echo "# Flush..."
sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} rewrite flush
# sed -i "s/demopapagrou_cwo93_/medimaypapag_FlZDu_/g" medimay.vn.20jan04.sql

echo "All done."
exit 0
