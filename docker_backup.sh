#!/usr/bin/env bash

# https://github.com/papagroup/papabash
# ------------------------------------------------------------
# Copyright 2019 Papagroup Co., Ltd.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ------------------------------------------------------------
# USAGE (in crontab):
# 
# PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin
# MAILTO="nhan.huynhvan@papagroup.net"
#
# 27 17 * * * bash /var/www/papabash/docker_backup.sh -y --container "db_container_1" --name "site.com" --destination "/var/www/db_backups" --volume-dir "/var/lib/mysql" --retain-days 7 > /dev/null
# 
# 31 17 * * * bash /var/www/papabash/docker_backup.sh -y --container "web_container_1" --name "site.com" --destination "/var/www/backups" --volume-dir "/var/www/site.com" --retain-days 2 > /dev/null
# -----------------------------------------------------------



# Halt the script on any errors.
set -e

# ----------
# Default Configuration
# ----------
LOCAL_BACKUP_DESTINATION="/where/to/save/backup/files"  # Local path for backups
GDRIVE_ROOT_FOLDER="Papa-Backups"                          # Remote destination root on gdrive
# EMAIL="nhan.huynhvan@papagroup.net"                   # Email ID for Backup Status Notification

# ----------
# Default Configuration for backup Docker Volume
# ----------
D_CONTAINER_NAME="container_to_backup"          # Container contains data to backup
D_NAME="sub_volume_name"                        # Specific (sub) name in case many sites using same volume
D_VOLUME_PATH="/path/inside/volume"             # Where to get data to backup/restore inside the volume
# Create array of sites based on folder names
# D_SITE_LIST=($(
#     cd $D_VOLUME_PATH
#     echo $PWD | rev | cut -d '/' -f 1 | rev
# ))
# D_RESTORE_VOLUME_TMP_NAME="m_temp_volume"       # 
IS_RESTORE=0                                    # 0 - Backup. 1 - Restore
HAS_INTERNET=1                                  # 1 - Assume always has internet connection
NO_OUTPUT=0                                     # 0 - Output to console. 1 - No output
FORCE_CHECK_REMOVE_EXPIRED_LOCAL_BACKUP=0       # 1 - force check and remove local backup without asking
FORCE_CHECK_REMOVE_EXPIRED_GDRIVE_BACKUP=0      # 1 - force check and remove gdrive backup without asking

# ----------
# Initialization
# ----------
me=$(basename "$0")
TODAY=$(date +"%Y-%m-%d_%H")                                # Today date
RESTORE_DATE=$TODAY                                         # Default restore date is today
RETAIN_DAYS=2                                               # Days to backups you would like to keep
EXPIRED_DATE=$(date +"%Y-%m-%d" -d "-$RETAIN_DAYS days")'*' # Expired file determined by calculated date := today - retain_days

LOG_FILE="/tmp/papa_backup_log"

# A list of folder names and files to exclude. There's no point backing up
# massive folders such as node_modules, plus you'll likely end up getting max
# file path copy errors because npm nests directories so deep it breaks Windows.
exclude_paths=(
  "*.zip"
  "*.gz"
  "*.bzip2"
  "*.tar"
  "backup-temp"
  "cache"
  ".dep"
  "*.bak*"
  ".asset-cache"
  ".bundle"
  ".jekyll-cache"
  ".tweet-cache"
  ".vagrant"
  "_site"
  "node_modules"
  "vendor"
  "tmp"
  "temp"
  "resources/assets"
  ".git*"
  ".babelrc"
  ".editorconfig"
  ".env.example"
  "bitbucket-pipelines.yml"
  "release"
  ".DS_Store"
  "logs"
  "backups"
)

# rsync allows you to exclude certain paths. We're just looping over all of the
# excluded items and build up separate --exclude flags for each one.
for item in "${exclude_paths[@]}"
do
  exclude_flags="${exclude_flags} --exclude=${item}"
done

