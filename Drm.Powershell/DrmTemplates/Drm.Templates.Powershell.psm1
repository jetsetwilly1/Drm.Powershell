#Dot source all functions in all ps1 files located in the module's public and private folders, excluding tests and profiles.
Get-ChildItem -Path $PSScriptRoot\private\*.ps1 -Exclude *.tests.ps1, *profile.ps1 -ErrorAction SilentlyContinue |
ForEach-Object {
    . $_.FullName
}

function Set-CloudflowsOwner {
    <#
    .SYNOPSIS 
        Update the owner of all cloudflows in a Dynamics environment.

    .DESCRIPTION
        Connect to a Dataverse instance using Connect-CrmOnline and provide
        the full name of a system user account to update all workflows to a new owner.

    .NOTES      
        Author     : Danny Styles

    .PARAMETER NewFlowOwner
        The full name of a system user account.

    .EXAMPLE
        Set-CloudflowsOwner -NewFlowOwner "Danny Styles"
    #>

    [CmdletBinding()]    
    PARAM (
    [Parameter(Mandatory=$true)] [string]$NewFlowOwner
    )

    # Check connection has been made to dataverse env.
    if ($null -eq $conn) 
    { 
        Write-Error "Please use Connect-CrmOnline to connect to a dataverse environment first." 
        throw "No connection to Dataverse environment."
    }

    $DataverseEnvUrl = $conn.CrmConnectOrgUriActual.Scheme+"://"+$conn.CrmConnectOrgUriActual.Host

    ##########################################################
    # Call Dataverse WebAPI using Authentication Token
    ##########################################################

    # Parameters for the Dataverse WebAPI call which includes our header
    # that carries the access token.
    $apiCallParams =
    @{
        URI = $DataverseEnvUrl+ "/api/data/v9.2/systemusers"
        Headers = @{
            "Authorization" = "Bearer $($conn.CurrentAccessToken)";
            "Content-Type" = "application/json"; 
            "Accept" = "application/json";
            "Prefer" = "odata.include-annotations="*"";
        }
        Method = 'GET'
    }

    # Call the Dataverse WebAPI
    $apiCallRequest = Invoke-RestMethod @apiCallParams -ErrorAction Stop
    $SystemUser = $apiCallRequest.value | where-object fullname -eq 'SYSTEM'
    $NewUser = $apiCallRequest.value | where-object fullname -eq "$NewFlowOwner"

    $apiCallParams =
    @{
        URI = $dataverseEnvUrl+ '/api/data/v9.2/workflows?$filter=category eq 5&$expand=ownerid,owninguser($select=fullname)'
        Headers = @{
            "Authorization" = "Bearer $($conn.CurrentAccessToken)";
            "Content-Type" = "application/json"; 
            "Accept" = "application/json";

        }
        Method = 'GET'
    }
    $apiCallRequest = Invoke-RestMethod @apiCallParams -ErrorAction Stop
    $workflows = $apiCallRequest.value | where-object _owninguser_value -ne $SystemUser.systemuserid
    $workflows = $workflows | where-object _owninguser_value -ne $NewUser.systemuserid

    foreach($Flow in $workflows){
        $uri = $dataverseEnvUrl+ '/api/data/v9.2/workflows(' + $flow.workflowid  + ')'
        $apiCallParams =
        @{
            URI =    $Uri
            Headers = @{
                "Authorization" = "Bearer $($conn.CurrentAccessToken)";
                "Content-Type" = "application/json"; 
                "Accept" = "application/json";

            }
            Method = 'PATCH'
        }

        $params = @{
        "ownerid@odata.bind"="/systemusers(" + $NewUser.systemuserid + ")"
        } | ConvertTo-Json

        write-host "Updating " $Flow.name
        $apiCallRequest = Invoke-RestMethod @apiCallParams -Body $params -ErrorAction Stop
    }
}

