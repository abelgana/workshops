#!/bin/sh

CONSUL_VERSION="1.2.3"
sudo /bin/mkdir -p /var/run/consul
sudo /bin/mkdir -p /var/consul
sudo /bin/chown -R consul:consul /var/run/consul
sudo /bin/chown -R consul:consul /var/consul
/bin/mkdir -p /home/consul/bin
/bin/mkdir -p /home/consul/consul.d
/bin/wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip -P /home/consul/bin
/bin/unzip -u /home/consul/bin/consul_${CONSUL_VERSION}_linux_amd64.zip -d /home/consul/bin
/bin/rm -rf /home/consul/bin/consul_${CONSUL_VERSION}_linux_amd64.zip
SERVICE_IP=$(/bin/ip addr show | /bin/awk -F " |/" '/inet *10.0.20./''{print $6}')
HOSTNAME=$(hostname)

bash -c "cat >/home/consul/consul.d/consul.json" << EOF
{
  "server": true,
  "node_name": "${HOSTNAME}",
  "datacenter": "dc1",
  "data_dir": "/var/consul/data",
  "bind_addr": "${SERVICE_IP}",
  "client_addr": "${SERVICE_IP}",
  "advertise_addr": "${SERVICE_IP}",
  "bootstrap_expect": 3,
  "retry_join": ["vault-azure-workshop-os-profile-consul-0","vault-azure-workshop-os-profile-consul-1","vault-azure-workshop-os-profile-consul-2"],
  "ui": true,
  "log_level": "DEBUG",
  "enable_syslog": true,
  "acl_enforce_version_8": false
}
EOF