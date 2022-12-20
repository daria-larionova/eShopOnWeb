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

#Create app insights
resource "azurerm_application_insights" "app_insights" {
  for_each = { for k,v in var.web_apps : k => v if v.enable_app_insights } #Create app insights to specific web apps only

  name                = "${each.value.name}-app-insights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"

}

#Web Apps
resource "azurerm_windows_web_app" "web_app" {
  for_each = {for idx, web_app in var.web_apps: idx => web_app} 

  name                = "${var.app_name}-${each.value.name}"
  location            = each.value.region
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.web_app_sp[each.key].id

  site_config {}
  
  app_settings = each.value.enable_app_insights ? {

    #App Insights Settings
    APPINSIGHTS_INSTRUMENTATIONKEY = "${azurerm_application_insights.app_insights[each.key].instrumentation_key}"
    APPINSIGHTS_PROFILERFEATURE_VERSION = "disabled"
    APPINSIGHTS_SNAPSHOTFEATURE_VERSION = "disabled"
    APPLICATIONINSIGHTS_CONNECTION_STRING = "${azurerm_application_insights.app_insights[each.key].connection_string}"
    ApplicationInsightsAgent_EXTENSION_VERSION = "~2"
    DiagnosticServices_EXTENSION_VERSION = "disabled"
    InstrumentationEngine_EXTENSION_VERSION = "disabled"
    SnapshotDebugger_EXTENSION_VERSION = "disabled"
    XDT_MicrosoftApplicationInsights_BaseExtensions = "disabled"
    XDT_MicrosoftApplicationInsights_PreemptSdk = "disabled"
    XDT_MicrosoftApplicationInsights_Mode = "default"
    ###

  } : {}
}

#Map source control
resource "azurerm_app_service_source_control" "example" {
  for_each = {for idx, web_app in var.web_apps: idx => web_app} 

  app_id   = azurerm_windows_web_app.web_app[each.key].id
  repo_url = var.repo_url
  branch   = var.repo_branch
}

#Deployment Slots
resource "azurerm_windows_web_app_slot" "deployment_slot" {
  for_each = { for k,v in var.web_apps : k => v if v.has_deployment_slot } #Add deployment to specific web apps only

  name           = "stage"
  app_service_id = azurerm_windows_web_app.web_app[each.key].id

  site_config {}
}