function Get-DynamicsAutoNumber{
    <#
	.SYNOPSIS 
    Connect to Dataverse and Get the value needed for a seed autonumber field this is to
    be run before release, then call the function Set-DynamicsAutoNumber to set the field after release

	.NOTES      
    Author     : Dave Langan
    
    .PARAMETER $TenantID
    The tenant ID for the environment
    
    .PARAMETER $appId
    The Application (client) ID of the App registration

    .PARAMETER $clientSecret
    The client secret generated within the App registration

    .PARAMETER $dataverseEnvUrl
    The url of the Dataverse environment you want to connect to

    .PARAMETER $EntityName
    The name of the entity in the dataverse to use

    .PARAMETER $FieldName
    The name of the field to get the next autonumber for

    .PARAMETER $VarName
    The name of the variable to set in ADO with the Seed value which is incremented by 1
    #>

    [CmdletBinding()]    
    PARAM (
    [Parameter(Mandatory=$true)] [string]$TenantId,
    [Parameter(Mandatory=$true)] [string]$ClientId,
    [Parameter(Mandatory=$true)] [string]$ClientSecret,
    [Parameter(Mandatory=$true)] [string]$dataverseEnvUrl,
    [Parameter(Mandatory=$true)] [string]$EntityName, 
    [Parameter(Mandatory=$true)] [string]$FieldName, 
    [Parameter(Mandatory=$true)] [string]$VarName 
    )

    $appId = $ClientId

    $oAuthTokenEndpoint = 'https://login.microsoftonline.com/' + $TenantId + '/oauth2/v2.0/token'
    
    $appId = $ClientId


    ##########################################################
    # Access Token Request
    ##########################################################

    # OAuth Body Access Token Request
    $authBody = 
    @{
        client_id = $appId;
        client_secret = $clientSecret;    
        # The v2 endpoint for OAuth uses scope instead of resource
        scope = "$($dataverseEnvUrl)/.default"    
        grant_type = 'client_credentials'
    }

    # Parameters for OAuth Access Token Request
    $authParams = 
    @{
        URI = $oAuthTokenEndpoint
        Method = 'POST'
        ContentType = 'application/x-www-form-urlencoded'
        Body = $authBody
    }

    # Get Access Token
    $authRequest = Invoke-RestMethod @authParams -ErrorAction Stop
    $authResponse = $authRequest

    ##########################################################
    # Call Dataverse WebAPI using Authentication Token
    ##########################################################

    # Params related to the Dataverse WebAPI call you will be making.
    # These need to be in single quotes to ensure they are not expanded.
    $uriParams = '$select=DisplayName,Settings'

    # Parameters for the Dataverse WebAPI call which includes our header
    # that carries the access token.
    $apiCallParams =
    @{
        URI = "$($dataverseEnvUrl)/api/data/v9.2/GetNextAutoNumberValue"
        Headers = @{
            "Authorization" = "$($authResponse.token_type) $($authResponse.access_token)";
            "Content-Type" = "application/json"; 
        }
        Method = 'POST'
    }

    $params = @{
        "EntityName"="$EntityName"
        "AttributeName"="$FieldName"
    #    "Value"=1002

    } | ConvertTo-Json

    # Call the Dataverse WebAPI
    $apiCallRequest = Invoke-RestMethod @apiCallParams -Body $params -ErrorAction Stop
    $apiCallResponse = $apiCallRequest

    #Output the results
    Write-Host "Seed value is set to " $apiCallResponse.NextAutoNumberValue.ToString() 

    $SeedNumber1 = $apiCallResponse.NextAutoNumberValue.tostring()
    [int]$SeedNumber = $SeedNumber1 + 1
    Write-Host ("##vso[task.setvariable variable=$VarName;isOutput=true;]$SeedNumber")
    Write-Host "##vso[task.setvariable variable=Seed;]$SeedNumber"
    return $SeedNumber1
}

