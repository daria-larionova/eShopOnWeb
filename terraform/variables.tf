variable "topic" {
  type        = string
  description = "The topic of the task from training in kebab-case, for example - app-services"
  validation {
    condition     = can(regex("^([a-z]*)(-[a-z]+)*$", var.topic))
    error_message = "Error: Topic must be in kebab-case, for example: app-services."
  }
}

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
    sku_code = string
    has_deployment_slot = bool
  }))
  default = [
    { name = "public-api", region = "eastus", sku_code = "S1", has_deployment_slot = false },
    { name = "web-app-1", region = "eastus", sku_code = "P1v2", has_deployment_slot = true },
    { name = "web-app-2", region = "westus", sku_code = "P1v2", has_deployment_slot = false }
  ]
 }

  variable "db_username" {
    description = "Database administrator username"
    type        = string
    sensitive   = true
  }

  variable "db_password" {
    description = "Database administrator password"
    type        = string
    sensitive   = true
  }

  variable "databases"  {
    description = "List of databases to create in SQL Server."
    type = list(string)
    default = ["CatalogDb", "Identity"]
  }