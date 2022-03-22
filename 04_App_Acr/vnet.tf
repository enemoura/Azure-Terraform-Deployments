resource "azurerm_resource_group" "RG" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "VNET" {
  name                = var.vnet_name
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  address_space       = var.vnet_address_space

  dynamic "subnet" {
    for_each = var.vnet_subnets
    content {
      name           = subnet.value.name
      address_prefix = subnet.value.address_prefix
    }
  }

}

resource "azurerm_subnet" "SUBNETS" {
  for_each             = { for s in var.subnets_delegated : s.subnet_name => s }
  resource_group_name  = azurerm_resource_group.RG.name
  name                 = each.value.subnet_name
  virtual_network_name = azurerm_virtual_network.VNET.name
  address_prefixes     = each.value.subnet_address_prefixes
  service_endpoints    = each.value.subnet_service_endpoints

  dynamic "delegation" {
    for_each = each.value.delegation
    content {
      name = delegation.value.delegation_name
      dynamic "service_delegation" {
        for_each = delegation.value["service"] != [] ? delegation.value["service"] : []
        content {
          name    = service.value["service_name"]
          actions = service.value["service_actions"]
        }
      }
    }
  }
}

#Get subnet name from ID: element(split("/", "/subs/xxxx/name"), length(split("/", "/subs/xxxx/name"))-1)
resource "azurerm_network_security_group" "NSG" {
  count               = length(azurerm_subnet.SUBNETS)
  name                = "${azurerm_subnet.SUBNETS[count.index].name}-nsg"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  #depends_on          = [azurerm_subnet.SUBNETS, azurerm_virtual_network.VNET]
}

resource "azurerm_subnet_network_security_group_association" "nsg_subnet_assoc" {
  count                     = length(azurerm_subnet.SUBNETS)
  subnet_id                 = azurerm_subnet.SUBNETS[count.index].id
  network_security_group_id = azurerm_network_security_group.NSG[count.index].id
}