# ---------
# Utility Functions
# ---------
#For Cleanup
CLEAN=$(which rm)
function escape_string() {
	local result=$(echo "$1" |
		sed 's/\\/\\\\/g' |
		sed 's/"/\\"/g' |
		sed "s/'/\\'/g")
	echo "$result"
}
function err_exit() {
	exit_code=$1
	shift
	echo "$me: $@" >/dev/null >&2
	exit $exit_code
}
function err_return() {
	exit_code=$1
	shift
	echo "$me: $@" >/dev/null >&2
	return $exit_code
}
function __log() {
    echo "$1" 2>&1 | tee -a "$LOG_FILE"
}
# function cleanup() {
# 	[[ -f $filename ]] && rm "$filename"
# }
function show_help() {
	cat <<EOF
Usage: $me [options]

options:
    -h, --help                        Show this help.
    --restore                         Restore instead of backup.
    -q, --no-output                   Don't echo the input.
    -y, --yes-for-all                 Answer 'yes' for all promp questions.
    --config config_file              Specify the location of the config file.
    --setup                           Setup interactively.
EOF
}

# ----------
# Parse command line options related to docker
# ----------
function parse_docker_args() {
    while [[ $# -gt 0 ]]; do
        opt="$1"
        shift

        case "$opt" in
        --container )
            D_CONTAINER_NAME=$1
            shift
            ;;
        --volume-dir )
            D_VOLUME_PATH=$1
            shift
            ;;
        --destination )
            LOCAL_BACKUP_DESTINATION=$1
            shift
            ;;
        --name )
            D_NAME=$1
            shift
            ;;
        *)
            err_return 0 "illegal option $opt"
            ;;
        esac
    done
}

# ----------
# Parse command line options
# ----------
function parse_args() {

	while [[ $# -gt 0 ]]; do
		opt="$1"
		shift

		case "$opt" in
		-h | \? | --help )
			show_help
			exit 0
			;;
		--restore )
			IS_RESTORE=1
			;;
        --rollback-days )
            RESTORE_DATE=$(date +"%Y-%m-%d" -d "-$1 days")
            shift
            ;;
        --container )
            D_CONTAINER_NAME=$1
            shift
            ;;
        --volume-dir )
            D_VOLUME_PATH=$1
            shift
            ;;
        --destination )
            LOCAL_BACKUP_DESTINATION=$1
            shift
            ;;
        --name )
            D_NAME=$1
            shift
            ;;
        --retain-days )
            RETAIN_DAYS=$1                                              # Days to backups you would like to keep
            EXPIRED_DATE=$(date +"%Y-%m-%d" -d "-$RETAIN_DAYS days")'*' # Expired file determined by calculated date := today - retain_days
            shift
            ;;
		-q | --no-output )
			NO_OUTPUT=1
			;;
		-y | --yes-for-all )
			YES_FOR_ALL=1
			;;
		--f-remove-expired )
			FORCE_CHECK_REMOVE_EXPIRED_LOCAL_BACKUP=1
			FORCE_CHECK_REMOVE_EXPIRED_GDRIVE_BACKUP=1
			;;
		--config )
			CUSTOM_CONFIG=$1
			shift
			;;
		--setup )
			setup
			exit 1
			;;
		* )
			err_exit 1 "illegal option $opt"
			show_help
			;;
		esac
	done
}

