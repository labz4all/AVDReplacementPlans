# PowerShell deployment
## AVD Replacement plan with basic options
### PowerShell
```PowerShell
$ResourceGroupName = 'L4A-AVD-WU1-ReplacementPlan-HP1'
$bicepParams = @{

    #FunctionApp
    FunctionAppName           = 'func-avdreplacementplan-wu1-labz4all' # Name must be globally unique
    HostPoolName              = 'L4A-WU1-MS-HP1'
    TargetSessionHostCount    = 1 # Replace this with your target number of session hosts in the pool
    SessionHostNamePrefix     = "WU1ADMSHP1"
    SessionHostTemplateUri    = "https://raw.githubusercontent.com/WillyMoselhy/AVDReplacementPlans/main/SampleSessionHostTemplate/sessionhost.json"
    ADOrganizationalUnitPath  = "OU=HP1,OU=Multi-Session Desktop Hostpools,OU=AVD,OU=WU1,OU=AZ,OU=Infrastructure,OU=L4A,DC=labz4all,DC=com"
    SubnetId                  = "/subscriptions/e3d9fc92-f025-4462-8ef2-7fb34231418f/resourceGroups/L4A-WU1-AVD-VNET/providers/Microsoft.Network/virtualNetworks/L4A-WU1-AVD-VNET/subnets/L4A-WU1-AVD-VNET-ADDS-SH-SNET"

    # Supporting Resources
    StorageAccountName        = 'stavdreplacehost23l4a' # Make sure this is a unique name
    LogAnalyticsWorkspaceName = 'law-avdreplacementplan'
    # Session Host Parameters
    SessionHostParameters     = @{
        VMSize                = 'Standard_D4as_v5'
        TimeZone              = 'GMT Standard Time'
        AdminUsername         = 'labzadmin'

        AcceleratedNetworking = $true

        ImageReference        = @{
            publisher = 'MicrosoftWindowsDesktop'
            offer     = 'Windows-11'
            sku       = 'win11-22h2-avd'
            version   = 'latest'
        }

        #Domain Join
        DomainJoinObject      = @{
            DomainType  ='ActiveDirectory'
            DomainName = 'labz4all.com'
            UserName   = 'jesse'
        }
        DomainJoinPassword    = @{
            reference = @{
                keyVault = @{ # Update this with the id of your key vault and secret name.
                    id         = '/subscriptions/1bba5916-d3ff-403e-9007-58759a426278/resourceGroups/L4A-WU2-PLATFORMS/providers/Microsoft.KeyVault/vaults/L4A-AKV-WU2-TAGS'
                }
                secretName = 'domainjoin'
            }
        }

        Tags                  = @{}
    }
}
$bicepParams.SessionHostParameters = $bicepParams.SessionHostParameters | ConvertTo-Json -Depth 10 -Compress
$paramsNewAzResourceGroupDeployment = @{
    # Cmdlet parameters
    TemplateFile            = ".\Build\Bicep\FunctionApps.bicep"
    Name                    = "DeployFunctionApp-$($bicepParams.FunctionAppName)"
    ResourceGroupName       = $ResourceGroupName
    TemplateParameterObject = $bicepParams
}
New-AzResourceGroupDeployment @paramsNewAzResourceGroupDeployment -Verbose
```
