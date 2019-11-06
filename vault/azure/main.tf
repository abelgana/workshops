resource "azurerm_resource_group" "rg_vault_workshop" {
  location = var.location
  name = "${var.prefix}-rg-vault-workshop"
}

resource "azurerm_virtual_network" "vnet_vault_workshop" {
  address_space = [
    var.address_space]
  location = azurerm_resource_group.rg_vault_workshop.location
  name = "${var.prefix}-vnet-vault-workshop"
  resource_group_name = azurerm_resource_group.rg_vault_workshop.name
}

resource "azurerm_subnet" "snet_vault_workshop" {
  address_prefix = var.subnet_prefix
  name = "${var.prefix}-snet-vault-workshop"
  resource_group_name = azurerm_resource_group.rg_vault_workshop.name
  virtual_network_name = azurerm_virtual_network.vnet_vault_workshop.name
}

resource "azurerm_network_security_group" "nsg_vault_workshop" {
  location = var.location
  name = "${var.prefix}-nsg-vault-workshop"
  resource_group_name = azurerm_resource_group.rg_vault_workshop.name

  security_rule {
    access = "Allow"
    destination_address_prefix = "*"
    destination_port_range = "8200"
    direction = "Inbound"
    name = "Vault"
    priority = 100
    protocol = "TCP"
    source_address_prefix = var.vault_source_ips
    source_port_range = "*"
  }

  security_rule {
    access = "Allow"
    destination_address_prefix = "*"
    destination_port_range = "5000"
    direction = "Inbound"
    name = "Transit-App"
    priority = 101
    protocol = "TCP"
    source_address_prefix = "*"
    source_port_range = "*"
  }

  security_rule {
    access = "Allow"
    destination_address_prefix = "*"
    destination_port_range = "22"
    direction = "Inbound"
    name = "SSH"
    priority = 102
    protocol = "TCP"
    source_address_prefix = var.ssh_source_ips
    source_port_range = "*"
  }
}

# resource "azurerm_firewall" "firewall-to-add" {
#   name                = "testfirewall"
#   location            = azurerm_resource_group.rg_vault_workshop.location
#   resource_group_name = azurerm_resource_group.rg_vault_workshop.name
#
#   ip_configuration {
#     name                 = "configuration"
#     subnet_id            = azurerm_subnet.snet_vault_workshop.id
#     public_ip_address_id = azurerm_public_ip.public_ip_vault_workshop.id
#   }
# }

resource "azurerm_public_ip" "public_ip_vault_workshop" {
  allocation_method = "Dynamic"
  domain_name_label = "${var.prefix}-ssh"
  location = azurerm_resource_group.rg_vault_workshop.location
  name = "${var.prefix}-public-ssh-ip-vault-workshop"
  resource_group_name = azurerm_resource_group.rg_vault_workshop.name
}

resource "azurerm_network_interface" "nic_ssh_vault_workshop" {
  location = var.location
  name = "${var.prefix}-nic-ssh-vault-workshop"
  network_security_group_id = azurerm_network_security_group.nsg_vault_workshop.id
  resource_group_name = azurerm_resource_group.rg_vault_workshop.name

  ip_configuration {
    name = "${var.prefix}-piconf-ssh-vault-workshop"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.public_ip_vault_workshop.id
    subnet_id = azurerm_subnet.snet_vault_workshop.id
  }
}

resource "azurerm_virtual_machine" "bastion_vault_workshop" {
  location = var.location
  name = "${var.prefix}-bastion-vault-workshop"
  network_interface_ids = [
    azurerm_network_interface.nic_ssh_vault_workshop.id]
  resource_group_name = azurerm_resource_group.rg_vault_workshop.name
  vm_size = var.vm_size

  storage_image_reference {
    publisher = var.image_publisher
    offer = var.image_offer
    sku = var.image_sku
    version = var.image_version
  }

  storage_os_disk {
    create_option = "fromImage"
    managed_disk_type = "Standard_LRS"
    name = "${var.prefix}-disk-ssh-vault-workshop"
  }

  os_profile {
    admin_username = var.admin_username
    computer_name = var.prefix
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file(var.public_key_path)
      path = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }
}

resource "azurerm_network_interface" "nic_vault_workshop" {
  count = var.vault_vms

  location = azurerm_resource_group.rg_vault_workshop.location
  name = "${var.prefix}-nic-vault-workshop-${count.index}"
  network_security_group_id = azurerm_network_security_group.nsg_vault_workshop.id
  resource_group_name = azurerm_resource_group.rg_vault_workshop.name

  ip_configuration {
    name = "${var.prefix}-ipconf-vault-workshop-${count.index}"
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.snet_vault_workshop.id
  }
}

resource "azurerm_availability_set" "av_set_vault_workshop" {
  location = azurerm_resource_group.rg_vault_workshop.location
  name = "${var.prefix}-av-set-vault-workshop"
  resource_group_name = azurerm_resource_group.rg_vault_workshop.name
  managed = true
}

resource "azurerm_virtual_machine" "vm_vault_workshop" {
  count = var.vault_vms

  location = azurerm_resource_group.rg_vault_workshop.location
  name = "${var.prefix}-vm-vault-workshop-${count.index}"
  network_interface_ids = [azurerm_network_interface.nic_vault_workshop[count.index].id]
  resource_group_name = azurerm_resource_group.rg_vault_workshop.name
  vm_size = var.vm_size
  availability_set_id = azurerm_availability_set.av_set_vault_workshop.id

  storage_image_reference {
    publisher = var.image_publisher
    offer = var.image_offer
    sku = var.image_sku
    version = var.image_version
  }

  storage_os_disk {
    create_option = "fromImage"
    managed_disk_type = "Standard_LRS"
    name = "${var.prefix}-disk-vault-workshop-${count.index}"
  }

  os_profile {
    admin_username = var.admin_username
    computer_name = "${var.prefix}-vm-vault-workshop-${count.index}"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file(var.public_key_path)
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }
  provisioner "file" {
    source      = "../files/scripts/setup.sh"
    destination = "/home/${var.admin_username}/setup.sh"

    connection {
      type = "ssh"
      bastion_host = azurerm_public_ip.public_ip_vault_workshop.fqdn
      bastion_host_key = var.public_key_path
      bastion_user = var.admin_username
      bastion_private_key  = file(var.private_key_path)
      host = self.name
      user = var.admin_username
      private_key = file(var.private_key_path)
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/${var.admin_username}/setup.sh",
      "/home/${var.admin_username}/setup.sh",
    ]

    connection {
      type = "ssh"
      bastion_host = azurerm_public_ip.public_ip_vault_workshop.fqdn
      bastion_host_key = var.public_key_path
      bastion_user = var.admin_username
      bastion_private_key  = file(var.private_key_path)
      host = self.name
      user = var.admin_username
      private_key = file(var.private_key_path)
    }
  }
}


