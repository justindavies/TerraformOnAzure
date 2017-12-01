# resource-groups.tf
# Author: juda@microsoft.com
# Configure the Microsoft Azure Provider


# Create a resource group
resource "azurerm_resource_group" "terraformonazure" {  
    name     = "terraformonazure"
    location = "East US"
}
