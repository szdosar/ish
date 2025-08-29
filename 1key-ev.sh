#!/bin/bash
### tmux
timedatectl set-timezone Asia/Shanghai
apt -y update
apt -y install tmux git
cd
git clone https://github.com/gpakosz/.tmux.git
ln -s -f .tmux/.tmux.conf
cp .tmux/.tmux.conf.local .
tmux
