terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.36.0"
    }
  }
}
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-${var.topic}-rg"
  location = var.default_region
}

#SQL Server with databases
resource "azurerm_mssql_server" "sql_server" {
  name                         = "${var.app_name}-db-server"
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
  sku_name       = "GP_S_Gen5_1"
  zone_redundant = false  
  storage_account_type = "Local"
  min_capacity = 1
  auto_pause_delay_in_minutes = 60
  geo_backup_enabled = false
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

#Web Apps
resource "azurerm_windows_web_app" "web_app" {
  for_each = {for idx, web_app in var.web_apps: idx => web_app} 

  name                = "${var.app_name}-${each.value.name}"
  location            = each.value.region
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.web_app_sp[each.key].id

  site_config {}
}

#Deployment Slots
resource "azurerm_windows_web_app_slot" "deployment_slot" {
  for_each = { for k,v in var.web_apps : k => v if v.has_deployment_slot } #Add deployment to specific web apps only

  name           = "stage"
  app_service_id = azurerm_windows_web_app.web_app[each.key].id

  site_config {}
}