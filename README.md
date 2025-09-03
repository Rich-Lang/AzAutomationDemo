# Azure Automation Demo

Small demo showing:
- Bicep deployment of a Storage Account + Automation Account (system‑assigned managed identity)
- PowerShell runbooks that (a) say hello, (b) read Entra ID users via Microsoft Graph, and (c) write files / user exports to Blob Storage

## Repo Structure
```
infra/    Bicep template + infra README
scripts/  PowerShell runbooks (import into Automation Account)
```
See `infra/README.md` for parameter details and sample deployment commands.

## Quick Start
1. Create (or choose) a resource group.
2. Deploy the Bicep template.
3. Assign Microsoft Graph App Role(s) to the Automation Account managed identity (at minimum: User.Read.All for the provided samples).
4. Create the required Automation variables.
5. Import the scripts as runbooks (PowerShell 7.2 recommended) and publish them.
6. Test runbooks manually, then add schedules / webhooks as needed.

### Deploy Infra (example)
```powershell
$rg   = 'rg-demo-core'
$loc  = 'eastus'
$stg  = 'democorestorage01'    # must be globally unique
$auto = 'aa-demo-core'

az group create -n $rg -l $loc
az deployment group create `
  -g $rg `
  -f ./infra/main.bicep `
  -p storageAccountName=$stg automationAccountName=$auto
```

### Grant Graph Permissions
After deployment, the Automation Account has a system-assigned identity. Grant it Microsoft Graph application permissions (e.g. User.Read.All) and consent (admin) — see the script excerpt in `infra/README.md`.

### Runbooks
| Script | Purpose |
|--------|---------|
| `justHelloWorld.ps1` | Simple test output |
| `readUsers.ps1` | Lists Entra ID users (uses Graph) |
| `writeStorage.ps1` | Creates a timestamped file and uploads to Blob |
| `readUsersWriteStorage.ps1` | Exports users to CSV and uploads + sample file |

All scripts that hit Azure resources use Managed Identity (Connect-AzAccount -Identity / Connect-MgGraph -Identity).
