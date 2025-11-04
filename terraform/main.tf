terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "~>1.0"
    }
  }
}

provider "azuredevops" {
  org_service_url       = "https://dev.azure.com/contactuzmarazzaq"
  personal_access_token = var.azure_devops_pat
}

provider "azurerm" {
  features {}
}

# ---------------------------
# Resource Group
# ---------------------------
resource "azurerm_resource_group" "rg" {
  name     = "mirror-rg"
  location = "West US" # Changed from East US (East is restricted for free accounts)
}

# ---------------------------
# Random suffix for unique names
# ---------------------------
resource "random_integer" "suffix" {
  min = 10000
  max = 99999
}

# ---------------------------
# Azure Container Registry (ACR)
# ---------------------------
# ---------------------------
# Azure Container Registry
# ---------------------------
resource "azurerm_container_registry" "acr" {
  name                = "mirroracr${random_integer.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}


# ---------------------------
# PostgreSQL Flexible Server
# ---------------------------
resource "random_password" "pg_password" {
  length  = 12
  special = false
}

resource "azurerm_postgresql_flexible_server" "pg" {
  name                   = "mirrorpg${random_integer.suffix.result}"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  administrator_login    = "pgadmin"
  administrator_password = random_password.pg_password.result
  version                = "14"
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"
}


# Allow public access (for now — not secure for production)
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
  name             = "allow_all"
  server_id        = azurerm_postgresql_flexible_server.pg.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# ---------------------------
# Azure Kubernetes Service (AKS)
# ---------------------------
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "mirror-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "mirroraks"

  default_node_pool {
  name       = "default"
  node_count = 1
  vm_size    = "Standard_B4ms" # 4 vCPUs, 16 GB RAM
}


  identity {
    type = "SystemAssigned"
  }

  # Ensure ACR exists first
  depends_on = [azurerm_container_registry.acr]
}

# ---------------------------
# Grant AKS permission to pull from ACR
# ---------------------------
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

# ---------------------------
# Outputs
# ---------------------------
output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "pg_fqdn" {
  value = azurerm_postgresql_flexible_server.pg.fqdn
}

output "pg_user" {
  value = azurerm_postgresql_flexible_server.pg.administrator_login
}

output "pg_password" {
  value     = random_password.pg_password.result
  sensitive = true
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "aks_kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}
output "postgres_connection_url" {
  description = "Complete PostgreSQL connection URL"
  value = format(
    "postgres://%s:%s@%s:5432/postgres?sslmode=require",
    azurerm_postgresql_flexible_server.pg.administrator_login,
    random_password.pg_password.result,
    azurerm_postgresql_flexible_server.pg.fqdn
  )
  sensitive = true
}

# ---------------------------
# Azure DevOps Project
# ---------------------------

# ---------------------------
# GitHub Service Connection
# ---------------------------
data "azuredevops_project" "mirror_project" {
  name = "mirror-app"
}


# ---------------------------
# Azure Pipeline (YAML-based)
# ---------------------------
# resource "azuredevops_build_definition" "mirror_pipeline" {
#   project_id = data.azuredevops_project.mirror_project.id

#   name       = "Word Mirror API CI Pipeline"

#   ci_trigger {
#     use_yaml = true
#   }

#   repository {
#     repo_type   = "GitHub"
#     repo_id   = "alphadev4/word-mirror-api"
#     branch_name = "master"
#     yml_path    = "terraform/azure-pipelines.yml"
#   }
# }
