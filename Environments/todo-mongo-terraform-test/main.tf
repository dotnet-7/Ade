locals {
  tags                         = { azd-env-name : var.environment_name }
  sha                          = base64encode(sha256("${var.environment_name}${var.location}${data.azurerm_client_config.current.subscription_id}"))
  resource_token               = substr(replace(lower(local.sha), "[^A-Za-z0-9_]", ""), 0, 13)
  cosmos_connection_string_key = "AZURE-COSMOS-CONNECTION-STRING"
  runtimeName                  = var.repoUrl == "https://github.com/Azure-Samples/todo-nodejs-mongo-terraform" ? "nodejs" : "python"
}
# ------------------------------------------------------------------------------------------------------
# Deploy resource Group
# ------------------------------------------------------------------------------------------------------
variable "resource_group_name" {}



data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}
# resource "azurecaf_name" "rg_name" {
#   name          = var.environment_name
#   resource_type = "azurerm_resource_group"
#   random_length = 0
#   clean_input   = true
# }

# resource "azurerm_resource_group" "rg" {
#   name     = azurecaf_name.rg_name.result
#   location = var.location

#   tags = local.tags
# }

# ------------------------------------------------------------------------------------------------------
# Deploy application insights
# ------------------------------------------------------------------------------------------------------
module "applicationinsights" {
  source           = "./modules/applicationinsights"
  location         = var.location
  rg_name          = data.azurerm_resource_group.rg.name
  environment_name = var.environment_name
  workspace_id     = module.loganalytics.LOGANALYTICS_WORKSPACE_ID
  tags             = local.tags
  resource_token   = local.resource_token
}

# ------------------------------------------------------------------------------------------------------
# Deploy log analytics
# ------------------------------------------------------------------------------------------------------
module "loganalytics" {
  source         = "./modules/loganalytics"
  location       = var.location
  rg_name        = data.azurerm_resource_group.rg.name
  tags           = local.tags
  resource_token = local.resource_token
}

# ------------------------------------------------------------------------------------------------------
# Deploy key vault
# ------------------------------------------------------------------------------------------------------
module "keyvault" {
  source                   = "./modules/keyvault"
  location                 = var.location
  principal_id             = var.principal_id
  rg_name                  = data.azurerm_resource_group.rg.name
  tags                     = local.tags
  resource_token           = local.resource_token
  access_policy_object_ids = [var.environment_principal_id]
  secrets = [
    {
      name  = local.cosmos_connection_string_key
      value = module.cosmos.AZURE_COSMOS_CONNECTION_STRING
    },
    {
      name  = "principalId"
      value = local.runtimeName == "nodejs" ? try(module.api_node.IDENTITY_PRINCIPAL_ID, "") : try(module.api_python.IDENTITY_PRINCIPAL_ID, "")
    }
  ]
  depends_on = [module.api]
}

# ------------------------------------------------------------------------------------------------------
# Deploy cosmos
# ------------------------------------------------------------------------------------------------------
module "cosmos" {
  source         = "./modules/cosmos"
  location       = var.location
  rg_name        = data.azurerm_resource_group.rg.name
  tags           = local.tags
  resource_token = local.resource_token
}

# ------------------------------------------------------------------------------------------------------
# Deploy app service plan
# ------------------------------------------------------------------------------------------------------
module "appserviceplan" {
  source         = "./modules/appserviceplan"
  location       = var.location
  rg_name        = data.azurerm_resource_group.rg.name
  tags           = local.tags
  resource_token = local.resource_token
}

# ------------------------------------------------------------------------------------------------------
# Deploy app service web app
# ------------------------------------------------------------------------------------------------------
module "web" {
  source         = "./modules/appservicenode"
  location       = var.location
  rg_name        = data.azurerm_resource_group.rg.name
  resource_token = local.resource_token

  tags               = merge(local.tags, { azd-service-name : "web" })
  service_name       = "web"
  appservice_plan_id = module.appserviceplan.APPSERVICE_PLAN_ID

  app_settings = {
    "SCM_DO_BUILD_DURING_DEPLOYMENT"                  = "false"
    "REACT_APP_APPLICATIONINSIGHTS_CONNECTION_STRING" = module.applicationinsights.APPLICATIONINSIGHTS_CONNECTION_STRING
    "REACT_APP_API_BASE_URL"                          = "https://app-api-${local.resource_token}.azurewebsites.net"
  }

  app_command_line = "./entrypoint.sh -o ./env-config.js && pm2 serve /home/site/wwwroot --no-daemon --spa"
}

# ------------------------------------------------------------------------------------------------------
# Deploy app service api
# ------------------------------------------------------------------------------------------------------


module "api" {
  source = "./api"
}




# ------------------------------------------------------------------------------------------------------
# Deploy app service apim
# ------------------------------------------------------------------------------------------------------
module "apim" {
  count                     = var.useAPIM ? 1 : 0
  source                    = "./modules/apim"
  name                      = "apim-${local.resource_token}"
  location                  = var.location
  rg_name                   = data.azurerm_resource_group.rg.name
  tags                      = merge(local.tags, { "azd-service-name" : var.environment_name })
  application_insights_name = module.applicationinsights.APPLICATIONINSIGHTS_NAME
  sku                       = "Consumption"
}

# ------------------------------------------------------------------------------------------------------
# Deploy app service apim-api
# ------------------------------------------------------------------------------------------------------
module "apimApi" {
  count                    = var.useAPIM ? 1 : 0
  source                   = "./modules/apim-api"
  name                     = module.apim[0].APIM_SERVICE_NAME
  rg_name                  = data.azurerm_resource_group.rg.name
  web_front_end_url        = module.web.URI
  api_management_logger_id = module.apim[0].API_MANAGEMENT_LOGGER_ID
  api_name                 = "todo-api"
  api_display_name         = "Simple Todo API"
  api_path                 = "todo"
  api_backend_url          = local.runtimeName == "nodejs" ? try(module.api_node.URI, "") : try(module.api_python.URI, "")
}