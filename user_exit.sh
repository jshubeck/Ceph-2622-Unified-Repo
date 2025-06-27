#!/bin/bash

## Get the helper file for Bastion workstation
USER_HOME=$(cat /etc/passwd | grep ^U | cut -d: -f6)
USER=$(cat /etc/passwd | grep ^U | cut -d: -f1)
cp ./cli-helper-2622.adoc $USER_HOME/cli-helper-2622.adoc
cp ./cli-helper-2622.html $USER_HOME/cli-helper-2622.html
mkdir /root/scripts.d
cp ./deploy_cluster.sh /root/scripts.d
cp ./break_and_fix1.yaml /root/scripts.d
cp ./break_and_fix2.yaml /root/scripts.d
chown $USER $USER_HOME/cli-helper-2622*
chmod 644 $USER_HOME/cli-helper-2622*
ssh ceph-node1 "mkdir /root/scripts.d"
scp ./purge_cluster.sh root@ceph-node1:/root/scripts.d
scp ./new_cluster_deploy.sh root@ceph-node1:/root/scripts.d

## Install the NFS client
dnf install -y nfs-utils

## Install AWS CLI client
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
chmod -R 755 /usr/local/aws-cli

# Install the MinIO (MC) client
curl https://dl.min.io/client/mc/release/linux-amd64/mc \
--create-dirs -o $HOME/minio-binaries/mc
# chmod 755 $HOME/minio-binaries/mc
cp $HOME/minio-binaries/mc /usr/local/bin
chmod 755 /usr/local/bin/mc

## Install the RCLONE client
curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip
unzip rclone-current-linux-amd64.zip
cp rclone-*-linux-amd64/rclone /usr/bin/
chown root:root /usr/bin/rclone
chmod 755 /usr/bin/rclone

## Configure html cli helper file as the default Firefox home page
PROFILE_DIR=$(find $USER_HOME/.mozilla/firefox -type d -name "*.default*" | head -n 1)
if [ -z "$PROFILE_DIR" ]; then
    echo "No Firefox profile found. Starting Firefox to create one..."
    sudo su - $USER -c "firefox --headless &"
    sleep 10
    pkill -f firefox
fi

## Search for the prefs.js file in the user's home directory
PREFS_PATH=$(find $USER_HOME -type f -name "prefs.js" | grep ".mozilla/firefox" | head -n 1)

## Check if the prefs.js file was found
if [ -z "$PREFS_PATH" ]; then
    echo "prefs.js file not found in the home directory."
    exit 1
fi

# Update profiles.ini to ensure the correct profile is used
PROFILES_INI="$USER_HOME/.mozilla/firefox/profiles.ini"
if [ -f "$PROFILES_INI" ]; then
    echo "Updating profiles.ini to set the correct profile as default."
    PROFILE_DIR=$(find $USER_HOME/.mozilla/firefox -type d -name "*.default*" | head -n 1)
    PROFILE_NAME=$(basename "$PROFILE_DIR")
    cat <<EOF > "$PROFILES_INI"
[General]
StartWithLastProfile=1
Version=2

[Profile0]
Name=default
IsRelative=1
Path=$PROFILE_NAME
Default=1
EOF
fi

## Define the path to the local HTML file
HTML_FILE_PATH="$USER_HOME/cli-helper-2622.html"

## Convert the file path to a URL format
FILE_URL="file://$HTML_FILE_PATH"

## Specify the second URL to open in a new tab
SECOND_URL="https://ceph-node1:8443"

## Backup the current prefs.js file
cp "$PREFS_PATH" "$PREFS_PATH.bak"

## Check if the user.js file exists in the same directory as prefs.js and create it if not
USER_JS_PATH=$(dirname "$PREFS_PATH")/user.js
if [ ! -f "$USER_JS_PATH" ]; then
    touch "$USER_JS_PATH"
    chmod 644 $USER_JS_PATH
    chown $USER:$USER $USER_JS_PATH
fi

pkill firefox
## Add the local file URL and the second URL to the startup pages (home pages) in user.js
echo 'user_pref("browser.startup.homepage", "'$FILE_URL'|'$SECOND_URL'");' >> "$USER_JS_PATH"
echo "Firefox will open with $FILE_URL and $SECOND_URL on startup."

## Install rpcbind on every node - required for Ceph NFS service to start
for SERVER in 1 2 3 4
do
ssh ceph-node${SERVER} "systemctl unmask rpcbind.socket ; systemctl unmask rpcbind.service ; systemctl enable --now rpcbind"
done

## Copy Ceph admin keys to the Bastion workstation
curl https://public.dhe.ibm.com/ibmdl/export/pub/storage/ceph/ibm-storage-ceph-8-rhel-9.repo | sudo tee /etc/yum.repos.d/ibm-storage-ceph-8-rhel-9.repo
dnf install ceph-common -y
scp -pr ceph-node1:/etc/ceph/ /etc/
sleep 90
ceph config-key get mgr/cephadm/registry_credentials | jq . > /root/scripts.d/registry.json
scp /root/scripts.d/registry.json root@ceph-node1:/root/scripts.d
exit 0
