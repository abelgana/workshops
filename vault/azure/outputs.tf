output "Instructions" {
  value = <<EOF

# Run the command below to access vault server

# export VAULT_ADDR=http://${azurerm_public_ip.lb_public_ip.fqdn}:8200
# export VAULT_TOKEN=root

EOF
}