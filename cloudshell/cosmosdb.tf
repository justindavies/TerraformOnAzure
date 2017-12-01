resource "random_id" "server" {
  keepers = {
    azi_id = 1
  }

  byte_length = 8
}


resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                = "${random_id.server.hex}-demo"
  location            = "${azurerm_resource_group.terraformonazure.location}"
  resource_group_name = "${azurerm_resource_group.terraformonazure.name}"
  offer_type          = "Standard"
  kind                = "MongoDB"
  
  consistency_policy {
    consistency_level = "Session"
  }


  failover_policy {
    location = "East US"
    priority = 0
  }


  tags {
    tier = "Storage"
  }
}

# primary_master_key 