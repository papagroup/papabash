# How to use docker backup/restore

```
git clone https://github.com/papagroup/papabash.git /root/papabash
```

# Install GDRIVE CLI while backup/restore 

## Create app & credentials

- Go to https://console.developers.google.com/apis/credentials
- Click "+ CREATE CREDENTIALS" > "OAuth client ID"
- Choose "Desktop application" in "Application type" > Click "Create"

## Re-build gdrive with new credentials

- Clone 
- Go to gdrive/ 
- Edit handlers_drive.go
```
const ClientId = "367116221053-7n0v**.apps.googleusercontent.com"
const ClientSecret = "1qsNodXN*****jUjmvhoO"
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