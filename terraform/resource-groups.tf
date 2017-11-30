# resource-groups.tf
# Author: juda@microsoft.com
# Configure the Microsoft Azure Provider

provider "azurerm" {  
  subscription_id = "${var.subscription_id}"
  client_id       = "${var.client_id}"
  client_secret   = "${var.client_secret}"
  tenant_id       = "${var.tenant_id}"
}

# Create a resource group
resource "azurerm_resource_group" "terraformonazure" {  
    name     = "terraformonazure"
    location = "East US"
}