function Set-DynamicsAutoNumber{
    <#
	.SYNOPSIS 
    Connect to Dataverse and Set the Seed value for an autonumber field this is to
    be run after release, it useses the ADO variable created by Get-DynamicsAutoNumber

	.NOTES      
    Author     : Dave Langan
    
    .PARAMETER $TenantID
    The tenant ID for the environment
    
    .PARAMETER $appId
    The Application (client) ID of the App registration

    .PARAMETER $clientSecret
    The client secret generated within the App registration

    .PARAMETER $dataverseEnvUrl
    The url of the Dataverse environment you want to connect to

    .PARAMETER $EntityName
    The name of the entity in the dataverse to use

    .PARAMETER $FieldName
    The name of the field to set the next autonumber seed value for

    .PARAMETER $SeedValue
    The name of the variable to use in ADO to set the seed value populated by the script Dynamicsautonumberget.ps1
    #>

    [CmdletBinding()]    
    PARAM (
    [Parameter(Mandatory=$true)] [string]$TenantId,
    [Parameter(Mandatory=$true)] [string]$ClientId,
    [Parameter(Mandatory=$true)] [string]$ClientSecret,
    [Parameter(Mandatory=$true)] [string]$dataverseEnvUrl,
    [Parameter(Mandatory=$true)] [string]$EntityName, 
    [Parameter(Mandatory=$true)] [string]$FieldName, 
    [Parameter(Mandatory=$true)] [int]$SeedValue 
    )

    $appId = $ClientId


    $oAuthTokenEndpoint = 'https://login.microsoftonline.com/' + $TenantId + '/oauth2/v2.0/token'
    
    $appId = $ClientId

    ##########################################################
    # Access Token Request
    ##########################################################

    # OAuth Body Access Token Request
    $authBody = 
    @{
        client_id = $appId;
        client_secret = $clientSecret;    
        # The v2 endpoint for OAuth uses scope instead of resource
        scope = "$($dataverseEnvUrl)/.default"    
        grant_type = 'client_credentials'
    }

    # Parameters for OAuth Access Token Request
    $authParams = 
    @{
        URI = $oAuthTokenEndpoint
        Method = 'POST'
        ContentType = 'application/x-www-form-urlencoded'
        Body = $authBody
    }

    # Get Access Token
    $authRequest = Invoke-RestMethod @authParams -ErrorAction Stop
    $authResponse = $authRequest

    ##########################################################
    # Call Dataverse WebAPI using Authentication Token
    ##########################################################

    # Params related to the Dataverse WebAPI call you will be making.
    # These need to be in single quotes to ensure they are not expanded.
    $uriParams = '$select=DisplayName,Settings'

    # Parameters for the Dataverse WebAPI call which includes our header
    # that carries the access token.
    $apiCallParams =
    @{
        URI = "$($dataverseEnvUrl)/api/data/v9.2/SetAutoNumberSeed"
        Headers = @{
            "Authorization" = "$($authResponse.token_type) $($authResponse.access_token)";
            "Content-Type" = "application/json"; 
        }
        Method = 'POST'
    }

    $params = @{
        "EntityName"="$EntityName"
        "AttributeName"="$FieldName"
        "Value"= $SeedValue

    } | ConvertTo-Json

    # Call the Dataverse WebAPI
    $apiCallRequest = Invoke-RestMethod @apiCallParams -Body $params -ErrorAction Stop
    $apiCallResponse = $apiCallRequest

    #Output the results
    Write-Host "Seed value is set to $SeedValue for field $FieldName in entity $EntityName"
}


