provider "azurerm" {
	features {}
}

# Managed by Terraform. This call might fail if the resource group has already been created e.g. it is required for packer which will run before Terraform.
# See: https://stackoverflow.com/questions/61418168/terraform-resource-with-the-id-already-exists
# resource "azurerm_resource_group" "main" {
#   name     = "${var.prefix}-rg"
#   location = var.location
#   tags     = {
#     environment = "dev"
#   }
# }
data "azurerm_resource_group" "main" {
  name = "${var.prefix}-rg"
}


resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/24"]
  location            = var.location
  resource_group_name = "${var.prefix}-rg"
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = "${var.prefix}-rg"
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_network_security_group" "main" {
  name                = "${var.prefix}-nsg"
  resource_group_name = "${var.prefix}-rg"
  location            = var.location
  tags                = var.tags
  
  security_rule {
    name                       = "Deny from internet"
	  description				         = "deny access from the internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow from subnet"
	  description				         = "allow access to other VMs on the subnet"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = azurerm_subnet.internal.address_prefixes
    destination_address_prefixes = azurerm_subnet.internal.address_prefixes
  }

  security_rule {
    name                       = "Allow to subnet"
	  description				         = "allow access from other VMs on the subnet"
    priority                   = 210
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = azurerm_subnet.internal.address_prefixes
    destination_address_prefixes = azurerm_subnet.internal.address_prefixes
  }
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic-${count.index}"
  resource_group_name = "${var.prefix}-rg"
  location            = var.location
  count               = var.vm_count

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_public_ip" "main" {
  name                = "${var.prefix}-acceptanceTestPublicIp1"
  resource_group_name = "${var.prefix}-rg"
  location            = var.location
  allocation_method   = "Static"
  tags                = var.tags
}


resource "azurerm_lb" "main" {
  name                = "${var.prefix}-lb"
  resource_group_name = "${var.prefix}-rg"
  location            = var.location

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.main.id
  }
}

resource "azurerm_lb_backend_address_pool" "main" {
  name            = "${var.prefix}-lb-BackEndAddressPool"
  loadbalancer_id = azurerm_lb.main.id
}

resource "azurerm_network_interface_backend_address_pool_association" "main" {
  network_interface_id    = azurerm_network_interface.main[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.main.id
  count                   = var.vm_count
}

resource "azurerm_lb_probe" "main" {
  for_each            = var.lb_probes

  resource_group_name = "${var.prefix}-rg"
  loadbalancer_id     = azurerm_lb.main.id
  name                = "${each.key}-running-probe"
  port                = each.value
}

resource "azurerm_lb_rule" "main" {
  for_each = { for i, v in var.lb_rules: i => v }
    resource_group_name            = "${var.prefix}-rg"
    loadbalancer_id                = azurerm_lb.main.id
    name                           = "${each.value.name}"
    protocol                       = "${each.value.protocol}"
    frontend_port                  = each.value.port_frontend
    backend_port                   = each.value.port_backend
    frontend_ip_configuration_name = "PublicIPAddress"
}


resource "azurerm_availability_set" "main" {
  name                = "${var.prefix}-aset"
  location            = var.location
  resource_group_name = "${var.prefix}-rg"
  tags                = var.tags
}

resource "azurerm_linux_virtual_machine" "main" {
  name                            = "${var.prefix}-vm-${count.index}"
  resource_group_name             = "${var.prefix}-rg"
  location                        = var.location
  size                            = "Standard_B1s"
  availability_set_id             = azurerm_availability_set.main.id
  admin_username                  = "${var.vm_username}"
  admin_password                  = "${var.vm_password}"
  disable_password_authentication = false
  tags                            = var.tags
  source_image_id                 = "${var.image_name}"
  network_interface_ids = [
    azurerm_network_interface.main[count.index].id,
  ]
  count                           = var.vm_count

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  depends_on = [
    azurerm_network_interface.main,
    azurerm_availability_set.main,
    azurerm_lb.main,
  ]
}
