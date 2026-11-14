# Private DNS for every private endpoint in the landing zone.
# In an enterprise landing zone these zones live in the hub (connectivity
# subscription); pass their IDs in existing_private_dns_zone_ids and only the
# missing ones are created here.
locals {
  zones_to_create = {
    for k, v in local.private_dns_zones : k => v
    if !contains(keys(var.existing_private_dns_zone_ids), k)
  }
}

resource "azurerm_private_dns_zone" "this" {
  for_each = local.zones_to_create

  name                = each.value
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  for_each = local.zones_to_create

  name                 = "link-${each.key}-${local.suffix}"
  private_dns_zone_id  = azurerm_private_dns_zone.this[each.key].id
  virtual_network_id   = azurerm_virtual_network.spoke.id
  registration_enabled = false
  tags                 = local.tags
}

locals {
  private_dns_zone_ids = merge(
    { for k, z in azurerm_private_dns_zone.this : k => z.id },
    var.existing_private_dns_zone_ids
  )
}
