# Bicep Deployment (Storage + Automation Account)

Minimal template: `main.bicep` creates:
- Storage Account (StorageV2, Standard_LRS)
- Automation Account (Basic SKU) with system-assigned identity

## Parameters
- storageAccountName (required)
- automationAccountName (required)
- location (defaults to resource group location)
- tags (object, optional)

## Deploy
Assumes resource group already exists.

```powershell
$rg = 'rg-demo-core'
$loc = 'eastus'
$stg = 'democorestorage01'
$auto = 'aa-demo-core'

az group create -n $rg -l $loc
az deployment group create `
  -g $rg `
  -f ./infra/main.bicep `
  -p storageAccountName=$stg automationAccountName=$auto
```

## Outputs
Deployment returns resource IDs and the automation identity principalId.

## Entra Permissions
```powershell
$spID = (Get-AzADServicePrincipal -DisplayName $auto).Id 

$oPermissions = @( 
  "User.Read.All" 
) 

$GraphAppId = "00000003-0000-0000-c000-000000000000" 
$oGraphSpn = Get-AzADServicePrincipal -Filter "appId eq '$GraphAppId'" 
$oAppRole = $oGraphSpn.AppRole | Where-Object {($_.Value -in $oPermissions) -and ($_.AllowedMemberType -contains "Application")} 

foreach($AppRole in $oAppRole)  
{  
  $oAppRoleAssignment = @{  
    "PrincipalId" = $spID  
    #"ResourceId" = $GraphAppId  
    "ResourceId" = $oGraphSpn.Id  
    "AppRoleId" = $AppRole.Id  
  }  
}

New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $oAppRoleAssignment.PrincipalId -BodyParameter $oAppRoleAssignment -Verbose
```
