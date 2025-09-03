$ClientId = Get-AutomationVariable -Name "clientId"
$TenantId = Get-AutomationVariable -Name "tenantId"
$ClientSecret = Get-AutomationVariable -Name "clientSecret"

# Convert the client secret to a secure string
$ClientSecretPass = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force

# Create a credential object using the client ID and secure string
$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $ClientSecretPass

# Connect to Microsoft Graph with Client Secret
Connect-MgGraph -TenantId $tenantId -ClientSecretCredential $ClientSecretCredential

Write-Output "Connected to Microsoft Graph"

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

# Create storage context (using OAuth)
$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount

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