# ---------
# Backup docker volume
# ---------
# creates a new container
# remove the container once it stops
# mounts all the volumes from container $CONTAINER_NAME also to this temporary container
# bind mount of the ~/backup/ directory from your host to the /backup directory inside the temporary container.
# specifies that the container should run an Ubuntu image
# backs up the contents of your website as a tarball inside /backup/ inside the container
# ---------
function backup_docker_volume() {

    __log "==============================================
Starting backup docker volume...
Target container      : $D_CONTAINER_NAME
Volume path           : $D_VOLUME_PATH
Backup path           : $LOCAL_BACKUP_DESTINATION
Backup file           : $D_CONTAINER_NAME.$D_NAME.$TODAY.tar.gz"

    FILE_TO_BACKUP="$LOCAL_BACKUP_DESTINATION/$D_CONTAINER_NAME.$D_NAME.$TODAY.tar.gz"

	if [ -f "$FILE_TO_BACKUP" ]; then
        __log "Backup file size      : $(stat -c%s $FILE_TO_BACKUP | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1000 ){ $1/=1000; s++ } printf "%.2f %s", $1, v[s] }')"
    fi

    FILE_TO_REMOVE="$LOCAL_BACKUP_DESTINATION/$D_CONTAINER_NAME.$D_NAME.$EXPIRED_DATE.tar.gz"
	if [ -f "$FILE_TO_REMOVE" ]; then
        __log "Backup file to delete : $FILE_TO_REMOVE ($(stat -c%s $FILE_TO_REMOVE | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1000 ){ $1/=1000; s++ } printf "%.2f %s", $1, v[s] }'))"
        __log "----------------------------------------------"
	else
        __log "Backup file to delete : $FILE_TO_REMOVE (Not found)"
        __log "----------------------------------------------"
	fi

    # Check if container exists
    [[ ! "$(docker ps | grep -w $D_CONTAINER_NAME)" ]] && err_exit 3 "Container $D_CONTAINER_NAME does not exist. Abort." # Abort
    # Check if container started
    [[ "$(docker ps -aq -f status=exited -f name=$D_CONTAINER_NAME)" ]] && err_exit 4 "Container $D_CONTAINER_NAME is exited. Abort." # Abort

    # Make sure the backup folder exists
    [[ ! -e "$LOCAL_BACKUP_DESTINATION" ]] && mkdir -p "$LOCAL_BACKUP_DESTINATION"

    WRITE_ON=0
    if [[ ! -e "$FILE_TO_BACKUP" ]]; then
		# NOT Exists -> Write new one
        WRITE_ON=1
    else
		# Exists -> Ask to overwrite
        echo "$FILE_TO_BACKUP exists."
        if [[ $YES_FOR_ALL = 1 ]]; then
            # All yes -> overwrite
            WRITE_ON=1
        else
            read -p "Are you sure to overwrite it? [y/N] :" choice
            case "$choice" in
            y | Y)
                # Overwrite
                WRITE_ON=1
                ;;
            *)
                # Continue
                # err_exit 0 "Aborting" # Abort
                ;;
            esac
        fi
    fi

    if [[ $WRITE_ON = 1 ]]; then
		docker run \
			--rm \
			--volumes-from "$D_CONTAINER_NAME" \
			-v "$LOCAL_BACKUP_DESTINATION":/backup ubuntu bash \
			-c "tar -czvf /backup/$D_CONTAINER_NAME.$D_NAME.$TODAY.tar.gz $exclude_flags -C $D_VOLUME_PATH ."

        echo "Done backup $D_CONTAINER_NAME locally."
        echo " "
    fi

    # Remove old backup file IF BACKUP FILE DONE SUCCESSFULLY
    if [[ -e "$FILE_TO_BACKUP" ]]; then
        
        FORCE_CHECK_REMOVE_EXPIRED_LOCAL_BACKUP=1

        send_backup_to_gdrive

    fi
    #  ..or force remove
    echo "[Debug] FORCE_CHECK_REMOVE_EXPIRED_LOCAL_BACKUP=$FORCE_CHECK_REMOVE_EXPIRED_LOCAL_BACKUP"
    [[ $FORCE_CHECK_REMOVE_EXPIRED_LOCAL_BACKUP = 1 ]] && local_delete_expired_backup
}

# ---------
# Restore docker volume
# ---------
function get_backup_file_from_drive() {

    GFILE_TO_RESTORE="$D_CONTAINER_NAME.$D_NAME.$RESTORE_DATE.tar.gz"
    GDRIVE_FILE_ID=$(gdrive list --no-header --name-width 0 --query "name = '$GFILE_TO_RESTORE'" --max 1 | awk '{ print $1 }')
    echo "[Gdrive][Debug] File to restore ID=$GDRIVE_FILE_ID"
    if [[ ! -z "$GDRIVE_FILE_ID" ]]; then
        __log "[Gdrive] Found backup ($GDRIVE_FILE_ID) to restore."
        echo "[Gdrive] Downloading..."
        GDRIVE_RESPONSE=$(gdrive download --path /tmp/ $GDRIVE_FILE_ID)
        __log "$GDRIVE_RESPONSE"
    else
        __log "[Gdrive] Not found file to restore ($GFILE_TO_RESTORE)"
    fi
}

