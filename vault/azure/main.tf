resource "azurerm_resource_group" "rg_vault_cluster" {
  location = var.location
  name = "${var.prefix}-rg-vault-cluster"
}

resource "azurerm_virtual_network" "vnet_vault_cluster" {
  address_space = [
    var.address_space]
  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-vnet-vault-cluster"
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name
}

resource "azurerm_subnet" "ssh_snet" {
  address_prefix = var.ssh_subnet_prefix
  name = "${var.prefix}-snet-ssh-vault"
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name
  virtual_network_name = azurerm_virtual_network.vnet_vault_cluster.name
}

resource "azurerm_subnet" "lb_vault_snet" {
  address_prefix = var.lb_vault_subnet_prefix
  name = "${var.prefix}-snet-lb-vault"
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name
  virtual_network_name = azurerm_virtual_network.vnet_vault_cluster.name
}

resource "azurerm_subnet" "vault_consul_snet" {
  address_prefix = var.consul_subnet_prefix
  name = "${var.prefix}-snet-vault-consul"
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name
  virtual_network_name = azurerm_virtual_network.vnet_vault_cluster.name
}

resource "azurerm_public_ip" "ssh_public_ip" {
  allocation_method = "Dynamic"
  domain_name_label = "${var.prefix}-ssh-public-ip"
  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-ssh-public-ip"
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name
}

resource "azurerm_public_ip" "lb_public_ip" {
  allocation_method = "Dynamic"
  domain_name_label = "${var.prefix}-lb-public-ip"
  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-lb-public-ip"
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name
}

resource "azurerm_network_security_group" "nsg_ssh_vault" {
  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-nsg-ssh-workshop"
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name

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

resource "azurerm_network_security_group" "nsg_lb_vault" {
  location = var.location
  name = "${var.prefix}-nsg-vault-workshop"
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name

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
}

resource "azurerm_network_security_group" "nsg_vault_consul" {
  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-nsg-vault-consul"
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name

  security_rule {
    access = "Allow"
    destination_address_prefix = "*"
    destination_port_range = "*"
    direction = "Inbound"
    name = "Consul"
    priority = 100
    protocol = "TCP"
    source_address_prefix = "*"
    source_port_range = "*"
  }
}

resource "azurerm_network_interface" "nic_vault_consul" {
  count = var.vault_vms

  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-nic-vault-consul${count.index}"
  network_security_group_id = azurerm_network_security_group.nsg_vault_consul.id
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name

  ip_configuration {
    name = "${var.prefix}-ip-conf-vault-consul-${count.index}"
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.vault_consul_snet.id
  }
}

resource "azurerm_network_interface" "nic_consul_ssh" {
  count = var.consul_vms

  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-nic-ssh-consul-${count.index}"
  network_security_group_id = azurerm_network_security_group.nsg_ssh_vault.id
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name

  ip_configuration {
    name = "${var.prefix}-ip-conf-consul-ssh-${count.index}"
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.ssh_snet.id
  }
}

resource "azurerm_network_interface" "nic_ssh_workshop" {
  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-nic-vault-workshop"
  network_security_group_id = azurerm_network_security_group.nsg_ssh_vault.id
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name

  ip_configuration {
    name = "${var.prefix}-piconf-vault-workshop"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.ssh_public_ip.id
    subnet_id = azurerm_subnet.ssh_snet.id
  }
}

resource "azurerm_network_interface" "public_lb_network_interface" {
  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-public-lb-network-interface"
  network_security_group_id = azurerm_network_security_group.nsg_lb_vault.id
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name

  ip_configuration {
    name = "${var.prefix}-lb-ip-conf"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.lb_public_ip.id
    subnet_id = azurerm_subnet.lb_vault_snet.id
  }
}

resource "azurerm_network_interface" "ssh_lb_network_interface" {
  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-ssh-lb-network-interface"
  network_security_group_id = azurerm_network_security_group.nsg_ssh_vault.id
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name

  ip_configuration {
    name = "${var.prefix}-lb-ssh-ip-conf"
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.ssh_snet.id
  }
}

resource "azurerm_network_interface" "nic_ssh_lb" {
  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-nic-ssh"
  network_security_group_id = azurerm_network_security_group.nsg_ssh_vault.id
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name

  ip_configuration {
    name = "${var.prefix}-ip-conf-ssh-consul"
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.ssh_snet.id
  }
}

resource "azurerm_network_interface" "nic_consul_vault" {
  count = var.consul_vms

  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-nic-consul-vault${count.index}"
  network_security_group_id = azurerm_network_security_group.nsg_vault_consul.id
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name

  ip_configuration {
    name = "${var.prefix}-ip-conf-consul-vault-${count.index}"
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.vault_consul_snet.id
  }
}

resource "azurerm_network_interface" "nic_ssh_consul" {
  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-nic-ssh-consul"
  network_security_group_id = azurerm_network_security_group.nsg_ssh_vault.id
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name

  ip_configuration {
    name = "${var.prefix}-ip-conf-ssh-consul"
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.ssh_snet.id
  }
}

resource "azurerm_network_interface" "nic_vault" {
  count = var.vault_vms

  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-nic-vault${count.index}"
  network_security_group_id = azurerm_network_security_group.nsg_lb_vault.id
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name

  ip_configuration {
    name = "${var.prefix}-ip-conf-vault-${count.index}"
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.lb_vault_snet.id
  }
}

resource "azurerm_network_interface" "nic_ssh_vault" {
  count = var.vault_vms

  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-nic-ssh-vault${count.index}"
  network_security_group_id = azurerm_network_security_group.nsg_ssh_vault.id
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name

  ip_configuration {
    name = "${var.prefix}-ip-conf-vault-ssh-${count.index}"
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.ssh_snet.id
  }
}

resource "azurerm_availability_set" "av_set_vault_workshop" {
  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-av-set-vault"
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name
  managed = true
}

resource "azurerm_availability_set" "av_set_consul" {
  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-av-set-consul"
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name
  managed = true
}

resource "azurerm_virtual_machine" "ssh_vm" {
  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-ssh-vm"
  network_interface_ids = [
    azurerm_network_interface.nic_ssh_workshop.id]
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name
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
    name = "${var.prefix}-ssh-disk"
  }

  os_profile {
    admin_username = var.admin_username
    computer_name = "${var.prefix}-ssh"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file(var.public_key_path)
      path = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }
}


