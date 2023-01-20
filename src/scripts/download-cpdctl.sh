#! /bin/bash
mkdir -p $HOME/bin
wget -q https://github.com/IBM/cpdctl/releases/download/v1.1.299/cpdctl_linux_amd64.tar.gz -P /tmp
tar xvzf /tmp/cpdctl_linux_amd64.tar.gz -C $HOME/bin

export PATH=$PATH:$HOME/bin
cpdctl version