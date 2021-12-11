#!/bin/bash 

MASTER_IP=$1
echo 'MASTER_IP:' $MASTER_IP


# Install Go
wget https://golang.org/dl/go1.17.3.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.17.3.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
go version

# Install CRI-O
# Create the .conf file to load the modules at bootup
cat <<EOF | sudo tee /etc/modules-load.d/crio.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Set up required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system
export OS="xUbuntu_20.04"
export VERSION="1.21"
cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /
EOF
cat <<EOF | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list
deb http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /
EOF

curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers.gpg add -
curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/Release.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/libcontainers-cri-o.gpg add -

sudo apt-get update
sudo apt-get install cri-o cri-o-runc

sudo systemctl daemon-reload
sudo systemctl enable crio --now



# Install K8s


sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
K_VER="1.21.0-00"
sudo apt install -y kubelet=${K_VER} kubectl=${K_VER} kubeadm=${K_VER}
sudo apt-mark hold kubelet kubeadm kubectl


sudo sed -i '/swap/d' /etc/fstab
sudo swapoff -a

# Creating a cluster with kubeadm for K8s
export CIDR=10.85.0.0/16
sudo kubeadm init --apiserver-advertise-address=$MASTER_IP --pod-network-cidr=$CIDR --cri-socket=/var/run/crio/crio.sock

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


# Setup KubeEdge Master Node
wget https://github.com/kubeedge/kubeedge/releases/download/v1.8.0/keadm-v1.8.0-linux-amd64.tar.gz
tar xzvf keadm-v1.8.0-linux-amd64.tar.gz
cd keadm-v1.8.0-linux-amd64/keadm/
sudo ./keadm init --advertise-address=$MASTER_IP --kube-config=$HOME/.kube/config

# Get KubeEdge Master Node token
sudo ./keadm gettoken --kube-config=$HOME/.kube/config

# Enable kubectl logs Feature

export CLOUDCOREIPS=$MASTER_IP
cd ~
git clone https://github.com/kubeedge/kubeedge.git
cp ./kubeedge/build/tools/certgen.sh /etc/kubeedge/
/etc/kubeedge/certgen.sh stream

kubectl get cm tunnelport -nkubeedge -oyaml