function Set-SolutionEnvironmentVariables{
    <#
    .SYNOPSIS
        Set environment variable values directly in an unpacked solution.
    .DESCRIPTION
        Update the current or default value of an environment variable definition in an unpacked solution, 
        using the provided schemaname. If the variable does not have a current or default value, 
        it will be added as the default value.
    .PARAMETER UnpackedSolutionFolder
        Required: Location of the unpakced solution
    .PARAMETER VariableReplacements
        A Hashtable of variable replacements e.g. { <schemaname> = <value>;}
    .PARAMETER JsonVariableReplacements
        Location of a .json file with variable replacements
   .EXAMPLE
        Set-SolutionEnvironmentVariables -UnpackedSolutionFolder C:\drmdemo\unpackedSolution -VariableReplacements @{ "new_helloDrm" = "example"; "new_exampleSchemaName"= "Example2"}
   .EXAMPLE
        Set-SolutionEnvironmentVariables -UnpackedSolutionFolder C:\drmdemo\unpackedSolution -JsonVariableReplacements C:\drmdemo\variablereplacements.json
    #>

    [CmdletBinding()]    
    PARAM(
        [parameter(Position=1, Mandatory=$true)]
        [ValidateScript({
            if(-NOT ($_ | Test-Path) ){
                throw "Cannot find unpacked solution at $_"
            }
            return $true 
        })]
        [System.IO.FileInfo]$UnpackedSolutionFolder,    
        [parameter(Position=2, Mandatory=$false,ParameterSetName="hashtable")]
        [Hashtable]$VariableReplacements,
        [parameter(Position=3, Mandatory=$false,ParameterSetName="json")]
        [ValidateScript({
            if(-Not ($_ | Test-Path) ){
                throw "File or folder does not exist" 
            }
            if(-Not ($_ | Test-Path -PathType Leaf) ){
                throw "The Path argument must be a file. Folder paths are not allowed."
            }
            return $true 
        })]
        [System.IO.FileInfo]$JsonVariableReplacements
    )

    # get schema definitions from folder names
    $variableSchemaNames = Get-ChildItem -Path $UnpackedSolutionFolder/environmentvariabledefinitions -Recurse -Directory -Force | Select -ExpandProperty Name

    # use the hashtable or json file and update the entries.
    if($variableSchemaNames.count -ne 0){
        
        if($JsonVariableReplacements){
            # read json into $VariableReplacements
            Write-Host "Reading variable replacements from json file..."
            $jsonReplacements = Get-Content -Raw -Path $JsonVariableReplacements | ConvertFrom-Json
        
            $VariableReplacements = @{}
            $jsonReplacements.psobject.properties | foreach{$VariableReplacements[$_.Name]= $_.Value}
        } else {
            Write-Host "Reading variable replacements from object..."
        }

        foreach($envReplacementKey in $VariableReplacements.keys){
            # find env definition in $variableSchemaNames list
            if($variableSchemaNames.Contains($envReplacementKey)){
                Write-Host "`nUpdating environment variable definition: '$($envReplacementKey)'"

                $envvarPath = "$UnpackedSolutionFolder/environmentvariabledefinitions/$envReplacementKey/environmentvariablevalues.json"
                $envdefinitionPath = "$UnpackedSolutionFolder/environmentvariabledefinitions/$envReplacementKey/environmentvariabledefinition.xml"

                # check for json file, if exists, update it.
                if(Test-Path -Path $envvarPath -PathType Leaf){
                  $json = Get-Content -Raw -Path $envvarPath | ConvertFrom-Json
                  Write-Host "...changing current value from : '$($json.environmentvariablevalues.environmentvariablevalue.value)' to '$($VariableReplacements[$envReplacementKey])'"
                  $json.environmentvariablevalues.environmentvariablevalue.value = $VariableReplacements[$envReplacementKey]
                  $json | ConvertTo-Json -depth 100 | Set-Content $envvarPath
                } elseif(Test-Path -Path $envdefinitionPath -PathType Leaf){

                  [xml]$xmlElm = Get-Content -Path $envdefinitionPath
                  
                  $testDefaultNodeExists = $xmlElm.SelectSingleNode("./environmentvariabledefinition/defaultvalue")

                  if($testDefaultNodeExists){
                    Write-Host "...changing default value from: '$($xmlElm.environmentvariabledefinition.defaultvalue)' to '$($VariableReplacements[$envReplacementKey])'"

                    $xmlElm.environmentvariabledefinition.defaultvalue = $VariableReplacements[$envReplacementKey]
                    $xmlElm.Save($envdefinitionPath)
                  } else {
                    Write-Host "...adding default value: '$($VariableReplacements[$envReplacementKey])'"

                    $child = $xmlElm.CreateElement("defaultvalue")
                    $out = $xmlElm.DocumentElement.AppendChild($child)
                    $xmlElm.environmentvariabledefinition.defaultvalue = $VariableReplacements[$envReplacementKey]
                    $xmlElm.Save($envdefinitionPath)
                  }
                }
            } else {
                Write-Host "`nNo environment variable definition was found in the solution for: '$($envReplacementKey)'"
            }
        }
    } else {
        throw "No variable definitions found. Please check the unpacked solution contains environmentvariable definitions."
    }
}

