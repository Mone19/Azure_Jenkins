terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.0.1"
    }
  }
}

variable "prefix" {
  default = "tfvmex"
}

# Resource group
resource "azurerm_resource_group" "vmrg" {
  name     = "${var.prefix}-resources"
  location = "West Europe"
}

# Virtual Network
resource "azurerm_virtual_network" "vmvnet" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.vmrg.location
  resource_group_name = azurerm_resource_group.vmrg.name
}

# Subnet
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.vmrg.name
  virtual_network_name = azurerm_virtual_network.vmvnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Public IP
resource "azurerm_public_ip" "vmpip" {
  name                = "${var.prefix}-publicip"
  location            = azurerm_resource_group.vmrg.location
  resource_group_name = azurerm_resource_group.vmrg.name
  allocation_method   = "Static"
}

# Network Interface
resource "azurerm_network_interface" "vmnic" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.vmrg.location
  resource_group_name = azurerm_resource_group.vmrg.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Network Security Group
resource "azurerm_network_security_group" "vmnsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.vmrg.location
  resource_group_name = azurerm_resource_group.vmrg.name

  security_rule {
    name                       = "allow-jenkins"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 8080
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network Interface Security Group Association
resource "azurerm_network_interface_security_group_association" "vmnic-nsg" {
  network_interface_id      = azurerm_network_interface.vmnic.id
  network_security_group_id = azurerm_network_security_group.vmnsg.id
}

# Virtual Machine
resource "azurerm_virtual_machine" "vm" {
  name                  = "${var.prefix}-vm"
  location              = azurerm_resource_group.vmrg.location
  resource_group_name   = azurerm_resource_group.vmrg.name
  network_interface_ids = [azurerm_network_interface.vmnic.id]
  vm_size               = "Standard_DS1_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = var.admin_username
    admin_password = var.admin_password

    custom_data = file("jenkins_install.sh")
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "staging"
  }
}