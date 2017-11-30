# Terraform On Azure
A few examples of using Terraform on Azure for your Infrastructure as Code needs.  In this walkthrough we will setup Terraform integration with Azure and deploy a simple 2-tier application using Azure Container Instances and CosmosDB as the backing store.

## Setup your environment

### Get your Subscription ID

```
➜  TerraformOnAzure (master) ✔ az account list -o table
A few accounts are skipped as they don't have 'Enabled' state. Use '--all' to display them.
Name                                  CloudName    SubscriptionId                        State    IsDefault
------------------------------------  -----------  ------------------------------------  -------  -----------
Visual Studio Enterprise              AzureCloud   443e0c11-[snip]-6f4198c8b91c  Enabled
Microsoft Azure Internal Consumption  AzureCloud   63bb1026-[snip]-8b343eefecb3  Enabled  True
Visual Studio Enterprise              AzureCloud   eaca98da-[snip]-f0edb23e0537  Enabled
```

### Create Service Principal for Terraforming

```
➜  TerraformOnAzure (master) ✔ az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/63bb1026-[snip]-8b343eefecb3"
AppId                                 DisplayName                    Name                                  Password                              Tenant
------------------------------------  -----------------------------  ------------------------------------  ------------------------------------  ------------------------------------
ec07b39a-[snip]-ba76ffe3892c  azure-cli-2017-11-29-20-13-29  http://azure-cli-2017-11-29-20-13-29  9184af04-[snip]-225ad6896b03  72f988bf-[snip]-2d7cd011db47
```

## Setup Terraform variables for Service Principal
All of our terraform scripts will need to know the Service Principal details.  

```
# variables.tf
# Author: juda@microsoft.com
# Instantiate variables for the Service Principal

variable "tenant_id" {  
    default = "72f988bf-[snip]-2d7cd011db47"
}

variable "client_id" {  
    default="ec07b39a-[snip]-ba76ffe3892c"
}

variable "client_secret" {  
    default="9184af04-[snip]-225ad6896b03"
}

variable "subscription_id" {  
    default="63bb1026-[snip]-8b343eefecb3"
}
```

### Cloud Shell
Instead of installing the Azure CLI, setting up a Service Principal and the rest of the Terraform Variables you can use the Azure Portal Cloud Shell.

We have made the Terraform experience as simple as possible, as all of the environment details are setup based on your default account through the Azure CLI.

![alt text](images/using-cloud-shell-it-has-my-terraform-variables.jpg "Win!")

If you are using Cloud Shell, you do not need to create the **variables.tf** file, or specify the *provider "azurevm"* section.

## Create your first resource
As with everything Azure, we start with a resource group.  Go ahead and create the file *resource-groups.tf*

```
# resource-groups.tf
# Author: juda@microsoft.com
# Configure the Microsoft Azure Provider

# Remove this section if using Cloud Shell
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
```

### Initialise Terraform

```
➜  create_resource_groups (master) ✗ ~/terraform/terraform init

Initializing provider plugins...
- Checking for available provider plugins on https://releases.hashicorp.com...
- Downloading plugin for provider "azurerm" (0.3.3)...

The following providers do not have any version constraints in configuration,
so the latest version was installed.

To prevent automatic upgrades to new major versions that may contain breaking
changes, it is recommended to add version = "..." constraints to the
corresponding provider blocks in configuration, with the constraint strings
suggested below.

* provider.azurerm: version = "~> 0.3"

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

### The Terraform Plan
It's always good to carry out a dry run of any infrastructure instantiation so that you can see what Terraform *would* do when you apply the configuration.

To do this, run the **terraform plan** command:

```
➜  create_resource_groups (master) ✗ ~/terraform/terraform plan
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.


------------------------------------------------------------------------

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  + azurerm_resource_group.terraformonazure
      id:       <computed>
      location: "eastus"
      name:     "terraformonazure"
      tags.%:   <computed>


Plan: 1 to add, 0 to change, 0 to destroy.

------------------------------------------------------------------------

Note: You didn't specify an "-out" parameter to save this plan, so Terraform
can't guarantee that exactly these actions will be performed if
"terraform apply" is subsequently run.
```

### Let's Terraform

```
➜  create_resource_groups (master) ✗ ~/terraform/terraform apply
azurerm_resource_group.terraformonazure: Creating...
  location: "" => "eastus"
  name:     "" => "terraformonazure"
  tags.%:   "" => "<computed>"
