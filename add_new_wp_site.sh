#!/bin/bash

if [ "$1" != "" ]; then
    DOMAIN="${1//[^a-zA-Z0-9\.\-_]/}"
else
    read -p "Enter domain > " VAR_INPUT
    DOMAIN="${VAR_INPUT//[^a-zA-Z0-9\.\-_]/}"
fi


read -p "Enter domain to clone (nginx config) FROM (enter to skip) > " VAR_INPUT
FROM_DOMAIN="${VAR_INPUT//[^a-zA-Z0-9\.\-_]/}"

if [ -z $FROM_DOMAIN ]; then
    FROM_DOMAIN="default.tpl"
fi

#read -p "Enter username > " VAR_INPUT
#USERNAME="${VAR_INPUT//[^a-zA-Z0-9\-_]/}"

# Generate Username base on Domain
USERNAME="`echo "${DOMAIN//[^a-zA-Z0-9_]/}" | cut -c -12`"

ENV_ROOT="/root/.genwpsites"
ENV_DIR="$ENV_ROOT/$DOMAIN"
ENV_FILE="$ENV_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    echo "env file exists ($ENV_FILE). Reading variables..."
    source "$ENV_FILE"
else
    echo "Generating variables..."

    PASSWORD=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c16)
    HOMEDIR="/home/$DOMAIN"
    PUBLIC_HTML_DIR="$HOMEDIR/public_html"
    DBPASS=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c16)
    DBNAME="$USERNAME"'_'"$(< /dev/urandom tr -dc A-Za-z0-9 | head -c5)"
    DBUSER="$USERNAME"'_'"$(< /dev/urandom tr -dc A-Za-z0-9 | head -c5)"
    DBPREFIX="$USERNAME"'_'"$(< /dev/urandom tr -dc A-Za-z0-9 | head -c5)_"

    WP_ADMIN_USER="$USERNAME"'_'"$(< /dev/urandom tr -dc A-Za-z0-9 | head -c5)"
    WP_ADMIN_PASS="$(< /dev/urandom tr -dc A-Za-z0-9 | head -c16)"
    WP_ADMIN_EMAIL="no-reply@papagroup.net"

    # Write to env file
    mkdir -p "$ENV_DIR"
    echo "USERNAME=$USERNAME" > ${ENV_FILE}
    echo "PASSWORD=$PASSWORD" >> ${ENV_FILE}
    echo "HOMEDIR=$HOMEDIR" >> ${ENV_FILE}
    echo "PUBLIC_HTML_DIR=$PUBLIC_HTML_DIR" >> ${ENV_FILE}
    echo "DBNAME=$DBNAME" >> ${ENV_FILE}
    echo "DBUSER=$DBUSER" >> ${ENV_FILE}
    echo "DBPASS=$DBPASS" >> ${ENV_FILE}
    echo "DBPREFIX=$DBPREFIX" >> ${ENV_FILE}
    echo "WP_ADMIN_USER=$WP_ADMIN_USER" >> ${ENV_FILE}
    echo "WP_ADMIN_PASS=$WP_ADMIN_PASS" >> ${ENV_FILE}
    echo "WP_ADMIN_EMAIL=$WP_ADMIN_EMAIL" >> ${ENV_FILE}
fi

# Check template nginx conf
if [ ! -f "/etc/nginx/conf.d/$FROM_DOMAIN.conf" ]; then
    echo "Nginx conf file of $FROM_DOMAIN does NOT exists!"
    echo "Exiting..."
    exit 5
fi

if id "$USERNAME" >/dev/null 2>&1; then
    echo "User exists. Please check again or use 'userdel <$USERNAME>' to delete the user first."

    read -p "Still continue? (y/n) > " VAR_INPUT
    if [ "$VAR_INPUT" != "y" ]; then
        echo "Exiting..."
        exit 2
    fi
else
    echo "Creating user $USERNAME..."
    # 1.1. create user & home directory
    #adduser $USERNAME
    #1.2. set password
    #passwd $USERNAME -p $PASSWORD
    #1.3. add to wheel (sudo) group
    #usermod -aG wheel $USERNAME
    #1.4. change home directory
    #usermod -d $HOMEDIR $USERNAME

    #1.1 + 1.2 + 1.3 + 1.4
    useradd $USERNAME -p $PASSWORD -m -d $HOMEDIR
    # -G wheel
fi

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
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo "#Starting..."

