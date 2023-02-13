terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.43.0"
    }
  }
  # after_hook "after_hook" {
  #   commands     = ["apply", "plan"]
  #   execute      = ["echo", "Finished running Terraform"]
  #   run_on_error = true
  # }
}
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = var.default_region
}

#Service Plans
resource "azurerm_service_plan" "web_app_sp" {
  for_each = {for idx, web_app in var.web_apps: idx => web_app} 

  name                = "${var.app_name}-${each.value.name}-sp"
  location            = each.value.region
  resource_group_name = azurerm_resource_group.main.name
  os_type             = var.os_type
  sku_name            = each.value.sku_code
}

#SQL Server with databases
resource "azurerm_mssql_server" "sql_server" {
  name                         = "${var.app_name}-db-server-1"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  administrator_login          = var.db_username
  administrator_login_password = var.db_password
  public_network_access_enabled = true
  minimum_tls_version          = "1.2"
  version                      = "12.0"
}

resource "azurerm_mssql_firewall_rule" "mssql_firewall_rule" {
  name             = "AllowAzureServicesAccess"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_database" "database" {
  for_each = toset(var.databases)

  name           = each.value
  server_id      = azurerm_mssql_server.sql_server.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb    = 1
  read_scale     = false
  sku_name       = "Basic"
  zone_redundant = false  
  storage_account_type = "Local"
  min_capacity = 1
  auto_pause_delay_in_minutes = 60
  geo_backup_enabled = true
}

data "azurerm_client_config" "current" {
}

# Create app insights
# resource "azurerm_application_insights" "app_insights" {
#   for_each = { for k,v in var.web_apps : k => v if v.enable_app_insights } #Create app insights to specific web apps only

#   name                = "${each.value.name}-app-insights"
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
#   application_type    = "web"

# }

#Key Valut
resource "azurerm_key_vault" "key_vault" {
  name                       = "${var.app_name}-keyvault-5"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
      "List",
      "Create",
      "Update",
      "Delete",
      "Recover"
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover"
    ]
  }
}

resource "azurerm_key_vault_secret" "db-connection-strings" {
  for_each = {for idx, database in var.databases: idx => database} 

  name         = "${each.value}-db-connection-string"
  value        = "Server=tcp:${azurerm_mssql_server.sql_server.fully_qualified_domain_name},1433;Initial Catalog=${each.value};Persist Security Info=False;User ID=${azurerm_mssql_server.sql_server.administrator_login};Password=${azurerm_mssql_server.sql_server.administrator_login_password};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.key_vault.id
}

#Service Bus
resource "azurerm_servicebus_namespace" "service_bus" {
  name                = "${var.app_name}-service-bus"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
}

resource "azurerm_servicebus_topic" "servicebus_topic" {
  name         = "orders"
  namespace_id = azurerm_servicebus_namespace.service_bus.id

  enable_partitioning = true
}

resource "azurerm_role_assignment" "servicebus_topic_role_assignment" {
  scope = azurerm_servicebus_namespace.service_bus.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id = azurerm_windows_function_app.function_app.identity[0].principal_id
}

resource "azurerm_servicebus_subscription" "servicebus_subscription" {
  name         = "function-app-subscription"
  topic_id           = azurerm_servicebus_topic.servicebus_topic.id
  max_delivery_count = 100
}

resource "azurerm_key_vault_secret" "service-bus-connection-string" {
  name         = "service-bus-connection-string"
  value        = azurerm_servicebus_namespace.service_bus.default_primary_connection_string
  key_vault_id = azurerm_key_vault.key_vault.id
}

#Cosmos DB
resource "azurerm_cosmosdb_account" "cosmosdb_account" {
  name                = "${var.app_name}-cosmos-db"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  is_virtual_network_filter_enabled = false
  enable_multiple_write_locations = false
  enable_free_tier = true

  consistency_policy {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }

  capacity  {
      total_throughput_limit = 1000
  }

  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }
  
  backup {
    type = "Periodic"
    interval_in_minutes = 1440
    retention_in_hours = 48
    storage_redundancy = "Geo"
  }
}