function New-DrmTemplate{
    <#
    .SYNOPSIS
        Generates a new DRM Template.
    .DESCRIPTION
        Connect to a Dynamics environment and use the Web API to build a barebones DRM template for use in automation.
    .PARAMETER Url
        Optional: [string] The Dynamics environment to connect.
    .PARAMETER EntityName
        Required: Select the entity you want to target here https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/reference/entitytypes?view=dataverse-latest
    .PARAMETER Filter
        Optional: Add your web api filter for example '$select=name'
    .PARAMETER SetupTemplateForAutomation
        Optional: If set, it will generate the template for connecting to a dynamics environment using application credentials.
    .PARAMETER SubscriptionId
        Required: Enter your subscrtiption id.
    .PARAMETER OutputToFile
        Optional: Custom path of location to save the template
    .EXAMPLE
        New-DrmTemplate -Url https://demo.crm11.com -Entity queues -Filter '$select=name' -SetupTemplateForAutomation -SubscriptionId 'xxxxxx'
    #>
    [CmdletBinding()]
    PARAM(
        [parameter(Position=1, Mandatory=$false)]
        [ValidatePattern('([\w-]+).crm([0-9]*).(microsoftdynamics|dynamics|crm[\w-]*).(com|de|us|cn)')]
        [string]$Url,
        [parameter(Position=2, Mandatory=$true)]
        [string]$EntityName, 
        [parameter(Position=3, Mandatory=$false)]
        [string]$Filter,
        [parameter(Position=4, Mandatory=$false)]
        [switch]$SetupTemplateForAutomation,
        #[parameter(Position=5, Mandatory=$false)]
        #[string]$SubscriptionId,
        [parameter(Position=6, Mandatory=$false)]
        [ValidateScript({
            if(-Not ($_.DirectoryName | Test-Path) ){
                throw "Folder location does not exist"
            }
            if((Get-Item -Path $_).PSIsContainer) {
                throw "You must include the file name e.g. 'template.json'"
            }
            return $true 
        })]
        [System.IO.FileInfo]$OutputToFile
        #[parameter(Position=7, DontShow=$true)]
        #[switch]$UseBetaEnvironment
    )

    #DynamicParam {
    #    if ([string]::IsNullOrEmpty($drm.SubscriptionId)) {
    #        $subAttribute = New-Object System.Management.Automation.ParameterAttribute
    #        $subAttribute.Position = 5
    #        $subAttribute.Mandatory = $true
    #        
    #        $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]
    #        $attributeCollection.Add($subAttribute)
    #         $SubscriptionId = New-Object System.Management.Automation.RuntimeDefinedParameter('SubscriptionId', [string], $attributeCollection)
    #         $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
    #         $paramDictionary.Add('SubscriptionId', $SubscriptionId)
    #         return $paramDictionary
    #    } else {
    #        $SubscriptionId = $drm.SubscriptionId
    #    }
    #}

    process {

        if($conn.CurrentAccessToken) {
                           
            [hashtable]$postParams = @{}

            if($Url) {
                $postParams.Add('url', $Url)
                Write-Host("Connecting to Dynamics Instance: " + $Url)
            }
            else {
                # try and get the url from the connection.
                if($conn.ConnectedOrgPublishedEndpoints.Get_Item("WebApplication")) {
                    $dynamicsUrl = $conn.ConnectedOrgPublishedEndpoints.Get_Item("WebApplication")

                    $postParams.Add('url', $dynamicsUrl)
                    Write-Host("Connecting to Dynamics Instance: " + $dynamicsUrl)
                }
                else {
                    throw "Unable to set the Dynamics url to fetch the data, published endpoint web application not available in connection details."
                }
            }

            $postParams.Add('entityname', $EntityName)
            Write-Verbose "Entityname set to $EntityName" 

            if($Filter) {
                $postParams.Add('filter', $Filter)
                Write-Verbose "Filter set to $Filter" 
            }

            if($SetupTemplateForAutomation.IsPresent) {
                $postParams.Add('setupTemplateForAutomation', $true)
                Write-Verbose "SetupTemplateForAutomation set to 'true'"
            } 
            else {
                $postParams.Add('setupTemplateForAutomation', $false)
                Write-Verbose "SetupTemplateForAutomation set to 'false'"
            }

            $postParams.Add('token', $conn.CurrentAccessToken)
            Write-Verbose "Using token from Connect-CrmOnline connection object."

            try
            {
                Write-Host("Generating Template...")
                    
                $verboseLogging = $false

                if($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent)
                {
                    $verboseLogging = $true
                }

                $templateManager= New-Object drm.Powershell.DrmTemplates.PowershellGenerateTemplate -ArgumentList $verboseLogging

                $response = $templateManager.GenerateTemplateAsync(($postParams|ConvertTo-Json)).GetAwaiter().GetResult() | ConvertFrom-Json

                if($response.Data.Template) {

                    if($OutputToFile) {
                        $templateManager.WriteTemplateToFile($OutputToFile)
                        
                        Write-Host "Template created at " $OutputToFile
                    }
                    else {
                        $pathInfo = Get-Location

                        $outputPath = Join-Path -Path $pathInfo.Path -ChildPath "\template.json"

                        $templateManager.WriteTemplateToFile($outputPath)
                        Write-Host "Template created at " $outputPath
                    }
                }
                else {
                    $JoinedString = $response.Error -join ","
                    Write-Error $JoinedString
                }

            }
            catch {
                throw $_
            }
        }
        else {
            throw "No connection to CRM online.  Please connect to a Dynamics environment using the 'Connect-CrmOnline' cmdlet."
        }
    }
}

