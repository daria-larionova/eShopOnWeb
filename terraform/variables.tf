variable "prefix" {
  type        = string
  description = "The prefix used for all resources"
  default = "azure-training"
}

variable "app_name" {
  type        = string
  description = "Application name to deploy"
  default = "e-shop"
}

variable "default_region" {
  type        = string
  description = "The Azure region where all resources should be created by default"
  default = "eastus"
}

variable "os_type" {
  type        = string
  description = "OS type for Web App"
  default = "Windows"
}

 variable "web_apps"  {
  description = "List of all web apps to create with a region and tiers."
  type = list(object({
    name = string
    region = string
    traffic_manager_endpoint_name = string
    traffic_manager_geo_mapping = string
    sku_code = string
    has_deployment_slot = bool
    enable_app_insights = bool
  }))
  default = [
    #{ name = "public-api", region = "eastus", sku_code = "S1", has_deployment_slot = false, enable_app_insights = false },
    { name = "web-app-1", region = "eastus", traffic_manager_endpoint_name="Europe", traffic_manager_geo_mapping="GEO-EU", sku_code = "P1v2", has_deployment_slot = false, enable_app_insights = false },
    { name = "web-app-2", region = "westus", traffic_manager_endpoint_name="Others", traffic_manager_geo_mapping="WORLD", sku_code = "P1v2", has_deployment_slot = true, enable_app_insights = false }
  ]
 }

 variable "databases"  {
    description = "List of databases to create in SQL Server."
    type = list(string)
    default = ["CatalogDb", "Identity"]
  }

  variable "db_username"  {
    type = string
  }

  variable "db_password"  {
    type = string
  }

  variable "logic_app_endpoint"  {
    type = string
  }