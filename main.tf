terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.0.1"
    }
  }
}

provider "azurerm" {
  features {}
}

# Random Name Generator
resource "random_pet" "resource_name" {
  length    = 2
  separator = "-"
}

# Resource Group
resource "azurerm_resource_group" "jenkins_rg" {
  name     = "${random_pet.resource_name.id}-resources"
  location = "West Europe"
}

# Virtual Network
resource "azurerm_virtual_network" "jenkins_vmnet" {
  name                = "${random_pet.resource_name.id}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.jenkins_rg.location
  resource_group_name = azurerm_resource_group.jenkins_rg.name
}

# Subnet
resource "azurerm_subnet" "jenkins_subnet" {
  name                 = "${random_pet.resource_name.id}-subnet"
  resource_group_name  = azurerm_resource_group.jenkins_rg.name
  virtual_network_name = azurerm_virtual_network.jenkins_vmnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "jenkins_vmnsg" {
  name                = "${random_pet.resource_name.id}-nsg"
  location            = azurerm_resource_group.jenkins_rg.location
  resource_group_name = azurerm_resource_group.jenkins_rg.name

  # Inbound rules
  security_rule {
    name                       = "${random_pet.resource_name.id}-AllowSSH"
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
    name                       = "${random_pet.resource_name.id}-AllowHTTP"
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
    name                       = "${random_pet.resource_name.id}-AllowJenkins"
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

# Public IP Address
resource "azurerm_public_ip" "jenkins_vm_public_ip" {
  name                = "${random_pet.resource_name.id}-public-ip"
  location            = azurerm_resource_group.jenkins_rg.location
  resource_group_name = azurerm_resource_group.jenkins_rg.name
  allocation_method   = "Static"
}

# Network Interface
resource "azurerm_network_interface" "jenkins_vmnic" {
  name                = "${random_pet.resource_name.id}-nic"
  location            = azurerm_resource_group.jenkins_rg.location
  resource_group_name = azurerm_resource_group.jenkins_rg.name

  ip_configuration {
    name                          = "configuration"
    subnet_id                     = azurerm_subnet.jenkins_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jenkins_vm_public_ip.id
  }
}

# Network Interface Security Group Association
resource "azurerm_network_interface_security_group_association" "jenkins_nsg" {
  network_interface_id      = azurerm_network_interface.jenkins_vmnic.id
  network_security_group_id = azurerm_network_security_group.jenkins_vmnsg.id
}

# SSH Public Key
resource "azurerm_ssh_public_key" "example" {
  name                = "example"
  resource_group_name = "example"
  location            = "West Europe"
  public_key          = file("~/.ssh/id_rsa.pub")
}

# Virtual Machine
resource "azurerm_virtual_machine" "jenkins_vm" {
  name                  = "${random_pet.resource_name.id}-vm"
  resource_group_name   = azurerm_resource_group.jenkins_rg.name
  location              = azurerm_resource_group.jenkins_rg.location
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [azurerm_network_interface.jenkins_vmnic.id]

  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${random_pet.resource_name.id}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${random_pet.resource_name.id}-hostname"
    admin_username = var.admin_username
    admin_password = var.admin_password
    custom_data    = file("jenkins.sh")
  }

  os_profile_linux_config {
    disable_password_authentication = true
  }
}