function Connect-CrmOnline{
    [CmdletBinding()]
    PARAM( 
        [parameter(Position=1, Mandatory=$true, ParameterSetName="connectionstring")]
        [string]$ConnectionString, 
        [parameter(Position=1, Mandatory=$true, ParameterSetName="Secret")]
        [Parameter(Position=1,Mandatory=$true, ParameterSetName="Creds")]
        [Parameter(Position=1,Mandatory=$true, ParameterSetName="NoCreds")]
        [ValidatePattern('([\w-]+).crm([0-9]*).(microsoftdynamics|dynamics|crm[\w-]*).(com|de|us|cn)')]
        [string]$ServerUrl, 
		[parameter(Position=2, Mandatory=$true, ParameterSetName="Creds")]
        [PSCredential]$Credential,
		[Parameter(Position=4,Mandatory=$false, ParameterSetName="Creds")]
		[Parameter(Position=3,Mandatory=$false, ParameterSetName="NoCreds")]
        [switch]$ForceOAuth,
        [parameter(Position=2, Mandatory=$true, ParameterSetName="Secret")]
		[Parameter(Position=5,Mandatory=$false, ParameterSetName="Creds")]
		[Parameter(Position=4,Mandatory=$false, ParameterSetName="NoCreds")]
        [ValidateScript({
            try {
                [System.Guid]::Parse($_) | Out-Null
                $true
            } catch {
                $false
            }
        })]
        [string]$OAuthClientId,
        [parameter(Position=3, Mandatory=$false, ParameterSetName="Secret")]
		[Parameter(Position=6,Mandatory=$false, ParameterSetName="Creds")]
		[Parameter(Position=5,Mandatory=$false, ParameterSetName="NoCreds")]
        [string]$OAuthRedirectUri, 
		[parameter(Position=4, Mandatory=$true, ParameterSetName="Secret")]
        [string]$ClientSecret, 
        [parameter(Position=5, Mandatory=$false, ParameterSetName="NoCreds")]
        [string]$Username, 
        [int]$ConnectionTimeoutInSeconds,
        [string]$LogWriteDirectory, 
        [switch]$BypassTokenCache,
        [parameter(Position=7, Mandatory=$false, ParameterSetName="Interactive")]
        [switch]$InteractiveMode
    )

    if($InteractiveMode){
        $global:conn = Get-CrmConnection -InteractiveMode
        return $global:conn
    }

	if(-not [string]::IsNullOrEmpty($ServerUrl) -and $ServerUrl.StartsWith("https://","CurrentCultureIgnoreCase") -ne $true){
		Write-Verbose "ServerUrl is missing https, fixing URL: https://$ServerUrl"
		$ServerUrl = "https://" + $ServerUrl
	}

	#starting default connection string with require new instance and server url
    $cs = "RequireNewInstance=True"
    $cs += ";Url=$ServerUrl"
    if($BypassTokenCache){
        $cs += ";TokenCacheStorePath="
    }

    if($ConnectionTimeoutInSeconds -and $ConnectionTimeoutInSeconds -gt 0){
	    $newTimeout = New-Object System.TimeSpan -ArgumentList 0,0,$ConnectionTimeoutInSeconds
        Write-Verbose "Setting new connection timeout of $newTimeout"
	    #set the timeout on the MaxConnectionTimeout static 
        [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]::MaxConnectionTimeout = $newTimeout
    }

    if($ConnectionString){
        if(!$ConnectionString -or $ConnectionString.Length -eq 0){
			throw "Cannot create the CrmServiceClient, the connection string is null"
		}
		Write-Verbose "ConnectionString provided - skipping all helpers/known parameters"
        
        $global:conn = New-Object Microsoft.Xrm.Tooling.Connector.CrmServiceClient -ArgumentList $ConnectionString
        if($global:conn){
            ApplyCrmServiceClientObjectTemplate($global:conn)  #applyObjectTemplateFormat
        }
		return $global:conn
    }
	elseif($ClientSecret){
		$cs += ";AuthType=ClientSecret"
		$cs += ";ClientId=$OAuthClientId"
        if(-not [string]::IsNullOrEmpty($OAuthRedirectUri)){
		    $cs += ";redirecturi=$OAuthRedirectUri"
        }
		$cs += ";ClientSecret='$ClientSecret'"
		Write-Verbose ($cs.Replace($ClientSecret, "*******"))
		try
		{
			if(!$cs -or $cs.Length -eq 0){
				throw "Cannot create the CrmServiceClient, the connection string is null"
			}

			#$global:conn = [Microsoft.Xrm.Tooling.Connector.CrmServiceClient]::new($cs)
            $global:conn = Get-CrmConnection -ConnectionString $cs
            
            #ApplyCrmServiceClientObjectTemplate($global:conn)  #applyObjectTemplateFormat
            $global:conn
            return
		}
		catch
		{
			throw $_
		}   
	}
	else{
        if(-not [string]::IsNullOrEmpty($Username) -and $ForceOAuth -eq $false){
            $cs += ";Username=$UserName"
            Write-Warning "UserName parameter is only compatible with oAuth, forcing auth mode to oAuth"
            $ForceOAuth = $true
        }
		#Default to Office365 Auth, allow oAuth to be used
		if(!$OAuthClientId -and !$ForceOAuth){
			Write-Verbose "Using AuthType=Office365"
            if(-not $Credential){
                #user did not provide a credential
                Write-Warning "Cannot create the CrmServiceClient, no credentials were provided. Credentials are required for an AuthType of Office365."
                $Credential = Get-Credential 
                if(-not $Credential){
                    throw "Cannot create the CrmServiceClient, no credentials were provided. Credentials are required for an AuthType of Office365."
                }
            }
			$cs+= ";AuthType=Office365"
            $cs+= ";Username=$($Credential.UserName)"
		    $cs+= ";Password='$($Credential.GetNetworkCredential().Password)'"
		}
		elseif($ForceOAuth){
            #use oAuth if requested -ForceOAuth
			Write-Verbose "Params Provided -> ForceOAuth: {$ForceOAuth} ClientId: {$OAuthClientId} RedirectUri: {$OAuthRedirectUri}"
            #try to use the credentials if they're provided
            if($Credential){
                Write-Verbose "Using provided credentials for oAuth"
                $cs+= ";Username=$($Credential.UserName)"
		        $cs+= ";Password='$($Credential.GetNetworkCredential().Password)'"
            }else{
                Write-Verbose "No credential provided, attempting single sign on with no credentials in the connectionstring"
            }

			if($OAuthClientId){
			    #use the clientid if provided, else use a provided clientid 
				Write-Verbose "Using provided oAuth clientid"
				$cs += ";AuthType=OAuth;ClientId=$OAuthClientId"
				if($OAuthRedirectUri){
					$cs += ";redirecturi=$OAuthRedirectUri"
				}
			}
			else{
                #else fallback to a known clientid
				$cs+=";AuthType=OAuth;ClientId=2ad88395-b77d-4561-9441-d0e40824f9bc"
				$cs+=";redirecturi=app://5d3e90d6-aa8e-48a8-8f2c-58b45cc67315"
			}
		}

		try
		{
			if(!$cs -or $cs.Length -eq 0){
				throw "Cannot create the CrmServiceClient, the connection string is null"
			}
            #log the connection string to be helpful
            $loggedConnectionString = $cs
            if($Credential){
                $loggedConnectionString = $cs.Replace($Credential.GetNetworkCredential().Password, "*******") 
            }
            Write-Verbose "ConnectionString:{$loggedConnectionString}"

			#$global:conn = New-Object Microsoft.Xrm.Tooling.Connector.CrmServiceClient -ArgumentList $cs
            $global:conn = Get-CrmConnection -ConnectionString $cs

            #ApplyCrmServiceClientObjectTemplate($global:conn)  #applyObjectTemplateFormat

            if($global:conn.LastCrmError -and $global:conn.LastCrmError -match "forbidden with client authentication scheme 'Anonymous'"){
                Write-Error "Warning: Exception encountered when authenticating, if you're using oAuth you might want to include the -username paramter to disambiguate the identity used for authenticate"
            }

			return $global:conn
		}
		catch
		{
			throw $_
		}  
	}
}