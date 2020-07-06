#!/usr/bin/env bash

set -e

# Some vars

export PROJECT_ROOT=/home/longban

export mediaFileGdriveId=195qX...SQ6
export mediaFile=/home/.media_backups/latest-media.tar.gz

export dbFileGdriveId=15n...vvSR
export dbFile=/home/.db_backups/latest-db.tar.gz

#export HOST=danangkitchen.papagroup.net
export HOST=admin.danangkitchen.vn

# # Install doctl
# # MacOS
# brew install doctl

# # Linux
# # Get latest version from https://github.com/digitalocean/doctl/releases
# cd ~
# wget https://github.com/digitalocean/doctl/releases/download/v<version>/doctl-<version>-linux-amd64.tar.gz
# tar xf ~/doctl-<version>-linux-amd64.tar.gz
# sudo mv ~/doctl /usr/local/bin

# # Init access token
# doctl auth init

# # List all Droplets on your account:
# doctl compute droplet list

# # List available region
# doctl compute region list

# # List ssh keys
# doctl compute ssh-key list

# # Create a Droplet:
# doctl compute droplet create <name> --region <region-slug> --image <image-slug> --size <size-slug>

# # SSH with root
# doctl compute ssh <droplet-name>

# # SSH with username
# doctl compute ssh username@<droplet-name>

## Using curl
# Go to https://cloud.digitalocean.com/account/api/tokens to get a Personal Access Token
export list_droplets="Unauthorized"

while [[ $list_droplets == *"Unauthorized"* ]]; do
    read -p "Enter your token [NULL]: " -s TOKEN
    TOKEN=${TOKEN:-NULL}

    echo ""

    # Get 1-click applications
    # curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" "https://api.digitalocean.com/v2/1-clicks"

    # Get list droplets
    list_droplets=$(curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" "https://api.digitalocean.com/v2/droplets?page=1&per_page=100" 2>&1)
    if [[ $list_droplets == *"Unauthorized"* ]]; then
        echo "Cannot authorize with that Token, please try again or Ctrl+C to quit."
    fi
    echo "..."
done

if [[ $list_droplets == *"Unauthorized"* ]]; then
    echo "Stop due to unauthorized."
    exit 0
fi

echo $list_droplets

# Retrieve a droplet by id
# curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" "https://api.digitalocean.com/v2/droplets/195161641"

# List droplets by tag
# curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" "https://api.digitalocean.com/v2/droplets?tag_name=dnkitchen" 

# List all regions
# curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" "https://api.digitalocean.com/v2/regions" 

# List all images
# curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" "https://api.digitalocean.com/v2/images?page=1&per_page=100" 

# List all SSH keys
# curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" "https://api.digitalocean.com/v2/account/keys" 

# Create a new droplet
create_droplet_res=$(curl -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
    -d '{"name":"dnkitchen.com.vn","region":"sgp1","size":"s-1vcpu-2gb","image":"docker-18-04","ssh_keys":[25333604,27610331,27610358],"backups":false,"ipv6":true,"user_data":null,"private_networking":null,"volumes": null,"tags":["web","python","django","saleor","channels","docker","dnkitchen"]}' \
    "https://api.digitalocean.com/v2/droplets")
# Get droplet_id
$create_droplet_res | grep "id"
export DROPLET_ID=198817502
echo $DROPLET_ID
# Check status
curl -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" "https://api.digitalocean.com/v2/droplets/$DROPLET_ID" 2>&1 | grep '"status":"active"'
# DROPLET_IP=$("ip_address":"206.189.154.162")
export DROPLET_IP=206.189.150.122


# SSH && Pull code

# Append ssh key of papagroup.net@gitlab.readonly
scp /Users/pii/.ssh/id_rsa_papagroup_gitlab_readonly root@$DROPLET_IP:~/.ssh/
scp /Users/pii/.ssh/id_rsa_papagroup_gitlab_readonly.pub root@$DROPLET_IP:~/.ssh/

ssh root@$DROPLET_IP

# Add to ssh agent
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa_papagroup_gitlab_readonly

# Check ssh connection to Gitlab
ssh -T git@gitlab.com

git clone git@gitlab.com:papagroup/longban-web-saleor.git /home/longban

# Get papabash
git clone --recurse-submodules https://github.com/papagroup/papabash.git /root/papabash
git submodule update --init --recursive
# Pull manually: git submodule update --remote

# Restore DB
# If have local backups...
# Or not, download from gdrive

# Install golang
apt update
apt install golang-go

# Install gdown
apt install -y python-pip
pip install gdown

# Get gdrive
wget "https://drive.google.com/uc?id=19Y364iDL7xnOWaKV0xIxibOdVJqFcHbo&export=download" -O /usr/bin/gdrive
chmod 700 /usr/bin/gdrive
gdrive list

# Get the latest db volume
mkdir -p /home/.db_backups

wget "https://drive.google.com/uc?id=$dbFileGdriveId&export=download" -O "$dbFile"
# Restore db
if file --mime-type "$dbFile" | grep -q gzip$; then
  echo "$dbFile is gzipped... Starting to restore database..."
  bash /root/papabash/docker-helpers/docker_backup.sh --destination "/home/.db_backups" --restore --container "longban_db_1" --volume-dir "/var/lib/postgresql/data"

  # !!! install slacktee
  # webhook_url=""
  # token="..."
  # tmp_dir="/tmp"
  # channel="devops-ntfs"
  # username="DevOpsNtf"
  # icon="ghost"
  # attachment=""
else
  echo "$dbFile is not gzipped. Please check again. Abort."
  exit 0
fi

# Get the latest media volume
mkdir -p /home/.media_backups

gdown "https://drive.google.com/uc?id=$mediaFileGdriveId" -O "$mediaFile"
# Restore media
if file --mime-type "$mediaFile" | grep -q gzip$; then
  echo "$mediaFile is gzipped... Starting to restore media..."
  bash /root/papabash/docker-helpers/docker_backup.sh --destination "/home/.media_backups" --restore --container "longban_web_1" --volume-dir "/app/media"
else
  echo "$mediaFile is not gzipped. Please check again. Abort."
  exit 0
fi

# Go to web root
cd /home/longban

# Init submodule dashboard_next
git submodule update --init --recursive

# (For test) Change domain (nginx)
# vi /home/longban/nginx/sites/
mv /home/longban/nginx/sites/danangkitchen-https.conf /home/longban/nginx/sites/danangkitchen-https.conf.bak
mv /home/longban/nginx/sites/longban.conf /home/longban/nginx/sites/longban.conf.bak
mv /home/longban/nginx/sites/longban-https.conf /home/longban/nginx/sites/longban-https.conf.bak
# Change ALLOWED_HOSTS
# vi saleor/settings.py

# Run web server
docker-compose -f /home/longban/docker-compose.yml up -d
bash /home/longban/scripts/update_production--docker.sh

# SSL
openssl dhparam -out /home/longban/nginx/ssl/dhparam-2048.pem 2048

docker restart longban_nginx_1 \
&& docker run -it --rm \
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
    -d $HOST \
    --debug \
&& docker exec -it longban_nginx_1 nginx -t
&& docker restart longban_nginx_1

# Check db connection

# Check redis connection

# Check API

# Check socket

# Change DNS Record to Cloudflare
