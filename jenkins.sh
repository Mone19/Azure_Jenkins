#!/bin/bash

# Update package lists
echo "Updating package lists..."
sudo apt update

# Install Java 21
echo "Installing Java 21..."
sudo apt install openjdk-21-jre -y

# Add Jenkins repository key
echo "Adding Jenkins repository key..."
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io.key

# Add Jenkins repository
echo "Adding Jenkins repository..."
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Update package lists again and install Jenkins
echo "Updating package lists..."
sudo apt update

echo "Installing Jenkins..."
sudo apt install jenkins -y

# Install additional packages
echo "Installing additional packages..."
sudo apt install -y git nodejs npm unzip jq docker.io

# Configure Docker and Jenkins
echo "Starting and enabling Jenkins..."
sudo systemctl start jenkins
sudo systemctl enable jenkins

echo "Starting and enabling Docker..."
sudo systemctl start docker
sudo systemctl enable docker

# Add Jenkins and current user to Docker group
echo "Adding user to Docker group..."
sudo usermod -aG docker $USER
sudo usermod -aG docker jenkins

# Download and install other tools
echo "Downloading and installing AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" 
sudo unzip awscliv2.zip
sudo ./aws/install

echo "Downloading and installing kubectl..."
curl -o kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.23.7/2022-06-29/bin/linux/amd64/kubectl
chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl
sudo cp kubectl /usr/local/bin/

echo "Downloading and installing eksctl..."
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

echo "Downloading and installing OWASP ZAP..."
sudo wget https://github.com/zaproxy/zaproxy/releases/download/v2.14.0/ZAP_2_14_0_unix.sh
sudo chmod +x ZAP_2_14_0_unix.sh 
sudo ./ZAP_2_14_0_unix.sh -q

# Check Jenkins and Docker status
echo "Checking Jenkins status..."
sudo systemctl status jenkins

echo "Checking Docker status..."
sudo systemctl status docker

echo "Setup completed successfully."