
#RESOURCE GROUP
resource "azurerm_resource_group" "development" {
    name      = "${var.resource_group}"
    location  = "${var.location}"
}


#NETWORK SECURITY GROUP
resource "azurerm_network_security_group" "development" {
  name                = "nsgdevelopment"
  location            = "${azurerm_resource_group.development.location}"
  resource_group_name = "${azurerm_resource_group.development.name}"

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefixes    = ["190.248.23.200/29","200.31.15.232/29"]
    destination_address_prefix = "*"
  }

  
}

#VIRTUAL NETWORK
resource "azurerm_virtual_network" "development" {
    name  = "developmentNetwork"
    address_space = ["10.0.0.0/16"]
    location = "${azurerm_resource_group.development.location}"
    resource_group_name = "${azurerm_resource_group.development.name}"
}

resource "azurerm_public_ip" "development" {
  name                         = "IPtest"
  location                     = "${azurerm_resource_group.development.location}"
  resource_group_name          = "${azurerm_resource_group.development.name}"
  public_ip_address_allocation = "static"
}


resource "azurerm_subnet" "development" {
 name                 = "subnet1"
 resource_group_name  = "${azurerm_resource_group.development.name}"
 virtual_network_name = "${azurerm_virtual_network.development.name}"
 address_prefix       = "10.0.2.0/24"
}


#LOAD BALANCER
resource "azurerm_lb" "development" {
  name                = "lbdevelopment"
  location            = "${azurerm_resource_group.development.location}"
  resource_group_name = "${azurerm_resource_group.development.name}"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.development.id}"
  }
}

#BACKEND ADDRESS POOL
resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = "${azurerm_resource_group.development.name}"
  loadbalancer_id     = "${azurerm_lb.development.id}"
  name                = "BackEndAddressPool"
}

#INBOUND NATPOOL RULES
resource "azurerm_lb_nat_pool" "lbnatpool" {
  count                          = 3
  resource_group_name            = "${azurerm_resource_group.development.name}"
  name                           = "ssh"
  loadbalancer_id                = "${azurerm_lb.development.id}"
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 3389
  frontend_ip_configuration_name = "PublicIPAddress"
}



#VMSCALE SET
resource "azurerm_virtual_machine_scale_set" "development" {
  name                = "tfscaleset"
  location            = "${azurerm_resource_group.development.location}"
  resource_group_name = "${azurerm_resource_group.development.name}"
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_DS1_v2"
    tier     = "Standard"
    capacity = 1
  }

  storage_profile_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun            = 0
    caching        = "ReadWrite"
    create_option  = "Empty"
    disk_size_gb   = 10
  }

  os_profile {
    computer_name_prefix = "devvm"
    admin_username       = "laurad"
    admin_password       = "Empanada@1k!"
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "developmentIPConfiguration"
      subnet_id                              = "${azurerm_subnet.development.id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.bpepool.id}"]
      load_balancer_inbound_nat_rules_ids    = ["${element(azurerm_lb_nat_pool.lbnatpool.*.id, count.index)}"]
    }
  }

  
}

#dns zone
resource "azurerm_dns_zone" "dnspublic" {
 name  = "trfdns.com"
 resource_group_name = "${azurerm_resource_group.development.name}"
  zone_type ="Public"
  
}

resource "azurerm_dns_zone" "dnsprivate" {
 name  = "trfdns.com"
  resource_group_name = "${azurerm_resource_group.development.name}"
  zone_type ="Private"
  
}

#DATABASE
resource "azurerm_mysql_server" "db" {
  name                = "myazuresqlserver2"
  location            = "${azurerm_resource_group.development.location}"
  resource_group_name = "${azurerm_resource_group.development.name}"
  
  sku {
    name = "B_Gen4_1"
    capacity = 1
    tier = "Basic"
    family = "Gen4"
  }

  storage_profile {
    storage_mb = 5120
    backup_retention_days = 7
    geo_redundant_backup = "Disabled"
  }

  administrator_login = "mysqladminun"
  administrator_login_password = "H@Sh1CoR3!"
  version = "5.7"
  ssl_enforcement = "Disabled"
}

resource "azurerm_mysql_database" "db" {
  name                = "testdb"
  resource_group_name = "${azurerm_resource_group.development.name}"
  server_name         = "${azurerm_mysql_server.db.name}"
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}



