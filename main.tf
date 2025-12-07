########################
# Resource Group
########################

resource "azurerm_resource_group" "rg" {
  name     = "${var.project_name}-rg"
  location = var.location
}

########################
# Storage Account
########################

resource "azurerm_storage_account" "sa" {
  name                     = "${var.project_name}sa1234" # must be globally unique, lowercase + numbers
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"
}

########################
# Service Plan (Consumption)
########################

resource "azurerm_service_plan" "plan" {
  name                = "${var.project_name}-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  os_type  = "Linux"
  sku_name = "Y1" # Consumption
}

########################
# Application Insights
########################

resource "azurerm_application_insights" "ai" {
  name                = "${var.project_name}-ai"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  application_type    = "other"
}

########################
# Key Vault + Secrets
########################

resource "azurerm_key_vault" "kv" {
  name                        = "${var.project_name}-kv"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = false
  soft_delete_retention_days  = 7

  # You (current user/service principal) need access to create secrets
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = ["Get", "List", "Set", "Delete"]
  }
}

# Store all AOAI settings as secrets

resource "azurerm_key_vault_secret" "aoai_endpoint" {
  name         = "azure-openai-endpoint"
  value        = var.azure_openai_endpoint
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "aoai_api_key" {
  name         = "azure-openai-api-key"
  value        = var.azure_openai_api_key
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "aoai_deployment" {
  name         = "azure-openai-deployment"
  value        = var.azure_openai_deployment
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "aoai_api_version" {
  name         = "azure-openai-api-version"
  value        = var.azure_openai_api_version
  key_vault_id = azurerm_key_vault.kv.id
}

########################
# Zip package of the Function
########################

data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../gpt-function"
  output_path = "${path.module}/function.zip"
}

########################
# Linux Function App
########################

resource "azurerm_linux_function_app" "func" {
  name                = "${var.project_name}-func"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  service_plan_id            = azurerm_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key

  https_only                  = true
  functions_extension_version = "~4"

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  # System-assigned identity for Key Vault access
  identity {
    type = "SystemAssigned"
  }

  # App settings use Key Vault references
  app_settings = {
    FUNCTIONS_WORKER_RUNTIME               = "python"
    AzureWebJobsFeatureFlags               = "EnableWorkerIndexing"
    APPINSIGHTS_INSTRUMENTATIONKEY         = azurerm_application_insights.ai.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING  = azurerm_application_insights.ai.connection_string

    # Key Vault references (Function will resolve via its managed identity)
    AZURE_OPENAI_ENDPOINT    = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.aoai_endpoint.id})"
    AZURE_OPENAI_API_KEY     = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.aoai_api_key.id})"
    AZURE_OPENAI_DEPLOYMENT  = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.aoai_deployment.id})"
    AZURE_OPENAI_API_VERSION = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.aoai_api_version.id})"
  }

  # Zip deploy: pushes gpt-function as an artifact
  zip_deploy_file = data.archive_file.function_zip.output_path
}

########################
# Key Vault access for Function App identity
########################

resource "azurerm_key_vault_access_policy" "func_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_function_app.func.identity.principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}
