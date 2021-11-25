#!/bin/sh

set -e

LOG_FILE=/home/papagroup/logs/edumall-wp.log
now="$(date +'%Y-%m-%d %T')"

cd /home/papagroup/projects/bhs-elearning/edumall-wp/edumall-wp-docker

git remote update

UPSTREAM=${1:-'@{u}'}
LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse "$UPSTREAM")
BASE=$(git merge-base @ "$UPSTREAM")

if [ $LOCAL = $REMOTE ]; then
    echo "[INFO][$(date +'%Y-%m-%d %T')] Up-to-date"
elif [ $LOCAL = $BASE ]; then
    echo "-----------"
    echo "[Info][$(date +'%Y-%m-%d %T')] Pulling..." >> $LOG_FILE
    if git pull; then
        echo "[DEBUG][$(date +'%Y-%m-%d %T')] Pull code OK" >> $LOG_FILE
        echo "[INFO][$(date +'%Y-%m-%d %T')] Re-up containers" >> $LOG_FILE
        /usr/local/bin/docker-compose up -d >> $LOG_FILE
    else
        echo "[DEBUG][$(date +'%Y-%m-%d %T')] pull code Not Ok" >> $LOG_FILE
    fi
    echo "[INFO][$(date +'%Y-%m-%d %T')] Done." >> $LOG_FILE
elif [ $REMOTE = $BASE ]; then
    echo "[INFO] Need to push" >> $LOG_FILE
else
    echo "[INFO] Diverged" >> $LOG_FILE
fi

echo "-------------"

