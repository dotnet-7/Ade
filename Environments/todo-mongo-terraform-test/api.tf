module "api_node" {
  count          = local.runtimeName == "nodejs" ? 1 : 0
  source         = "./modules/appservicenode"
  location       = var.location
  rg_name        = data.azurerm_resource_group.rg.name
  resource_token = local.resource_token

  tags               = merge(local.tags, { "azd-service-name" : "api" })
  service_name       = "api"
  appservice_plan_id = module.appserviceplan.APPSERVICE_PLAN_ID
  app_settings = {
    "AZURE_COSMOS_CONNECTION_STRING_KEY"    = local.cosmos_connection_string_key
    "AZURE_COSMOS_DATABASE_NAME"            = module.cosmos.AZURE_COSMOS_DATABASE_NAME
    "SCM_DO_BUILD_DURING_DEPLOYMENT"        = "true"
    "AZURE_KEY_VAULT_ENDPOINT"              = module.keyvault.AZURE_KEY_VAULT_ENDPOINT
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = module.applicationinsights.APPLICATIONINSIGHTS_CONNECTION_STRING
    "API_ALLOW_ORIGINS"                     = "https://app-web-${local.resource_token}.azurewebsites.net"
  }

  app_command_line = ""

  identity = [{
    type = "SystemAssigned"
  }]
}
module "api_python" {
  count          = local.runtimeName == "python" ? 1 : 0
  source         = "./modules/appservicepython"
  location       = var.location
  rg_name        = data.azurerm_resource_group.rg.name
  resource_token = local.resource_token

  tags               = merge(local.tags, { "azd-service-name" : "api" })
  service_name       = "api"
  appservice_plan_id = module.appserviceplan.APPSERVICE_PLAN_ID
  app_settings = {
    "AZURE_COSMOS_CONNECTION_STRING_KEY"    = local.cosmos_connection_string_key
    "AZURE_COSMOS_DATABASE_NAME"            = module.cosmos.AZURE_COSMOS_DATABASE_NAME
    "SCM_DO_BUILD_DURING_DEPLOYMENT"        = "true"
    "AZURE_KEY_VAULT_ENDPOINT"              = module.keyvault.AZURE_KEY_VAULT_ENDPOINT
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = module.applicationinsights.APPLICATIONINSIGHTS_CONNECTION_STRING
    "API_ALLOW_ORIGINS"                     = "https://app-web-${local.resource_token}.azurewebsites.net"
  }

  app_command_line = ""

  identity = [{
    type = "SystemAssigned"
  }]
}