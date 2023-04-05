# Dynamics Resource Management (DRM) Templates

Download the latest Powershell module: https://www.powershellgallery.com/packages/Drm.Templates.Powershell

![](https://github.com/jetsetwilly1/Drm.Powershell/blob/main/md-images/pwsh-new-drmdeployment.gif)

## Build and run the Powershell module

To build the project just run 

```cmd
dotnet build --configuration Debug|Release
```

In Visual Studio just hit F5 to run the profile below in the launchSettings.json file

```json
{
  "profiles": {
    "Powershell 5": {
      "commandName": "Executable",
      "executablePath": "%SystemRoot%\\system32\\WindowsPowerShell\\v1.0\\powershell.exe",
      "commandLineArgs": "-NoExit -Command \"& { $Env:PSModulePath = $Env:PSModulePath+';$(ProjectDir)\\Output\\'; Import-Module -Name Drm.Templates.Powershell }\"",
      "workingDirectory": "%HOMEDRIVE%%HOMEPATH%",
      "nativeDebugging": false
    }
  }
}
```

Powershell 5 will spin up and automatically import the Drm.Templates.Powershell module.

Get up and running quickly by following the quickstart https://docs.drmtemplates.io/tutorials/quickstart.html

## Generate Templates

To generate templates you can connect to Dynamics environments using the
`Connect-CrmOnline` cmdlet.  This module comes from Dynamics CRM SDK (Microsoft.Xrm.Tooling.CrmConnector.Powershell ).
[Use PowerShell cmdlets for XRM tooling to connect to CRM.](https://learn.microsoft.com/en-us/powershell/module/microsoft.xrm.tooling.crmconnector.powershell/?view=pa-ps-latest)

Check out the documentation for generating templates. https://docs.drmtemplates.io/tutorials/generate-a-drm-template.html

## About DRM Templates

Dynamics Resource Management Templates (DRM) was built with Devops 
Engineers and Dynamics developers in mind. Based on ARM Templates, 
they are constructed in the same way and offer many of the same 
functionality.

Managing multiple Dynamics environments can be challenging but by 
using this tool, environments can be easily maintained and controlled
all through your automation pipelines.

DRM Templates allow you to 'PATCH' entities with your configuration.
This includes custom entities. A common scenario for a Dynamics 
environment is to manage environment variables or build Queues and Teams. 
Not only can you manage basic properties of these entities but
you can also apply members to your queues and teams.

Generate templates using the `New-DrmTemplate` cmd

Deploy templates using the `New-DrmDeployment` cmd

Below is an example template for an environmentvariablevalue.

```json
{
      "targetenvironment": "[variables('dynamicsCredentials')]",
      "type": "drm.crmbaseentity/environmentvariablevalues",
      "apiVersion": "2023-01-09",
      "name": "DEMO_Environment_Variables",
      "properties": {
        "data": [
          {
            "environmentvariablevalueid": "634b1a5e-0775-4de0-8cdd-9a5fdb4ac21f",
            "schemaname": "new_TestVariable",
            "value": "Hello Drm Current Value"
          }
        ]
      }
    }
```

## Contribute

Let's make this the automation equivalent of XrmToolBox :-)

Submit PR's with powershell functions that other people might find useful when deploying solutions across multiple environments.

Functions can be added to the `Drm.Templates.Powershell.psm1` file.

If you frequently use a Powershell function for automating tasks in Dynamics 365 projects, then consider adding it 
to the module for others to pick up and use.

## Documentation

Documentation can be found here https://docs.drmtemplates.io

Contribute to the documentation here https://github.com/jetsetwilly1/Drm.Documentation/.

Here's some of the how-to's already written

- [Manage application users](https://docs.drmtemplates.io/articles/manage-application-user-accounts.html)
- [Manage Business Units](https://docs.drmtemplates.io/articles/manage-business-units.html)
- [Connection References](https://docs.drmtemplates.io/articles/connection-references.html)
- [Setting Environment Variables](https://docs.drmtemplates.io/articles/setting-environment-variables.html)
- [Manage Organisation Settings](https://docs.drmtemplates.io/articles/setting-organisation-settings.html)
- [Transfer Word Document Templates](https://docs.drmtemplates.io/articles/document-templates.html)
- [Manage workflows](https://docs.drmtemplates.io/articles/manage-workflows.html)
- [Manage Custom Entities](https://docs.drmtemplates.io/articles/manage-custom-entities.html)