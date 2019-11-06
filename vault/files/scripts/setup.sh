#!/bin/sh

VAULT_VERSION="1.2.3"
USER_HOME="/home/abelgana"
BIN_PATH=${USER_HOME}/bin
wget "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip"
mkdir -p ${BIN_PATH}
unzip "vault_${VAULT_VERSION}_linux_amd64.zip" -d ${BIN_PATH}


sudo bash -c "cat >/etc/systemd/system/vault.service" << 'EOF'
[Unit]
Description=Hashicorp Vault
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=USER_HOME/vault server -dev -dev-root-token-id=root -dev-listen-address=0.0.0.0:8200
Restart=on-failure # or always, on-abort, etc

[Install]
WantedBy=multi-user.target
EOF

sudo sed "s?USER_HOME?${BIN_PATH}?" /etc/systemd/system/vault.service -i

sudo systemctl start vault
sudo systemctl enable vault

echo "export VAULT_ADDR=http://localhost:8200" >> $HOME/.bashrc
echo "export VAULT_TOKEN=root" >> $HOME/.bashrc