resource "azurerm_virtual_machine" "lb_vm" {
  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-lb-vm"
  network_interface_ids = [
    azurerm_network_interface.public_lb_network_interface.id,
    azurerm_network_interface.ssh_lb_network_interface.id]
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name
  primary_network_interface_id = azurerm_network_interface.ssh_lb_network_interface.id
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
    name = "${var.prefix}-lb-disk"
  }

  os_profile {
    admin_username = var.admin_username
    computer_name = "${var.prefix}-lb"
    custom_data = file("../files/envoy/json/ignition.json")
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file(var.public_key_path)
      path = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }
}

resource "azurerm_virtual_machine" "vm_vault_workshop" {
  count = var.vault_vms

  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-vm-vault-${count.index}"
  network_interface_ids = [
    azurerm_network_interface.nic_vault[count.index].id,
    azurerm_network_interface.nic_ssh_vault[count.index].id,
    azurerm_network_interface.nic_vault_consul[count.index].id
  ]
  primary_network_interface_id = azurerm_network_interface.nic_ssh_vault[count.index].id
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name
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
    name = "${var.prefix}-os-disk-vault-${count.index}"
  }

  os_profile {
    admin_username = var.admin_username
    computer_name = "${var.prefix}-os-profile-vault-${count.index}"
    custom_data = file("../files/vault/json/ignition.json")
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file(var.public_key_path)
      path = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }
}

resource "azurerm_virtual_machine" "vm_consul" {
  count = var.consul_vms

  location = azurerm_resource_group.rg_vault_cluster.location
  name = "${var.prefix}-vm-consul-${count.index}"
  network_interface_ids = [
    azurerm_network_interface.nic_consul_vault[count.index].id,
    azurerm_network_interface.nic_consul_ssh[count.index].id
  ]
  primary_network_interface_id = azurerm_network_interface.nic_consul_vault[count.index].id
  resource_group_name = azurerm_resource_group.rg_vault_cluster.name
  vm_size = var.vm_size
  availability_set_id = azurerm_availability_set.av_set_consul.id

  storage_image_reference {
    publisher = var.image_publisher
    offer = var.image_offer
    sku = var.image_sku
    version = var.image_version
  }

  storage_os_disk {
    create_option = "fromImage"
    managed_disk_type = "Standard_LRS"
    name = "${var.prefix}-os-disk-consul-${count.index}"
  }

  os_profile {
    admin_username = var.admin_username
    computer_name = "${var.prefix}-os-profile-consul-${count.index}"
    custom_data = file("../files/consul/json/server/ignition.json")
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = file(var.public_key_path)
      path = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }
}

# resource "azurerm_firewall" "firewall-to-add" {
# }