# ---------
# Restore docker volume
# ---------
function restore_docker_volume() {

    __log "==================================================="
    __log "Restoring backup..."
    __log "Restore to container  : $D_CONTAINER_NAME"

    FILE_TO_RESTORE="$LOCAL_BACKUP_DESTINATION/$D_CONTAINER_NAME.$D_NAME.$RESTORE_DATE.tar.gz"

    # Local file not found => Try to download from gdrive first
    [ ! -f "$FILE_TO_RESTORE" ] && __log "Not found $FILE_TO_RESTORE..." && get_backup_file_from_drive
    [ ! -f "$FILE_TO_RESTORE" ] && FILE_TO_RESTORE="/tmp/$D_CONTAINER_NAME.$D_NAME.$RESTORE_DATE.tar.gz"

    # Check if backup file ready
    if [ -f "$FILE_TO_RESTORE" ]; then
        __log "Restore from file     : $FILE_TO_RESTORE ($(stat -c%s $FILE_TO_RESTORE | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1000 ){ $1/=1000; s++ } printf "%.2f %s", $1, v[s] }'))"
        __log "-----------------------"

        # Check if container exists & running
        CONTAINER_EXIST=$(docker ps --filter status=running | grep -w "$D_CONTAINER_NAME" | awk '{ print $1 }')
        if [ -z $CONTAINER_EXIST ]; then
            # Not exists => return
            __log "Container to restore ($D_CONTAINER_NAME) not exists or not running. Abort."
            return 0
        fi

        # Check if old volume still there
        # VOLUME_EXIST=$(docker volume ls | grep -w "$D_VOLUME_TO_RESTORE" | awk '{ print $1 }')
        # if [ ! -z $VOLUME_EXIST ]; then
        #     # Not exists => return
        #     _log "Volume to restore ($D_VOLUME_TO_RESTORE) not exists. Abort."
        #     return 0
        # fi
        # if [ -z $VOLUME_EXIST ]; then
        #     D_RESTORE_VOLUME_TMP_NAME="$D_VOLUME_TO_RESTORE"
        # else
        #     TMP_VOLUME_EXIST=$(docker volume ls | grep -w "$D_VOLUME_TO_RESTORE" | awk '{ print $1 }')
        #     echo "[Debug] TMP_VOLUME_EXIST=$TMP_VOLUME_EXIST"
        #     if [ -z $TMP_VOLUME_EXIST ]; then
        #         echo "Volume '$D_RESTORE_VOLUME_TMP_NAME' exists."
        #         docker volume rm "$TMP_VOLUME_EXIST"
        #         echo "=> Deleted volume."
        #     fi
        #     # Creates a new temporary volume
        #     docker volume create "$D_RESTORE_VOLUME_TMP_NAME"
        #     echo "[Debug] New volume '$D_RESTORE_VOLUME_TMP_NAME' created."
        # fi

        # Copy the data volume tar.gz file from your team's AWS S3 bucket.
        # if [ ! -f db/db-data-volume.tar.gz ]; then aws s3 cp \
        #     s3://{your-bucket}/mysql-data-volume/db-data-volume.tar.gz db-data-volume.tar.gz;
        # fi
        # Stop the database container to prevent read/writes during the database
        echo "[Debug] Stopping container '$D_CONTAINER_NAME'..."
        docker stop "$D_CONTAINER_NAME"

        # Remove the /var/lib/mysql contents from the database container.
        echo "[Debug] Removing container '$D_CONTAINER_NAME''s data at '$D_VOLUME_PATH/*'..."
        docker run --rm --volumes-from "$D_CONTAINER_NAME" alpine:3.3 bin/sh -c "rm -rf $D_VOLUME_PATH/*"

        # Use the ubuntu image with the `restore` command to extract
        # the tar.gz file contents into $D_VOLUME_PATH in the $D_CONTAINER_NAME.
        echo "[Debug] Unzip data to '$D_VOLUME_PATH' inside container '$D_CONTAINER_NAME'..."
        docker run --rm --interactive --volumes-from "$D_CONTAINER_NAME" \
            ubuntu bash -c "tar -xzvf - -C $D_VOLUME_PATH" < $FILE_TO_RESTORE

        echo "[Debug] Start container '$D_CONTAINER_NAME'..."
        docker restart "$D_CONTAINER_NAME"

        __log "Done restore data in '$D_VOLUME_PATH' inside container '$D_CONTAINER_NAME' and restarted container."

    else
        __log "Not found backup file to restore ($FILE_TO_RESTORE)"
    fi

}

