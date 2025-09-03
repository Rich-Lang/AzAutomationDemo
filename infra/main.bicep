@description('Location for all resources.')
param location string = resourceGroup().location

@description('Storage account name (3-24 lowercase letters/numbers).')
param storageAccountName string

@description('Automation Account name.')
param automationAccountName string

@description('Container name for blob storage.')
param containerName string = 'exports'

@description('Optional tags applied to all resources.')
param tags object = {}

// Storage Account
resource stg 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
  tags: tags
}



resource automationAccount 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  identity: {
    type: 'SystemAssigned'
  }
  name: automationAccountName
  location: location
  properties: {
    disableLocalAuth: false
    publicNetworkAccess: true
    sku: {
      name: 'Free'
    }
  }
  tags: tags
}

// Automation variables (loop). clientSecret is a placeholder and marked encrypted.
var automationVariables = [
  {
    name: 'resourceGroup'
    value: resourceGroup().name
    encrypted: false
  }
  {
    name: 'storageAccountName'
    value: storageAccountName
    encrypted: false
  }
  {
    name: 'containerName'
    value: containerName
    encrypted: false
  }
  {
    name: 'clientId' // Only used by readUsersWriteStorage_AppRegistration.ps1
    value: 'PLACEHOLDER-CLIENT-ID' // Replace manually or via secure process post-deploy
    encrypted: false
  }
  {
    name: 'clientSecret' // Only used by readUsersWriteStorage_AppRegistration.ps1
    value: 'PLACEHOLDER-SECRET' // Replace manually or via secure process post-deploy
    encrypted: true
  }
  {
    name: 'tenantId' // Only used by readUsersWriteStorage_AppRegistration.ps1
    value: tenant().tenantId
    encrypted: false
  }
]

resource automationAccountVariables 'Microsoft.Automation/automationAccounts/variables@2024-10-23' = [for v in automationVariables: {
  parent: automationAccount
  name: v.name
  properties: {
    isEncrypted: v.encrypted
    value: '"${v.value}"'
  }
}]

var artifactsLocation string = 'https://raw.githubusercontent.com/Rich-Lang/AzAutomationDemo/refs/heads/main/scripts/'

// Runbook metadata collection
var runbooks = [
  {
    name: 'a_HelloWorld'
    file: 'justHelloWorld.ps1'
    description: 'Literally just print Hello World'
  }
  {
    name: 'b_ReadUsers'
    file: 'readUsers.ps1'
    description: 'Reads all Users from Entra'
  }
  {
    name: 'c_WriteStorage'
    file: 'writeStorage.ps1'
    description: 'Writes a file to Azure Blob Storage'
  }
  {
    name: 'd_ReadUsersWriteStorage'
    file: 'readUsersWriteStorage.ps1'
    description: 'Reads users and writes to Azure Blob Storage'
  }
  {
    name: 'e_ReadUsersWriteStorage_AppRegistration'
    file: 'readUsersWriteStorage_AppRegistration.ps1'
    description: 'Reads users and writes to Azure Blob Storage (App Registration)'
  }
]

resource runbookResources 'Microsoft.Automation/automationAccounts/runbooks@2023-11-01' = [for rb in runbooks: {
  name: rb.name
  parent: automationAccount
  location: location
  properties: {
    description: rb.description
    runbookType: 'PowerShell72'
    logProgress: false
    logVerbose: false
    publishContentLink: {
      uri: uri(artifactsLocation, rb.file)
      version: '1.0.0.0'
    }
  }
}]

var psGalleryModules = [
  'Microsoft.Graph'
  'Microsoft.Graph.Users'
  'Microsoft.Graph.Authentication'
]

var moduleVersion = '2.25.0'

resource PSGalleryModules72 'Microsoft.Automation/automationAccounts/powerShell72Modules@2023-11-01' = [for psGalleryModule in psGalleryModules: {
  name: psGalleryModule
  parent: automationAccount
  tags: {}
  properties: {
    contentLink: {
      uri: 'https://www.powershellgallery.com/api/v2/package/${psGalleryModule}/${moduleVersion}'
    }
  }
}]

// Blob service (default) and container
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: stg
  properties: {}
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: containerName
  parent: blobService
  properties: {
    publicAccess: 'None'
  }
}

// Role assignment: Grant Storage Blob Data Contributor to Automation Account managed identity over the Storage Account
// Role definition IDs:
//   Storage Blob Data Contributor: b7e6dc6d-f1e8-4753-8033-0f276bb0955b
//   Storage Account Contributor (management only, no data): 17d1049b-9a84-46fb-8f53-869881c3d3ab
// Using Blob Data Contributor for read/write data access.
resource storageBlobDataContributorRA 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  // name must be GUID - deterministic using storage + automation account names
  name: guid(stg.id, 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b', automationAccount.name)
  scope: stg
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
    principalId: automationAccount.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output storageAccountId string = stg.id
output automationAccountId string = automationAccount.id
output automationIdentityPrincipalId string = automationAccount.identity.principalId
output storageContainerId string = blobContainer.id
output storageContainerUri string = 'https://${stg.name}.${environment().suffixes.storage}/${containerName}'
