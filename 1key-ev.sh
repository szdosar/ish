#!/bin/bash
### tmux
sudo timedatectl set-timezone Asia/Shanghai
apt-get -y update
apt-get -y install tmux
cd
git clone https://github.com/gpakosz/.tmux.git
ln -s -f .tmux/.tmux.conf
cp .tmux/.tmux.conf.local .
tmux