azurerm_resource_group.terraformonazure: Creation complete after 1s (ID: /subscriptions/63bb1026-[snip]-...efecb3/resourceGroups/terraformonazure)

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```


### Check your resources

```
➜  create_resource_groups (master) ✗ az group show -n terraformonazure
Location    Name
----------  ----------------
eastus     terraformonazure
```


## Deploy a 2-Tier Architecture
For this walkthrough, we will use a Docker [image](https://hub.docker.com/r/inklin/iexcompanies/) that will pull some company information for the FANG group of companies, plus Microsoft.

The image will be deployed into an Azure Container Instance, and will be published via a Public IP address.

The data from IEX will be saved into a newly instantiated CosmosDB instance on the first run (to simulate a new test deployment of the code), and any calls the the HTTP endpoint will display a list of the last prices, along with some other data about the stocks.

### Setup the CosmosDB Terraform script

Create a new file called cosmosdb.tf within the same directory as your variables.tf and resource-group.tf files.

```
resource "random_id" "server" {
  keepers = {
    azi_id = 1
  }

  byte_length = 8
}

```

This is used to generate a random 8-character string to provide as unique an FQDN as possible for the new CosmosDB instance.

```
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
```

As you would expect with instantiating a CosmosDB instance, it takes a number of the parameters you would be used to from the Azure CLI, or the Web Portal.

Terraform has the ability to inject calculated, or generated variables, and we are referencing the Location and Resource group we created earlier in the walkthrough.  We will use this functionality a lot more through the document.

### Deploy CosmosDB
Now that the Cosmos Terraform script has been created, go back into the directory, and see what *terraform plan* would do.

```
➜  terraform (master) ✗ ~/terraform/terraform plan
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.

azurerm_resource_group.terraformonazure: Refreshing state... (ID: /subscriptions/63bb1026-[snip]-...efecb3/resourceGroups/terraformonazure)

------------------------------------------------------------------------

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  + azurerm_cosmosdb_account.cosmosdb
      id:                                                   <computed>
      consistency_policy.#:                                 "1"
      consistency_policy.258236697.consistency_level:       "Session"
      consistency_policy.258236697.max_interval_in_seconds: "5"
      consistency_policy.258236697.max_staleness_prefix:    "100"
      failover_policy.#:                                    "1"
      failover_policy.1571414883.id:                        <computed>
      failover_policy.1571414883.location:                  "eastus"
      failover_policy.1571414883.priority:                  "0"
      kind:                                                 "MongoDB"
      location:                                             "eastus"
      name:                                                 "${random_id.server.hex}-demo"
      offer_type:                                           "Standard"
      primary_master_key:                                   <computed>
      primary_readonly_master_key:                          <computed>
      resource_group_name:                                  "terraformonazure"
      secondary_master_key:                                 <computed>
      secondary_readonly_master_key:                        <computed>
      tags.%:                                               "1"
      tags.tier:                                            "Storage"

  + random_id.server
      id:                                                   <computed>
      b64:                                                  <computed>
      b64_std:                                              <computed>
      b64_url:                                              <computed>
      byte_length:                                          "8"
      dec:                                                  <computed>
      hex:                                                  <computed>
      keepers.%:                                            "1"
      keepers.azi_id:                                       "1"


Plan: 2 to add, 0 to change, 0 to destroy.

------------------------------------------------------------------------

Note: You didn't specify an "-out" parameter to save this plan, so Terraform
can't guarantee that exactly these actions will be performed if
"terraform apply" is subsequently run.
```

Some interesting things to note.  As we have already created the resource group in a previous step, Terraform will only create the new CosmosDB instance.  There are two rather large benefits to this:

* It makes it really simple to iterate over a complex deployment model, slowly adding to it over time - rather than a big bang/tear your hair out workflow

* It allows you to treat your Infrastructure as a desired state.  If anyone removes a resource accidentally, it can be brought back to life (we'll see this in action later...)

Once you are happy with what Terraform *would* do, let's go ahead and apply that to our subscription.

This operation only takes 2/3 minutes, so you can go and grab a :coffee:

```
➜  terraform (master) ✗ ~/terraform/terraform apply
azurerm_resource_group.terraformonazure: Refreshing state... (ID: /subscriptions/63bb1026-[snip]-...efecb3/resourceGroups/terraformonazure)
random_id.server: Creating...
  b64:            "" => "<computed>"
  b64_std:        "" => "<computed>"
  b64_url:        "" => "<computed>"
  byte_length:    "" => "8"
  dec:            "" => "<computed>"
  hex:            "" => "<computed>"
  keepers.%:      "" => "1"
  keepers.azi_id: "" => "1"