# Check dirs
if [ ! -d "$PUBLIC_HTML_DIR" ]; then
    mkdir -p "$PUBLIC_HTML_DIR"
fi

if [ ! -d "$HOMEDIR/.ssh" ]; then
    mkdir -p "$HOMEDIR/.ssh"
fi

[ -f "$HOMEDIR/.ssh/authorized_keys" ] || touch "$HOMEDIR/.ssh/authorized_keys"

chmod 700 "$HOMEDIR/.ssh/authorized_keys"
chown -R ${USERNAME}:nginx "$HOMEDIR"
#chown -R nginx:nginx "$HOMEDIR"
ls -al "$HOMEDIR"

# Make sure these things to make SSH works
# 1. authorized_keys file & Folders modes
# drw------- root:root .
# drwxr-xr-x root:root ..
# drwx------ root:root .ssh
# -rw------- root:root .ssh/authorized_keys

# 2. Included ssh key into .ssh/authorized_keys

#--------------------------------------------------------------------
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#--------------------------------------------------------------------

# mysql

# MySQL> CREATE DATABASE IF NOT EXISTS `dbname`;
# MySQL> SHOW DATABASES;

# MySQL> CREATE USER 'user'@'hostname' IDENTIFIED BY 'password';
# MySQL> GRANT ALL PRIVILEGES ON dbname.* To 'user'@'hostname';
# mysql> FLUSH PRIVILEGES;
# MySQL> SELECT User FROM mysql.user;

mysql -e "CREATE DATABASE IF NOT EXISTS ${DBNAME};"
mysql -e "SHOW DATABASES;"
mysql -e "CREATE USER IF NOT EXISTS '${DBUSER}'@'localhost' IDENTIFIED BY '${DBPASS}'"
mysql -e "GRANT ALL PRIVILEGES ON ${DBNAME}.* To '${DBUSER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"
mysql -e "SELECT User FROM mysql.user;"

#nginx
[ -f "$PUBLIC_HTML_DIR/nginx.conf" ] || touch "$PUBLIC_HTML_DIR/nginx.conf"

if [ -f "/etc/nginx/conf.d/$DOMAIN.conf" ]; then
    echo "Nginx conf file exists."
else
    echo "Copying nginx conf..."
    cp /etc/nginx/conf.d/$FROM_DOMAIN.conf "/etc/nginx/conf.d/$DOMAIN.conf"
    # Replace to new domain
    sed -i "s/$FROM_DOMAIN/$DOMAIN/" /etc/nginx/conf.d/${DOMAIN}.conf

    # HTTPS...
    if [ -f "/etc/nginx/conf.d/${FROM_DOMAIN}_https.conf.sample" ]; then
        echo "Copying nginx https conf..."
        cp "/etc/nginx/conf.d/${FROM_DOMAIN}_https.conf.sample" "/etc/nginx/conf.d/${DOMAIN}_https.conf.sample"
        # Replace to new domain
        sed -i "s/$FROM_DOMAIN/$DOMAIN/" /etc/nginx/conf.d/${DOMAIN}_https.conf.sample
    fi

    echo 'Checking nginx syntax...'
    nginx -t

    # Failed checking nginx -> exit
    [ $? -eq 0 ] || exit 3

    echo 'Restarting nginx...'
    service nginx restart
fi

#WP:
cd "$PUBLIC_HTML_DIR"
pwd

echo "# Downloading core wp..."
sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} core download
echo "# Config core wp..."
sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} core config --dbname=$DBNAME --dbuser=$DBUSER --dbpass=$DBPASS --dbhost=localhost --dbprefix=$DBPREFIX
echo "# Creating db..."
sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} db create
echo "# Installing wp core..."
sudo -u ${USERNAME} -i -- php -d memory_limit=-1 /usr/local/bin/wp --path=${PUBLIC_HTML_DIR} core install --url=http://$DOMAIN --title=$DOMAIN --admin_user=$WP_ADMIN_USER --admin_password=$WP_ADMIN_PASS --admin_email=$WP_ADMIN_EMAIL

# Fix permission
find $PUBLIC_HTML_DIR -type d -exec chmod 755 '{}' \;
find $PUBLIC_HTML_DIR -type f -exec chmod 644 '{}' \;
chown -R nginx:nginx $PUBLIC_HTML_DIR
chown nginx:nginx $PUBLIC_HTML_DIR/..

echo "All done."
exit 0
