#!/bin/bash

set -e

BACKUP_DIR=/home/papagroup/.db_backups/
prompt="Please select a file to remove (0 to Quit):"
options=( $(find $BACKUP_DIR -maxdepth 1 -print0 | xargs -0) )

PS3="$prompt "
select opt in "${options[@]}" ; do
    if (( REPLY == 0 )) ; then
        exit

    elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
        echo  "You picked $opt which is file $REPLY"
        break

    else
        echo "Invalid option. Try another one."
    fi
done

FILE_TO_RESTORE=$opt

D_CONTAINER_NAME=deploy_db_1
D_VOLUME_PATH=/var/lib/mysql
#FILE_TO_RESTORE=/home/papagroup/.db_backups/deploy_db_1.mes.papagroup.net.2020-03-18_08.tar.gz

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

echo "Done restore successfully."
