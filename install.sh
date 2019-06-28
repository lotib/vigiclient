#!/bin/bash

set -e
set -u

BASEURL=https://www.vigibot.com/vigiclient
BASEDIR=/usr/local/vigiclient

fgrep bcm2835-v4l2 /etc/modules || echo bcm2835-v4l2 >> /etc/modules

apt update
apt install -y nodejs npm ffmpeg

rm -rf $BASEDIR
mkdir -p $BASEDIR
cd $BASEDIR

wget $BASEURL/clientrobotpi.js
wget $BASEURL/trame.js
wget $BASEURL/vigiupdate.sh
chmod +x vigiupdate.sh

wget $BASEURL/robot.json -P /boot -N
wget $BASEURL/vigiclient.service -P /etc/systemd/system -N
wget $BASEURL/vigicron -P /etc/cron.d -N

ln -s /bin/cat processdiffusion
ln -s $(which ffmpeg || echo ffmpegnotfound) processdiffaudio

wget $BASEURL/package.json
npm install

systemctl enable vigiclient
