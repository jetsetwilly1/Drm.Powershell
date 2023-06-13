#
# Module manifest for module 'DrmTemplateV1'
#
# Generated by: Stuart Elcocks
#
# Generated on: 15/04/2021
#

@{

# Script module or binary module file associated with this manifest.
RootModule = '.\Drm.Templates.Powershell.psm1'

# Version number of this module.
ModuleVersion = '2.1.2'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '730b9aa9-a801-4dc2-949d-9063c52ec919'

# Author of this module
Author = 'Stuart Elcocks'

# Company or vendor of this module
#CompanyName = ''

# Copyright statement for this module
Copyright = '(c) 2023. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Drm Template Tools allow you to generate and deploy configuration templates to your Microsoft Dynamics 365 online environments. DRM is a wrapper utility based around the Dynamics 365 online web api that allows you to configure and maintain many Dynamics entities. https://docs.drmtemplates.io/drmtemplates/supported-web-api-entities.html Check out the documentation here https://docs.drmtemplates.io/ to see how easy it is to get up and running quickly.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.0'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
DotNetFrameworkVersion = '4.0.0.0'

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
RequiredAssemblies = @(
".\Drm.Powershell\Azure.Core.dll",
".\Drm.Powershell\Azure.Security.KeyVault.Secrets.dll",
".\Drm.Powershell\DrmTemplates.Services.dll",
".\Drm.Powershell\Microsoft.AspNetCore.Mvc.Abstractions.dll",
".\Drm.Powershell\Microsoft.AspNetCore.Mvc.Core.dll",
".\Drm.Powershell\Microsoft.Extensions.Logging.Abstractions.dll",
".\Drm.Powershell\Microsoft.Extensions.Logging.Abstractions.dll",
".\Drm.Powershell\Microsoft.Identity.Client.dll",
".\Drm.Powershell\Microsoft.IdentityModel.Abstractions.dll",
".\Drm.Powershell\Microsoft.IdentityModel.JsonWebTokens.dll",
".\Drm.Powershell\Microsoft.IdentityModel.Logging.dll",
".\Drm.Powershell\Microsoft.IdentityModel.Tokens.dll",
".\Drm.Powershell\System.Buffers.dll",
".\Drm.Powershell\System.Diagnostics.DiagnosticSource.dll",
".\Drm.Powershell\System.IdentityModel.Tokens.Jwt.dll",
".\Drm.Powershell\System.Memory.dll",
".\Drm.Powershell\System.Numerics.Vectors.dll",
".\Drm.Powershell\System.Runtime.CompilerServices.Unsafe.dll",
".\Drm.Powershell\System.Text.Json.dll",
".\Drm.Powershell\System.Threading.Tasks.Extensions.dll",
".\Drm.Powershell\Drm.Templates.Powershell.dll",
".\Drm.Powershell\Newtonsoft.Json.dll",
".\Drm.Powershell\Newtonsoft.Json.Schema.dll",
".\Drm.Powershell\Drm.Core.dll",
".\Drm.Powershell\DrmDeployment.Services.dll",
".\Drm.Powershell\DrmTemplates.OData.Services.dll",
".\Drm.Powershell\Jint.dll",
".\Drm.Powershell\Esprima.dll",
".\Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Crm.Sdk.Proxy.dll",
".\Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Crm.Sdk.Proxy.dll",
".\Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.IdentityModel.Clients.ActiveDirectory.dll",
".\Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Xrm.Sdk.dll",
".\Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Xrm.Tooling.Connector.dll",
".\Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Xrm.Tooling.CrmConnectControl.dll",
".\Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Xrm.Tooling.CrmConnector.Powershell.dll",
".\Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Xrm.Tooling.Ui.Styles.dll",
".\Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Crm.Sdk.Proxy.dll")

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
NestedModules = @('.\Drm.Powershell\Drm.Templates.Powershell.dll','Microsoft.Xrm.Tooling.CrmConnector.Powershell')

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @('New-DrmTemplate','Set-SolutionEnvironmentVariables', 'Connect-CrmOnline','Get-DynamicsAutoNumber','Set-DynamicsAutoNumber')

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
FileList = @('Drm.Powershell\Drm.Templates.Powershell.dll',
'Drm.Powershell\Drm.Core.dll',
'Drm.Powershell\DrmDeployment.Services.dll',
'Drm.Powershell\DrmTemplates.OData.Services.dll',
'Drm.Powershell\DrmTemplates.Services.dll',
'Drm.Templates.Powershell.psm1','Drm.Powershell\Newtonsoft.Json.dll',
'Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Crm.Sdk.Proxy.dll',
'Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.IdentityModel.Clients.ActiveDirectory.dll',
'Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Rest.ClientRuntime.dll',
'Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Xrm.Sdk.Deployment.dll',
'Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Xrm.Sdk.dll',
'Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Xrm.Tooling.Connector.dll',
'Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Xrm.Tooling.CrmConnectControl.dll',
'Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Xrm.Tooling.CrmConnector.Powershell.dll',
'Microsoft.Xrm.Tooling.CrmConnector.PowerShell\3.3.0.964\Microsoft.Xrm.Tooling.Ui.Styles.dll')

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('Dynamics', 'DRM', 'CRM', 'Dynamics365','PowerApps','CDS', 'CommonDataService', 'PowerPlatform','Dataverse')

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        ProjectUri = 'https://docs.drmtemplates.io/'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = '
Changes and enhancements in this release: 
- Added two new functions Get-DynamicsAutoNumber and Set-DynamicsAutoNumber from Dave Langan to help configure Seed configuration via pipelines.
- Powershell module is available at https://github.com/jetsetwilly1/Drm.Powershell
- Schemas located at https://schemas.drmtemplates.io/
- To get up and running quickly visit the project website: https://docs.drmtemplates.io/tutorials/quickstart.html'

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

