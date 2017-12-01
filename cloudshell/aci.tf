resource "azurerm_container_group" "aci-iexcompanies" {
  name                = "iexcompanies"
  location            = "${azurerm_resource_group.terraformonazure.location}"
  resource_group_name = "${azurerm_resource_group.terraformonazure.name}"
  ip_address_type     = "public"
  os_type             = "linux"

  container {
    name = "iexcompanies"
    image = "inklin/iexcompanies"
    cpu ="0.5"
    memory =  "1.5"
    port = "80"

    environment_variables {
        "COSMOSDB"="mongodb://${azurerm_cosmosdb_account.cosmosdb.name}:${azurerm_cosmosdb_account.cosmosdb.primary_master_key}@${azurerm_cosmosdb_account.cosmosdb.name}.documents.azure.com:10255/?ssl=true&replicaSet=globaldb"
    }
  }

  tags {
    environment = "testing"
  }
}