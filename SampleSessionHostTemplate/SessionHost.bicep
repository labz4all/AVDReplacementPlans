param VMName string
param VMSize string
param TimeZone string
param Location string = resourceGroup().location
param SubnetID string
param AdminUsername string
@secure()
param AdminPassword string

param AcceleratedNetworking bool

param Tags object = {}

param imageReference object

//HostPool join
param HostPoolName string
@secure()
param HostPoolToken string
param WVDArtifactsURL string = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_09-08-2022.zip'

//Domain Join
param DomainJoinObject object

@secure()
param DomainJoinPassword string = ''

resource vNIC 'Microsoft.Network/networkInterfaces@2022-07-01' = {
  name: '${VMName}-vNIC'
  location: Location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: SubnetID
          }
        }
      }
    ]
    enableAcceleratedNetworking: AcceleratedNetworking
  }
  tags: Tags
}

resource VM 'Microsoft.Compute/virtualMachines@2022-08-01' = {
  name: VMName
  location: Location
  identity: (DomainJoinObject.DomainType == 'AzureActiveDirectory') ? { type: 'SystemAssigned' } : null
  properties: {
    osProfile: {
      computerName: VMName
      adminUsername: AdminUsername
      adminPassword: AdminPassword
      windowsConfiguration: {
        timeZone: TimeZone
      }
    }
    hardwareProfile: {
      vmSize: VMSize
    }
    storageProfile: {
      osDisk: {
        name: '${VMName}-OSDisk'
        createOption: 'FromImage'
        deleteOption: 'Delete'
      }
      imageReference: imageReference
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vNIC.id
          properties:{
            deleteOption: 'Delete'
          }
        }
      ]
    }
    licenseType: 'Windows_Client'

  }
  // Domain Join  - AD//
  resource ADJoin 'extensions@2022-08-01' = {
    // Documentation is available here: https://docs.microsoft.com/en-us/azure/active-directory-domain-services/join-windows-vm-template#azure-resource-manager-template-overview
    name: 'DomainJoin'
    location: Location
    properties: {
      publisher: 'Microsoft.Compute'
      type: 'JSonADDomainExtension'
      typeHandlerVersion: '1.3'
      autoUpgradeMinorVersion: true
      settings: {
        Name: DomainJoinObject.DomainName
        OUPath: DomainJoinObject.OUPath
        User: '${DomainJoinObject.DomainName}\\${DomainJoinObject.UserName}'
        Restart: 'true'

        //will join the domain and create the account on the domain. For more information see https://msdn.microsoft.com/en-us/library/aa392154(v=vs.85).aspx'
        Options: 3
      }
      protectedSettings: {
        Password: DomainJoinPassword //TODO: Test domain join from keyvault option
      }
    }
  }

  // HostPool join //
  resource AddWVDHost 'extensions@2022-08-01' = if (HostPoolName != '') {
    name: 'dscextension'
    location: Location
    properties: {
      publisher: 'Microsoft.PowerShell'
      type: 'DSC'
      typeHandlerVersion: '2.77'
      autoUpgradeMinorVersion: true
      settings: {
        modulesUrl: WVDArtifactsURL
        configurationFunction: 'Configuration.ps1\\AddSessionHost'
        properties: {
          hostPoolName: HostPoolName
          registrationInfoToken: HostPoolToken
          aadJoin: false
          useAgentDownloadEndpoint: true
        }
      }
    }
    dependsOn: [ADJoin]

  }

  tags: Tags
}