random_id.server: Creation complete after 0s (ID: Ysem6TNkil4)
azurerm_cosmosdb_account.cosmosdb: Creating...
  consistency_policy.#:                                 "" => "1"
  consistency_policy.258236697.consistency_level:       "" => "Session"
  consistency_policy.258236697.max_interval_in_seconds: "" => "5"
  consistency_policy.258236697.max_staleness_prefix:    "" => "100"
  failover_policy.#:                                    "" => "1"
  failover_policy.1571414883.id:                        "" => "<computed>"
  failover_policy.1571414883.location:                  "" => "eastus"
  failover_policy.1571414883.priority:                  "" => "0"
  kind:                                                 "" => "MongoDB"
  location:                                             "" => "eastus"
  name:                                                 "" => "62c7a6e933648a5e-demo"
  offer_type:                                           "" => "Standard"
  primary_master_key:                                   "" => "<computed>"
  primary_readonly_master_key:                          "" => "<computed>"
  resource_group_name:                                  "" => "terraformonazure"
  secondary_master_key:                                 "" => "<computed>"
  secondary_readonly_master_key:                        "" => "<computed>"
  tags.%:                                               "" => "1"
  tags.tier:                                            "" => "Storage"
azurerm_cosmosdb_account.cosmosdb: Still creating... (10s elapsed)
azurerm_cosmosdb_account.cosmosdb: Still creating... (20s elapsed)
azurerm_cosmosdb_account.cosmosdb: Still creating... (30s elapsed)
azurerm_cosmosdb_account.cosmosdb: Still creating... (40s elapsed)
azurerm_cosmosdb_account.cosmosdb: Still creating... (50s elapsed)
azurerm_cosmosdb_account.cosmosdb: Still creating... (1m0s elapsed)
azurerm_cosmosdb_account.cosmosdb: Still creating... (1m10s elapsed)
azurerm_cosmosdb_account.cosmosdb: Still creating... (1m20s elapsed)
azurerm_cosmosdb_account.cosmosdb: Still creating... (1m30s elapsed)
azurerm_cosmosdb_account.cosmosdb: Still creating... (1m40s elapsed)
azurerm_cosmosdb_account.cosmosdb: Still creating... (1m50s elapsed)
azurerm_cosmosdb_account.cosmosdb: Still creating... (2m0s elapsed)
azurerm_cosmosdb_account.cosmosdb: Creation complete after 2m9s (ID: /subscriptions/63bb1026-[snip]-...databaseAccounts/62c7a6e933648a5e-demo)

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

### Setup IEX Companies ACI deployment
Now that We have a resource group, and Cosmos up and running, it's time to define the Container Instance with the Flask app.  Create a file called aci.tf within the same directory as our previous examples.

```
resource "azurerm_container_group" "iexcompanies" {
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
```

Within the Python Flask app, we are using PyMongo to connect to the CosmosDB instance.  For this though, we need the CosmosDB connection string.

Again, using Terraform's ability to re-use variables, as well as **generated** data, we have constructed the connection string.

The FQDN of any CosmosDB instance is of the form *dbname*:*PRIMARY_KEY*@*dbname*.documents.azure.com, so we can substitute the name of the CosmosDB instance generated during the last run, as well as Terraform knowing what the primary and secondary key is when the Cosmos instance was generated.

Armed with this knowledge, we are able to generate and use the connection string at instantiation time making the entire deployment dynamic.

#### Deploy the Container Instance
We should have a pretty good idea at this point as to what Terraform would plan to do (i.e. only deploy the ACI as we already have the resource group and CosmosDB instance).  So let's go ahead and just deploy:

```
➜  terraform (master) ✗ ~/terraform/terraform apply
random_id.server: Refreshing state... (ID: Ysem6TNkil4)
azurerm_resource_group.terraformonazure: Refreshing state... (ID: /subscriptions/63bb1026-[snip]-...efecb3/resourceGroups/terraformonazure)
azurerm_cosmosdb_account.cosmosdb: Refreshing state... (ID: /subscriptions/63bb1026-[snip]-...databaseAccounts/62c7a6e933648a5e-demo)
azurerm_container_group.aci-iexcompanies: Creating...
  container.#:                                "" => "1"
  container.0.cpu:                            "" => "0.5"
  container.0.environment_variables.%:        "" => "1"
  container.0.environment_variables.COSMOSDB: "" => "mongodb://62c7a6e933648a5e-demo:yvz6tvLnXukG2hqxLooENc2OM1oYztK8[snip]FPReKmg==@62c7a6e933648a5e-demo.documents.azure.com:10255/?ssl=true&replicaSet=globaldb"
  container.0.image:                          "" => "inklin/iexcompanies"
  container.0.memory:                         "" => "1.5"
  container.0.name:                           "" => "iexcompanies"
  container.0.port:                           "" => "80"
  ip_address:                                 "" => "<computed>"
  ip_address_type:                            "" => "public"
  location:                                   "" => "eastus"
  name:                                       "" => "iexcompanies"
  os_type:                                    "" => "linux"
  resource_group_name:                        "" => "terraformonazure"
  tags.%:                                     "" => "1"
  tags.environment:                           "" => "testing"
azurerm_container_group.aci-iexcompanies: Creation complete after 5s (ID: /subscriptions/63bb1026-[snip]-...rInstance/containerGroups/iexcompanies)

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

### Check the ACI deployment and get the IP address
Use the *az* cli, Cloud Shell or the Portal to check on the deployment status.

```
➜  terraform (master) ✗ az container list -g terraformonazure
Name          ResourceGroup     ProvisioningState    Image                IP:ports          CPU/Memory       OsType    Location
------------  ----------------  -------------------  -------------------  ----------------  ---------------  --------  ----------
iexcompanies  terraformonazure  Creating             inklin/iexcompanies  52.170.23.150:80  0.5 core/1.5 gb  Linux     eastus
```

Once the deployment is complete you can ping the endpoint to see if everything is working as expected.

![alt text](images/running.PNG "It works!")

# Destroy!
So that was great, we iterated through and created a 2-tier architecture, a pattern to automate the deployment of a Docker container with a backing service.

Let's destroy all the hard work we have done, so we can shwo the whole working together.

```
➜  terraform (master) ✗ ~/terraform/terraform destroy
random_id.server: Refreshing state... (ID: Ysem6TNkil4)
azurerm_resource_group.terraformonazure: Refreshing state... (ID: /subscriptions/63bb1026-[snip]-...efecb3/resourceGroups/terraformonazure)
azurerm_cosmosdb_account.cosmosdb: Refreshing state... (ID: /subscriptions/63bb1026-[snip]-...databaseAccounts/62c7a6e933648a5e-demo)
azurerm_container_group.aci-iexcompanies: Refreshing state... (ID: /subscriptions/63bb1026-[snip]-...rInstance/containerGroups/iexcompanies)

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  - azurerm_container_group.aci-iexcompanies

  - azurerm_cosmosdb_account.cosmosdb

  - azurerm_resource_group.terraformonazure

  - random_id.server


Plan: 0 to add, 0 to change, 4 to destroy.

Do you really want to destroy?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

azurerm_container_group.aci-iexcompanies: Destroying... (ID: /subscriptions/63bb1026-[snip]-...rInstance/containerGroups/iexcompanies)
azurerm_container_group.aci-iexcompanies: Destruction complete after 3s
azurerm_cosmosdb_account.cosmosdb: Destroying... (ID: /subscriptions/63bb1026-[snip]-...databaseAccounts/62c7a6e933648a5e-demo)

[snip]
```

# Bring it back to life
And let's create the whole thing again now that we have all the architecture defined.

```
➜  terraform (master) ✗ ~/terraform/terraform apply
random_id.server: Creating...
  b64:            "" => "<computed>"
  b64_std:        "" => "<computed>"
  b64_url:        "" => "<computed>"
  byte_length:    "" => "8"
  dec:            "" => "<computed>"
  hex:            "" => "<computed>"
  keepers.%:      "" => "1"
  keepers.azi_id: "" => "1"
random_id.server: Creation complete after 0s (ID: QTw2hOzM4_Q)
azurerm_resource_group.terraformonazure: Creating...
  location: "" => "eastus"
  name:     "" => "terraformonazure"
  tags.%:   "" => "<computed>"
azurerm_resource_group.terraformonazure: Creation complete after 1s (ID: /subscriptions/63bb1026-[snip]-...efecb3/resourceGroups/terraformonazure)
azurerm_cosmosdb_account.cosmosdb: Creating...
  consistency_policy.#:                                 "" => "1"
  consistency_policy.258236697.consistency_level:       "" => "Session"
  consistency_policy.258236697.max_interval_in_seconds: "" => "5"
  consistency_policy.258236697.max_staleness_prefix:    "" => "100"
  failover_policy.#:                                    "" => "1"
  failover_policy.1571414883.id:                        "" => "<computed>"
  failover_policy.1571414883.location:                  "" => "eastus"
  failover_policy.1571414883.priority:                  "" => "0"
  kind:                                                 "" => "MongoDB"
  location:                                             "" => "eastus"
  name:                                                 "" => "413c3684eccce3f4-demo"
  offer_type:                                           "" => "Standard"
  primary_master_key:                                   "" => "<computed>"
  primary_readonly_master_key:                          "" => "<computed>"
  resource_group_name:                                  "" => "terraformonazure"
  secondary_master_key:                                 "" => "<computed>"
  secondary_readonly_master_key:                        "" => "<computed>"
  tags.%:                                               "" => "1"
  tags.tier:                                            "" => "Storage"
azurerm_cosmosdb_account.cosmosdb: Still creating... (10s elapsed)

[snip]
```

# Conclusion
If the only thing you are changing is code in your container, but you need to instantiate infrastructure for your CD pipeline, Terraform is great.

It's great for a whole host of other use-cases, and you can define and deploy infrastructure and Azure 1st party services in a defined, and repeatable fashion till your :heart:'s content!
