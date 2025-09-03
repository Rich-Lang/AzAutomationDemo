# Connect to Microsoft Graph using Managed Identity (for Automation Account)
Connect-MgGraph -Identity

# Get a list of users
$users = Get-MgUser -All

# Output the users
$users | Select-Object DisplayName, UserPrincipalName