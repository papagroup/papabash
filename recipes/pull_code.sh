#!/bin/bash

set -e

WEB_CONTAINER_NAME=`docker ps --format "{{.Names}}" | grep "web"`
GIT=$(command -v 'git' || which 'git' || type -p 'git')
REPO_URL=git@gitlab.com:papagroup-outsource/bluebiz-mes.git
PROJECT_ROOT=/home/papagroup/bluebiz-seoil
CURRENT_PATH=$PROJECT_ROOT/current
RELEASES_PATH=$PROJECT_ROOT/releases
NEWEST_RELEASE_PATH=$(ls -td -- $RELEASES_PATH/* | head -n 1)
SHARED_PATH=$PROJECT_ROOT/shared
DEP_PATH=$PROJECT_ROOT/.dep
MAX_NUM_OF_REVISION=3
RELEASE_COUNT=`find $RELEASES_PATH -maxdepth 1 -mindepth 1 -type d | wc -l`
# CURRENT_RELEASE_INDEX=$(find $RELEASES_PATH -maxdepth 1 -mindepth 1 -type d -printf '%p\n' | sort -r | head -n 1 | cut -d '/' -f 2) # by alphabet
CURRENT_RELEASE_INDEX=`cd $RELEASES_PATH && [[ -z "$(ls $RELEASES_PATH)" ]] && echo "00" || ls * -td | head -n 1` # latest dir or "00" if empty
# increase +1 to create next release dir
# RELEASE_ID=$((CURRENT_RELEASE_INDEX+1)) # -bash: 08: value too great for base (error token is "08") ?!
RELEASE_ID=`expr $CURRENT_RELEASE_INDEX + 1`
# check if it's below 10 since you need the 0 infront of it
if [ $RELEASE_ID -lt "10" ]; then
   RELEASE_ID=0$RELEASE_ID
else
   RELEASE_ID=$RELEASE_ID
fi
NOW=$(date +"%Y%m%d%H%M%S")

SHARED_SUBDIR_1=BLUE_BIZ_SEOIL/target/storages
WEBSERVICE_USER=www-data

echo " ➤ Executing task deploy:prepare"
if [ ! -d $PROJECT_ROOT ]; then mkdir -p $PROJECT_ROOT; fi
# if [ ! -L $CURRENT_PATH ] && [ -d $CURRENT_PATH ]; then echo 'true'; fi
if [ ! -d $DEP_PATH ]; then mkdir -p $DEP_PATH; fi
if [ ! -d $RELEASES_PATH ]; then mkdir -p $RELEASES_PATH; fi
if [ ! -d $SHARED_PATH ]; then mkdir -p $SHARED_PATH; fi
echo " ➤ Executing task deploy:lock"
if [ -f $DEP_PATH/deploy.lock ]; then echo 'Already locking deployment.'; fi
touch $DEP_PATH/deploy.lock
echo " ➤ Executing task deploy:release"
# cd $PROJECT_ROOT && (if [ -h release ]; then echo 'true'; fi)
# cd $PROJECT_ROOT && (if [ -d releases ] && [ "$(ls -A releases)" ]; then echo 'true'; fi)
# cd $PROJECT_ROOT && (cd releases && ls -t -1 -d */)
# cd $PROJECT_ROOT && (if [ -f .dep/releases ]; then echo 'true'; fi)
# cd $PROJECT_ROOT && (tail -n $MAX_NUM_OF_REVISION .dep/releases)
# cd $PROJECT_ROOT && (if [ -d $PROJECT_ROOT/releases/$RELEASE_ID ]; then echo 'true'; fi)
echo "$NOW,$RELEASE_ID" >> $DEP_PATH/releases
if [ ! -d $RELEASES_PATH/$RELEASE_ID ]; then mkdir -p $RELEASES_PATH/$RELEASE_ID; fi
# cd $PROJECT_ROOT && (if [[ $(man ln 2>&1 || ln -h 2>&1 || ln --help 2>&1) =~ '--relative' ]]; then echo 'true'; fi)
cd $PROJECT_ROOT && (ln -nfs --relative $RELEASES_PATH/$RELEASE_ID $PROJECT_ROOT/release)
echo " ➤ Executing task deploy:pull_code"
# $GIT version
# cd $PROJECT_ROOT && (if [ -h $PROJECT_ROOT/release ]; then echo 'true'; fi)
# cd $PROJECT_ROOT && (readlink $PROJECT_ROOT/release)
echo -e "Host gitlab.com\n\tStrictHostKeyChecking no\n\n" > ~/.ssh/config
cd $PROJECT_ROOT && ($GIT clone -b master --depth 1 --recursive $REPO_URL $RELEASES_PATH/$RELEASE_ID 2>&1)
# echo " ➤ Executing task deploy:shared"
# rm -rf $RELEASES_PATH/$RELEASE_ID/$SHARED_SUBDIR_1
# mkdir -p `dirname $RELEASES_PATH/$RELEASE_ID/$SHARED_SUBDIR_1`
# mkdir -p $SHARED_PATH/$SHARED_SUBDIR_1
# ln -nfs --relative $SHARED_PATH/$SHARED_SUBDIR_1 $RELEASES_PATH/$RELEASE_ID/$SHARED_SUBDIR_1
# echo "➤ Executing task deploy:writable"
# cd $RELEASES_PATH/$RELEASE_ID && (mkdir -p $WRITABLE_SUBDIR_1) && ( chgrp -RH $WEBSERVICE_USER $WRITABLE_SUBDIR_1 )
echo " ➤ Executing task deploy:symlink"
# if [[ $(man mv 2>&1 || mv -h 2>&1 || mv --help 2>&1) =~ '--no-target-directory' ]]; then echo 'true'; fi
mv -T $PROJECT_ROOT/release $PROJECT_ROOT/current
echo " ➤ Executing task deploy:restart_service"
docker restart $WEB_CONTAINER_NAME
echo " ➤ Executing task deploy:unlock"
rm -f $DEP_PATH/deploy.lock
echo " ➤ Executing task fix_permissions"
# chgrp -R $WEBSERVICE_USER $RELEASES_PATH/$RELEASE_ID
# echo $USER
# mkdir -p $RELEASES_PATH/$RELEASE_ID/BLUE_BIZ_SEOIL/target/ROOT # Fix ROOT/ permission
mv $RELEASES_PATH/$RELEASE_ID/BLUE_BIZ_SEOIL/target/.war $RELEASES_PATH/$RELEASE_ID/BLUE_BIZ_SEOIL/target/ROOT.war # Fix ROOT/ permission
# sudo chown -R $USER:$WEBSERVICE_USER $RELEASES_PATH/$RELEASE_ID
sleep 1
sudo chown -R $USER:$USER $RELEASES_PATH/$RELEASE_ID
echo " ➤ Executing task deploy:cleanup"
# Check if reach max revision number -> Remove oldest/expired release
if [ $RELEASE_COUNT -ge $MAX_NUM_OF_REVISION ]; then    
   echo "Reach maximum $MAX_NUM_OF_REVISION revisions"
   OLDEST_RELEASE_PATH=$(IFS= read -r -d $'\0' line < <(find $RELEASES_PATH -maxdepth 1 -mindepth 1 -type d -printf '%T@ %p\0' 2>/dev/null | sort -z -n) && echo "${line#* }")
   echo "Removing $OLDEST_RELEASE_PATH..."
   sudo rm -rf $OLDEST_RELEASE_PATH/BLUE_BIZ_SEOIL/target/ROOT
   rm -rf $OLDEST_RELEASE_PATH
fi
cd $PROJECT_ROOT && if [ -e release ]; then  rm release; fi
cd $PROJECT_ROOT && if [ -h release ]; then  rm release; fi
echo "🚀 Successfully deployed 🚀"
