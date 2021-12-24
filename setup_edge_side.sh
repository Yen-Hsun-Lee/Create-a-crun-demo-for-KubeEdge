#!/bin/bash 
token=$1
master_ip=$2
echo 'token:' $token 
echo 'master_ip:' $master_ip


# Install CRI-O and crun
wget -qO- https://raw.githubusercontent.com/second-state/wasmedge-containers-examples/main/crio/install.sh | bash


# Install Go
wget https://golang.org/dl/go1.17.3.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.17.3.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin


# join edge node to master
wget https://github.com/kubeedge/kubeedge/releases/download/v1.8.1/keadm-v1.8.1-linux-amd64.tar.gz
tar xzvf keadm-v1.8.1-linux-amd64.tar.gz
cd keadm-v1.8.1-linux-amd64/keadm/

sudo ./keadm join \
--cloudcore-ipport=$master_ip:10000 \
--edgenode-name=edge \
--token=$token \
--remote-runtime-endpoint=unix:///var/run/crio/crio.sock \
--runtimetype=remote \
--cgroupdriver=systemd \
--kubeedge-version=1.8.1

sudo sed -i '/edgeStream/ {N;s/\(enable: \).*/\1true/}' /etc/kubeedge/config/edgecore.yaml
sudo sed -i '/edgeStream/ {N;s/\(server: \).*/\1'$master_ip':10004/}' /etc/kubeedge/config/edgecore.yaml
sudo systemctl restart edgecore.service

echo 'Finish...'
