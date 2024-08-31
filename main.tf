terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.0.1"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "prefix" {
  default = "tfvmex"
}

# Resource group
resource "azurerm_resource_group" "jenkins-rg" {
  name     = "${var.prefix}-resources"
  location = "West Europe"
}

# Virtual Network
resource "azurerm_virtual_network" "jenkins-vmnet" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.jenkins-rg.location
  resource_group_name = azurerm_resource_group.jenkins-rg.name
}

# Subnet
resource "azurerm_subnet" "jenkins-subnet" {
  name                 = "jenkins-subnet"
  resource_group_name  = azurerm_resource_group.jenkins-rg.name
  virtual_network_name = azurerm_virtual_network.jenkins-vmnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "jenkins-vmnsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.jenkins-rg.location
  resource_group_name = azurerm_resource_group.jenkins-rg.name

  # Inbound rules
  security_rule {
    name                       = "AllowSSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = 22
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = 80
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowJenkins"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network Interface
resource "azurerm_network_interface" "jenkins-vmnic" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.jenkins-rg.location
  resource_group_name = azurerm_resource_group.jenkins-rg.name

  ip_configuration {
    name                          = "configuration"
    subnet_id                     = azurerm_subnet.jenkins-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Network Interface Security Group Association
resource "azurerm_network_interface_security_group_association" "jenkins-nsg" {
  network_interface_id      = azurerm_network_interface.jenkins-vmnic.id
  network_security_group_id = azurerm_network_security_group.jenkins-vmnsg.id
}

# SSH Public Key
resource "azurerm_ssh_public_key" "jenkins-key" {
  name                = "Jenkins_key"
  resource_group_name = azurerm_resource_group.jenkins-rg.name
  location            = azurerm_resource_group.jenkins-rg.location
  public_key          = file("~/.ssh/id_rsa.pub")
}

# Virtual Machine
resource "azurerm_virtual_machine" "jenkins-vm" {
  name                  = "${var.prefix}-vm"
  resource_group_name   = azurerm_resource_group.jenkins-rg.name
  location              = azurerm_resource_group.jenkins-rg.location
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [azurerm_network_interface.jenkins-vmnic.id]

  delete_os_disk_on_termination = true

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
    custom_data = file("jenkins.sh")
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = azurerm_ssh_public_key.jenkins-key.public_key
    }
  }
}