function setup() {
	if [[ -z "$HOME" ]]; then
		err_exit 1 "\$HOME is not defined. Please set it first."
	fi

    # Check Gdrive
    file="/usr/bin/gdrive"
    if [[ ! -f "$file" ]]; then
    # if [[ -z $(command -v gdrive) ]]; then

        echo "Download And Install Gdrive..."
        if [ $(getconf LONG_BIT) = "64" ]; then
            wget "https://drive.google.com/uc?id=1Ej8VgsW5RgK66Btb9p74tSdHMH3p4UNb&export=download" -O /usr/bin/gdrive
        else
            wget "https://drive.google.com/uc?id=1eo9hMXz0WyuBwRxPM0LrTtQmhTgOLUlg&export=download" -O /usr/bin/gdrive
        fi

        chmod 777 /usr/bin/gdrive
        gdrive list
        
        echo "Gdrive installed successfully."
    fi
    
	if [[ -z $(command -v slacktee.sh) ]]; then
        if [[ $YES_FOR_ALL = 1 ]]; then
            # All yes -> overwrite
            choice="y"
        else
            read -p "slacktee.sh is not installed, do you want to install it? [y/N] :" choice
        fi

        case "$choice" in
        y | Y)

            git clone https://github.com/course-hero/slacktee.git /var/www/papabash/slacktee
            bash /var/www/papabash/slacktee/install.sh
            result=$?
            
            if [[ "$result" == "0" ]]; then
                echo "slacktee.sh successfully installed."
            else
                err_exit 1 "slacktee.sh failed to install, exit code was \"$result\". Please install it first."
            fi
            ;;
        *)
            err_exit 0 "Aborting" # Abort
            ;;
        esac
	fi
}

# ---------
# Delete old backup locally
# ---------
function local_delete_expired_backup() {
    FILE_TO_REMOVE="$LOCAL_BACKUP_DESTINATION/$D_CONTAINER_NAME.$D_NAME.$EXPIRED_DATE.tar.gz"
    echo " "
    echo "Finding local expired backup ($FILE_TO_REMOVE)..."

    # if [[ -e "$FILE_TO_REMOVE" ]]; then
    #     __log "Deleting local expired backup ($FILE_TO_REMOVE) ..."
    #     $CLEAN $FILE_TO_REMOVE
    #     [[ ! -f $FILE_TO_REMOVE ]] && __log "=> Deleted."
    # else
    #     echo "=> Not found."
    # fi

    for f in $FILE_TO_REMOVE; do

        ## Check if the glob gets expanded to existing files.
        ## If not, f here will be exactly the pattern above
        ## and the exists test will evaluate to false.
        # [ -e "$f" ] && __log "files do exist" || __log "files do not exist"

        if [[ -e "$f" ]]; then
            __log "Deleting local expired backup ($f) ..."
            $CLEAN -f $f
            [[ ! -f $f ]] && __log "=> Deleted."
        else
            echo "=> Not found."
        fi

        ## This is all we needed to know, so we can break after the first iteration
        break
    done

    echo " "
}

# ---------
# Delete old backup, get folder id and delete if exists
# ---------
function gdrive_delete_expired_backup() {
    echo " "
    echo "[Gdrive] Finding expired backup ($D_CONTAINER_NAME.$D_NAME.$EXPIRED_DATE.tar.gz)..."
    GDRIVE_EXPIRED_BACKUP_ID=$(gdrive list --no-header --name-width 0 --query "name = '$D_CONTAINER_NAME.$D_NAME.$EXPIRED_DATE.tar.gz'" --max 1 --order createdTime | awk '{ print $1 }')
    # awk 'NR > 1 {exit}; {print $NR;}'
    echo "[Gdrive][Debug] GDRIVE_EXPIRED_BACKUP_ID=$GDRIVE_EXPIRED_BACKUP_ID"
    if [[ ! -z "$GDRIVE_EXPIRED_BACKUP_ID" ]]; then
        __log "[Gdrive] Found expired backup ($D_CONTAINER_NAME.$D_NAME.$EXPIRED_DATE.tar.gz)."
        echo "[Gdrive] Deleting..."
        GDRIVE_RESPONSE=$(gdrive delete $GDRIVE_EXPIRED_BACKUP_ID)
        __log "$GDRIVE_RESPONSE"
        # [[ -s /tmp/web_log.txt ]] && echo "[Gdrive] Deleted Old Backup Successfully.. File Name $GDRIVE_EXPIRED_BACKUP_ID" >>"$LOG_FILE" || echo " [Gdrive] Delete Old Backup Error..!!" >>"$LOG_FILE"
        echo "[Gdrive] => Deleted."
    else
        echo "[Gdrive] => Not found."
    fi
    echo " "
}