resource "azurerm_cosmosdb_sql_database" "cosmosdb_sql_database" {
  name                = "DeliveryDb"
  resource_group_name = azurerm_cosmosdb_account.cosmosdb_account.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmosdb_account.name
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "cosmosdb_sql_container" {
  name                = "DeliveryItems"
  resource_group_name = azurerm_cosmosdb_account.cosmosdb_account.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmosdb_account.name
  database_name       = azurerm_cosmosdb_sql_database.cosmosdb_sql_database.name
  partition_key_path  = "/id"
}

resource "azurerm_key_vault_secret" "cosmos-db-connection-string" {
  name         = "cosmos-db-connection-string"
  value        = azurerm_cosmosdb_account.cosmosdb_account.primary_sql_connection_string
  key_vault_id = azurerm_key_vault.key_vault.id
}


#Logic App (manual)
resource "azurerm_key_vault_secret" "logic-app-endpoint" {
  name         = "logic-app-endpoint"
  value        = var.logic_app_endpoint
  key_vault_id = azurerm_key_vault.key_vault.id
}

#Warehouse Storage and Functions
resource "azurerm_storage_account" "storage_account" {
  name                     = "eshopwhsa"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "storage_container" {
  name                  = "warehouse"
  storage_account_name  = azurerm_storage_account.storage_account.name
  container_access_type = "private"
}

resource "azurerm_service_plan" "function_sp" {
  name                = "${var.app_name}-warehouse-sp"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = var.os_type
  sku_name            = "S1"
}

resource "azurerm_key_vault_secret" "warehouse-connection-string" {
  name         = "warehouse-connection-string"
  value        = azurerm_storage_account.storage_account.primary_connection_string
  key_vault_id = azurerm_key_vault.key_vault.id
}

resource "azurerm_windows_function_app" "function_app" {
  name                = "${var.app_name}-warehouse-function-app"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
  service_plan_id            = azurerm_service_plan.function_sp.id

  site_config {
    always_on = true
    remote_debugging_enabled = true
    remote_debugging_version = "VS2022"
  }
  app_settings = {
    "blobStorageConnectionString" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.warehouse-connection-string.id})"
    "cosmosDbConnectionString" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.cosmos-db-connection-string.id})"
    "logicAppEndpoint" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.logic-app-endpoint.id})"
    "serviceBusConnectionString" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.service-bus-connection-string.id})",
    "blobStorageContainerName"= "warehouse",
    "cosmosDbContainerName"= "DeliveryItems",
    "cosmosDbDatabaseName"= "DeliveryDb",
    "cosmosDbPartitionKey"= "/id",
  }
  
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "function_app_role_assignment" {
  scope = azurerm_windows_function_app.function_app.id
  role_definition_name = "Key Vault Reader"
  principal_id = data.azurerm_client_config.current.object_id
}

#Web Apps
resource "azurerm_windows_web_app" "web_app" {
  for_each = {for idx, web_app in var.web_apps: idx => web_app} 

  name                = "${var.app_name}-${each.value.name}"
  location            = each.value.region
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.web_app_sp[each.key].id

  identity {
    type = "SystemAssigned"
  }

  site_config {}

  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = "Development"
    "${azurerm_key_vault_secret.db-connection-strings[0].name}" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db-connection-strings[0].id})"
    "${azurerm_key_vault_secret.db-connection-strings[1].name}" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db-connection-strings[1].id})"
    "ServiceBusConnectionString" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.service-bus-connection-string.id})"
  }

  connection_string {
    name = azurerm_key_vault_secret.db-connection-strings[0].name
    type = "SQLServer"
    value = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db-connection-strings[0].id})"
  }

  connection_string {
    name = azurerm_key_vault_secret.db-connection-strings[1].name
    type = "SQLServer"
    value = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.db-connection-strings[1].id})"
  }
}

resource "azurerm_role_assignment" "web_app_role_assignment" {
  for_each = {for idx, web_app in azurerm_windows_web_app.web_app: idx => web_app} 

  scope = each.value.id
  role_definition_name = "Key Vault Reader"
  principal_id = data.azurerm_client_config.current.object_id
}

#Deployment Slots
resource "azurerm_windows_web_app_slot" "deployment_slot" {
  for_each = { for k,v in var.web_apps : k => v if v.has_deployment_slot } #Add deployment to specific web apps only

  name           = "stage"
  app_service_id = azurerm_windows_web_app.web_app[each.key].id

  site_config {}
}


#Traffic Manager

resource "azurerm_traffic_manager_profile" "traffic_manager" {
  name                   = "${var.app_name}-traffic-manager"
  resource_group_name    = azurerm_resource_group.main.name
  traffic_routing_method = "Geographic"

  dns_config {
    relative_name = "${var.app_name}-traffic-manager"
    ttl           = 100
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }
}

# resource "azurerm_app_service_custom_hostname_binding" "web_services_custom_domain_binding" {
#   hostname            = data.azurerm_traffic_manager_profile.traffic_manager.endpoint
#   app_service_name    = "${azurerm_app_service.test.name}"
#   resource_group_name = "${azurerm_resource_group.test.name}"
# }

resource "azurerm_traffic_manager_azure_endpoint" "traffic_manager_endpoint" {
  for_each = {for idx, web_app in var.web_apps: idx => web_app} 

  name               = "${each.value.traffic_manager_endpoint_name}-endpoint"
  profile_id         = azurerm_traffic_manager_profile.traffic_manager.id
  weight             = 100
  geo_mappings       = ["${each.value.traffic_manager_geo_mapping}"]
  target_resource_id = azurerm_windows_web_app.web_app[each.key].id
}

resource "azurerm_key_vault_access_policy" "web_app_key_vault_access_policy" {
  for_each = {for idx, web_app in azurerm_windows_web_app.web_app: idx => web_app} 

  key_vault_id = azurerm_key_vault.key_vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = each.value.identity[0].principal_id

  key_permissions = [
    "Get",
  ]

  secret_permissions = [
    "Get",
  ]
}

resource "azurerm_key_vault_access_policy" "function_app_key_vault_access_policy" {
  key_vault_id = azurerm_key_vault.key_vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_windows_function_app.function_app.identity[0].principal_id

  key_permissions = [
    "Get",
  ]

  secret_permissions = [
    "Get",
  ]
}


