
# How to use docker backup/restore

```
git clone https://github.com/papagroup/papabash.git /root/papabash
```

# Install GDRIVE CLI while backup/restore 

## Create app & credentials

- Go to https://console.developers.google.com/apis/credentials
- Click "+ CREATE CREDENTIALS" > "OAuth client ID"
- Choose "Desktop application" in "Application type" > Click "Create"

## Install golang (to rebuild gdrive with new credentials)

+ option 1:
```sh
apt update && apt install -y golang-go
```

+ option 2:
```sh
cd /tmp
wget https://golang.org/dl/go1.15.linux-amd64.tar.gz
sudo tar -xvf go1.15.linux-amd64.tar.gz
sudo mv go /usr/local
export PATH=$PATH:/usr/local/go/bin
```

## Re-build gdrive with new credentials (OPTION 2)

- Clone git:gitlab.com/papagroup/gdrive.git
- Checkout another branch (e.g: prj_ABC)
- Change client id & secret and push
```sh
vi handlers_drive.go
#---
const ClientId = "xxxxxxxx"
const ClientSecret = "xxxxxxx"
```
- Run build command
```sh
env GIT_TERMINAL_PROMPT=1 go get gitlab.com/papagroup/gdrive
# ...enter username & password
# ...repo will be placed at ~/go/src/gdrive
```
- Go to `~/go/src/gdrive` to checkout to branch "prj_ABC" (<< this step is not tested yet)
- Run build command again (<< this step is not tested yet)
- OAuth & Check by running `gdrive list`

## Re-build gdrive with new credentials (OPTION 2)

- Clone
```sh
git clone https://github.com/prasmussen/gdrive.git
```
- Go to gdrive/ 
```sh
cd gdrive
```
- Edit handlers_drive.go
```sh
vi handlers_drive.go
#---
const ClientId = "367116221053-7n0v**.apps.googleusercontent.com"
const ClientSecret = "1qsNodXN*****jUjmvhoO"
```

- Prepare go env & package
```sh
# write to ~/.profile
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# Check
go version

# Check env
go env

# get package github.com/prasmussen/gdrive
go get github.com/prasmussen/gdrive
```

- Run build script
```
bash _release/build-all.sh
```

- Upload binary file `gdrive`
```
# Ubuntu
$ rsync -avzh _release/bin/gdrive-linux-x64 root@45.xx.255.xx:/usr/bin/gdrive
root@45.xx.255.xx:$ sudo chmod 700 /usr/bin/gdrive

# Centos
$ rsync -avzh _release/bin/gdrive-linux-arm64 root@45.xx.255.xx:/usr/sbin/gdrive
root@45.xx.255.xx:$ sudo chmod 700 /usr/sbin/gdrive
```

## Add crontab

Example:
```
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin

5 */5 * * * bash /root/papabash/docker-helpers/docker_backup.sh -y --container "longban_db_1" --name "danangkitchen.vn" --destination "/home/.db_backups" --volume-dir "/var/lib/postgresql/data" --retain-days 3 > /dev/null

7 */5 * * * bash /root/papabash/docker-helpers/docker_backup.sh -y --container "longban_web_1" --name "danangkitchen.vn" --destination "/home/.media_backups" --volume-dir "/app/media" --retain-days 2

```

<!-- bash /home/admin/papabash/docker-helpers/docker_backup.sh -y --container "securityalarm-webservices_db_1" --name "securityalarm-pg" --destination "/home/.db_backups" --volume-dir "/var/lib/postgresql/data" --retain-days 5 > /dev/null -->