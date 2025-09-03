# Connect to Microsoft Graph using Managed Identity (for Automation Account)
Connect-MgGraph -Identity

# Get a list of users
$users = Get-MgUser -All

# Output the users
$users | Select-Object DisplayName, UserPrincipalName

##################################################################
# WRITE STORAGE
##################################################################

$ResourceGroup = Get-AutomationVariable -Name "resourceGroup"
$StorageAccountName = Get-AutomationVariable -Name "storageAccountName"
$ContainerName = Get-AutomationVariable -Name "containerName"

if (-not $ResourceGroup) { throw "resourceGroup variable not set." }
if (-not $StorageAccountName) { throw "storageAccountName variable not set." }
if (-not $ContainerName) { throw "containerName variable not set." }

Write-Output "Variables:"
Write-Output "ResourceGroup: $ResourceGroup"
Write-Output "StorageAccountName: $StorageAccountName"
Write-Output "ContainerName: $ContainerName"

Write-Output "Connecting to Azure..."
Connect-AzAccount -Identity

$sa = Get-AzStorageAccount -ResourceGroupName $ResourceGroup -Name $StorageAccountName
if (-not $sa) { throw "Storage account not found: $StorageAccountName" }
$ctx = $sa.Context

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

$tempPath = Join-Path $env:TEMP "CreatedFile-$stamp.csv"
"This was run on $env:COMPUTERNAME" | Set-Content -Path $tempPath -Encoding UTF8
Write-Output "Wrote to $tempPath"

(Get-Item $tempPath).Length

$blobName = "SomeFile-$stamp.csv"
Write-Output "Uploading $blobName to container '$ContainerName'..."
Set-AzStorageBlobContent -File $tempPath -Container $ContainerName -Blob $blobName -Context $ctx -Force | Out-Null

Write-Output "Upload complete. Blob: $blobName"

$BlobPrefix = "Users"
$tempPath = Join-Path $env:TEMP "$($BlobPrefix)-$stamp.csv"

$rows =
    $users |
    Select-Object `
        @{Name="FirstName"; Expression = { $_.givenName }},
        @{Name="UserPrincipalName"; Expression = { $_.UserPrincipalName }},
        @{Name="UserId"; Expression = { $_.Id }}

$rows | Export-Csv -Path $tempPath -NoTypeInformation -Encoding UTF8
Write-Output "Wrote CSV to $tempPath"

(Get-Item $tempPath).Length

$blobName = "Users-$stamp.csv"
Write-Output "Uploading $blobName to container '$ContainerName'..."
Set-AzStorageBlobContent -File $tempPath -Container $ContainerName -Blob $blobName -Context $ctx -Force | Out-Null
Write-Output "Upload complete. Blob: $blobName"

Write-Output "Runbook finished."