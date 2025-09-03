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
Write-Output "Runbook finished."