# ---------
# Send backups to gDrive
# ---------
function send_backup_to_gdrive() {

    __log "Sending backups to gDrive..."
    __log "Backup path           : $LOCAL_BACKUP_DESTINATION"

    FILE_TO_BACKUP="$LOCAL_BACKUP_DESTINATION/$D_CONTAINER_NAME.$D_NAME.$TODAY.tar.gz"
    if [ -f "$FILE_TO_BACKUP" ]; then
        __log "Backup file           : $D_CONTAINER_NAME.$D_NAME.$TODAY.tar.gz ($(stat -c%s $FILE_TO_BACKUP | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1000 ){ $1/=1000; s++ } printf "%.2f %s", $1, v[s] }'))"
	else
        __log "Backup file           : $D_CONTAINER_NAME.$D_NAME.$TODAY.tar.gz (Not found)"
	fi

    FILE_TO_REMOVE="$LOCAL_BACKUP_DESTINATION/$D_CONTAINER_NAME.$D_NAME.$EXPIRED_DATE.tar.gz"
    for f in $FILE_TO_REMOVE; do
        __log "Backup file to delete :"
        ## Check if the glob gets expanded to existing files.
        ## If not, f here will be exactly the pattern above
        ## and the exists test will evaluate to false.
        # [ -e "$f" ] && __log "files do exist" || __log "files do not exist"
        if [ -f "$f" ]; then
            __log " - $f ($(stat -c%s $f | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1000 ){ $1/=1000; s++ } printf "%.2f %s", $1, v[s] }'))"
        else
            __log " - $f (Not found)"
        fi
        __log "----------------------------------------------"

        ## This is all we needed to know, so we can break after the first iteration
        break
    done

    #Check remote backup folder exists on gdrive
    GDRIVE_ROOT_FOLDER_ID=$(gdrive list --no-header --query "name = '$GDRIVE_ROOT_FOLDER'" --max 1 --order createdTime | grep dir | awk '{ print $1 }')
    if [[ -z "$GDRIVE_ROOT_FOLDER_ID" ]]; then
        
        GDRIVE_RESPONSE=$(gdrive mkdir $GDRIVE_ROOT_FOLDER)
        echo "[Gdrive][Debug] GDRIVE_RESPONSE=$GDRIVE_RESPONSE"
        __log "$GDRIVE_RESPONSE"

        GDRIVE_ROOT_FOLDER_ID=$(gdrive list --no-header --query "name = '$GDRIVE_ROOT_FOLDER'" --max 1 --order createdTime | grep dir | awk '{ print $1 }')
    fi

    # Get current folder ID
    echo "[Gdrive] Checking if folder already exists on gdrive - /$GDRIVE_ROOT_FOLDER/$D_CONTAINER_NAME/"
    GDRIVE_CONTAINER_DIR_ID=$(gdrive list --no-header --query "name = '$D_CONTAINER_NAME'" --max 1 --order createdTime | grep dir | awk '{ print $1 }')
    #Create folder if doesn't exist
    if [[ -z "$GDRIVE_CONTAINER_DIR_ID" ]]; then
        echo "[Gdrive] => Folder NOT exist."
        __log "[Gdrive] => Creating new folder..."
        GDRIVE_RESPONSE=$(gdrive mkdir --parent $GDRIVE_ROOT_FOLDER_ID $D_CONTAINER_NAME)
        # echo "[Gdrive][Debug] GDRIVE_RESPONSE=$GDRIVE_RESPONSE"
        __log "$GDRIVE_RESPONSE"
        echo "[Gdrive][Debug] $($GDRIVE_RESPONSE | awk '{print $(NR+1)}')"
        # Get new folder ID
        GDRIVE_CONTAINER_DIR_ID=$(gdrive list --no-header --query "name = '$D_CONTAINER_NAME'" --max 1 --order createdTime | grep dir | awk '{ print $1 }')
        echo "[Gdrive] => Created new folder (id: $GDRIVE_CONTAINER_DIR_ID)"
    else
        echo "[Gdrive] => Folder exist (id: $GDRIVE_CONTAINER_DIR_ID)."
    fi

    # Check remote backup file exists on gdrive
    echo "[Gdrive] Checking if file already exists on gdrive - $D_CONTAINER_NAME.$D_NAME.$TODAY.tar.gz"
    GDRIVE_FILE_ID=$(gdrive list --no-header --name-width 0 --query "name = '$D_CONTAINER_NAME.$D_NAME.$TODAY.tar.gz'" --max 1 --order createdTime | awk '{ print $1 }')
    echo "[Gdrive][Debug] GDRIVE_FILE_ID=$GDRIVE_FILE_ID"

    GDRIVE_WRITE_ON=0
    if [[ -z "$GDRIVE_FILE_ID" ]]; then
        # Not exists
        GDRIVE_WRITE_ON=1
    else
        # Exists => Confirm still upload (duplicated)
        echo "[Gdrive][Warn] $D_CONTAINER_NAME.$D_NAME.$TODAY.tar.gz (id: $GDRIVE_FILE_ID) already exists."
        if [[ $YES_FOR_ALL = 1 ]]; then
            # All yes -> overdo
            GDRIVE_WRITE_ON=1
        else
            read -p "[Gdrive] Are you want to continue (duplicated)? [y/N] :" choice
            case "$choice" in
                y | Y)
                    # Continue duplicate
                    GDRIVE_WRITE_ON=1
                    ;;
                *)
                    echo "[Gdrive] Stop uploading $D_CONTAINER_NAME..."
                    # err_exit 0 "Aborting" # Abort
                    # return 0 # Exit function
                    GDRIVE_WRITE_ON=0
                    ;;
            esac
        fi
    fi

    if [[ $GDRIVE_WRITE_ON = 1 ]]; then
        # Copy to temp folder
        cp -f $FILE_TO_BACKUP /tmp/$D_CONTAINER_NAME.$D_NAME.$TODAY.tar.gz
        # Upload temp file & delete if success
        __log "[Gdrive] Uploading the file to the folder..."
        
        GDRIVE_RESPONSE=$(gdrive upload --parent $GDRIVE_CONTAINER_DIR_ID --delete /tmp/$D_CONTAINER_NAME.$D_NAME.$TODAY.tar.gz)
        __log "[Gdrive][Debug] $GDRIVE_RESPONSE"

        # Temp file deleted := upload successfully
        if [[ ! -f /tmp/$D_CONTAINER_NAME.$D_NAME.$TODAY.tar.gz ]]; then
            __log "[Gdrive] $D_CONTAINER_NAME's Volume Backup Successfully Done."
            __log "[Gdrive] File Name: $D_CONTAINER_NAME.$D_NAME.$TODAY.tar.gz ($(stat -c%s $FILE_TO_BACKUP | awk '{ split( "B KB MB GB TB PB" , v ); s=1; while( $1>1000 ){ $1/=1000; s++ } printf "%.2f %s", $1, v[s] }'))"
    
            # Check old backup & delete if exists
            FORCE_CHECK_REMOVE_EXPIRED_GDRIVE_BACKUP=1
            
        else
            __log "$D_CONTAINER_NAME's Volume Backup Error..!!"
        fi
    fi

    # Check & delete expired gdrive backup
    echo "[Debug] FORCE_CHECK_REMOVE_EXPIRED_GDRIVE_BACKUP=$FORCE_CHECK_REMOVE_EXPIRED_GDRIVE_BACKUP"
    [[ $FORCE_CHECK_REMOVE_EXPIRED_GDRIVE_BACKUP = 1 ]] && gdrive_delete_expired_backup

    __log "Done uploading $D_CONTAINER_NAME to Gdrive."
    echo " "

}

