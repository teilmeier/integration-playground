// Defines the infrastructure that consits of
// - An Azure App Service with a Basic Plan (B1)
// - An Azure Function App with a Consumption Plan
// - An Logic App Standard on a WS1 Plan
// - Other needed resources like storage accounts, app insights, etc.
//
// The infrastructure is deployed to a resource group
// that is created if it does not exist.
//
// The infrastructure is deployed with the following naming convention:
// - <prefix>-<environment>-<resource>

param location string = 'northeurope'
param prefix string = 'integration'
param environment string = 'dev'

var randomPostfix = substring(uniqueString(prefix, environment, location), 0, 5)

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${prefix}${environment}strg${randomPostfix}'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}

resource loganalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${prefix}-${environment}-loganalytics'
  location: location
  properties: {
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${prefix}-${environment}-appinsights'
  location: location
  properties: {
    WorkspaceResourceId: loganalyticsWorkspace.id
    Application_Type: 'web'
  }
  kind: 'web'
}

resource eventGridTopic 'Microsoft.EventGrid/topics@2022-06-15' = {
  name: '${prefix}-${environment}-eventgridtopic'
  location: location
  properties: {
    inputSchema: 'CloudEventSchemaV1_0'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${prefix}-${environment}-appserviceplan'
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
}

resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${prefix}-${environment}-webapp'
  location: location
  kind: 'web'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'SalesOrderApiUri'
          value: 'https://${functionApp.properties.defaultHostName}/api/PublishOrderEvent'
        }
        {
          name: 'SalesOrderApiKeyParam'
          value: 'x-functions-key'
        }
        {
          name: 'SalesOrderApiKeyValue'
          value: functionAppHost.listKeys().functionKeys.default
        }
      ]
    }
  }
}

resource functionAppPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${prefix}-${environment}-functionappplan'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${prefix}-${environment}-functionapp'
  location: location
  kind: 'functionapp'
  properties: {
    serverFarmId: functionAppPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'EVENTGRID_TOPICKEY'
          value: eventGridTopic.listKeys().key1
        }
        {
          name: 'EVENTGRID_URI'
          value: eventGridTopic.properties.endpoint
        }
      ]
    }
  }
}

resource functionAppHost 'Microsoft.Web/sites/host@2022-09-01' existing = {
  name: 'default'
  parent: functionApp
}

resource logicAppPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${prefix}-${environment}-logicappplan'
  location: location
  sku: {
    tier: 'WorkflowStandard'
    name: 'WS1'
  }
  properties: {
    targetWorkerCount: 1
    maximumElasticWorkerCount: 1
    elasticScaleEnabled: true
    isSpot: false
  }
}

resource logicapp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${prefix}-${environment}-logicapp'
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: '${prefix}-${environment}-logicapp'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: '[1.*, 2.0.0)'
        }
        {
          name: 'APP_KIND'
          value: 'workflowApp'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'WORKFLOWS_SUBSCRIPTION_ID'
          value: subscription().subscriptionId
        }
        {
          name: 'WORKFLOWS_LOCATION_NAME'
          value: location
        }
        {
          name: 'WORKFLOWS_RESOURCE_GROUP_NAME'
          value: resourceGroup().name
        }
        {
          name: 'EVENTGRID_CONNECTIONRUNTIMEURL'
          value: eventGridConnection.properties.connectionRuntimeUrl
        }
        {
          name: 'EVENTGRID_CONNECTIONNAME'
          value: '${prefix}-${environment}-eventgridconnection'
        }
        {
          name: 'EVENTGRID_TOPICNAME'
          value: '${prefix}-${environment}-eventgridtopic'
        }
        {
          name: 'EVENTGRID_SUBSCRIPTIONNAME'
          value: '${prefix}-${environment}-eventgridsubscription'
        }
      ]
      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
      netFrameworkVersion: 'v6.0'
    }
    serverFarmId: logicAppPlan.id
    clientAffinityEnabled: false
  }
}

resource eventGridConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: '${prefix}-${environment}-eventgridconnection'
  location: location
  kind: 'V2'
  properties: {
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/azureeventgrid'
    }
    displayName: '${prefix}-${environment}-eventgridconnection'
    parameterValueType: 'Alternative' // Managed Identity
  }
}

resource eventGridConnectionAccessPolicy 'Microsoft.Web/connections/accessPolicies@2016-06-01' = {
  name: '${prefix}-${environment}-eventgridconnectionaccesspolicy'
  parent: eventGridConnection
  location: location
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: subscription().tenantId
        objectId: logicapp.identity.principalId
      }
    }
  }
}

resource eventGridSubscriptionContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '428e0ff0-5e57-4d9c-a221-2c70d0e0a443'
}
resource eventGridSubscriptionContributoroleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(eventGridTopic.id, resourceGroup().id, logicapp.id)
  scope: eventGridTopic
  properties: {
    principalId: logicapp.identity.principalId
    roleDefinitionId: eventGridSubscriptionContributor.id
  }
}