# ----------
# Start script
# ----------
function check_internet_connection() {
    # Check Internet Connection (https://www.tummy.com/articles/famous-dns-server/)
    echo "Checking Internet Connection..."
    IS=$(/bin/ping -c 5 4.2.2.2 | grep -c "64 bytes")

    if (test "$IS" -gt "2"); then
        HAS_INTERNET=1
    else
        #Display Internet Connection Error Message
        HAS_INTERNET=0
        echo "[ERROR] Please Check Your Internet Connection."
    fi
}

# ----------
# Start script
# ----------
function main() {
    
	parse_args "$@"
    setup
	trap cleanup SIGINT SIGTERM SIGKILL

    if [[ $IS_RESTORE = 1 ]]; then
        # Restore
        restore_docker_volume
    else
        # Backup
        backup_docker_volume
    fi
    
    # Log Status - Send Mail/Slack
    # cat -v "$LOG_FILE" | mutt -s "Backup Server Status Log - $(date)" $EMAIL
    cat -v "$LOG_FILE" | slacktee.sh -a "warning" -e "Backup/Restore Status Log" "From $(hostname) | at $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null

    # Cleanup logs
    # chmod -R 777 /tmp/*
    [ -f "$LOG_FILE" ] && $CLEAN "$LOG_FILE"
    
    exit 0
}
main "$@"
