#Dot source all functions in all ps1 files located in the module's public and private folders, excluding tests and profiles.
Get-ChildItem -Path $PSScriptRoot\private\*.ps1 -Exclude *.tests.ps1, *profile.ps1 -ErrorAction SilentlyContinue |
ForEach-Object {
    . $_.FullName
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

                $response = $templateManager.GenerateTemplate(($postParams|ConvertTo-Json)).GetAwaiter().GetResult() | ConvertFrom-Json

                if($response.Data.Template) {

                    $response.Data.Template = $response.Data.Template -replace '\\"', '"'

                    $jsonFormatedTemplate = $response.Data.Template | ConvertFrom-Json `
                    | ConvertTo-Json -Depth 100 | `
                    %{ `
                        [Regex]::Replace($_, "\\u(?<Value>[a-zA-Z0-9]{4})", { `
                            param($m) ([char]([int]::Parse($m.Groups['Value'].Value, `
                            [System.Globalization.NumberStyles]::HexNumber))).ToString() } ) `
                    } | Format-Json -Indentation 2

                    if($OutputToFile) {
                        $jsonFormatedTemplate | Out-File $OutputToFile
                        Write-Host "Template created at " $OutputToFile
                    }
                    else {
                        $pathInfo = Get-Location

                        $outputPath = Join-Path -Path $pathInfo.Path -ChildPath "\template.json"

                        $jsonFormatedTemplate | Out-File $outputPath
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

function Format-Json {
    <#
    .SYNOPSIS
        Prettifies JSON output.
    .DESCRIPTION
        Reformats a JSON string so the output looks better than what ConvertTo-Json outputs.
    .PARAMETER Json
        Required: [string] The JSON text to prettify.
    .PARAMETER Minify
        Optional: Returns the json string compressed.
    .PARAMETER Indentation
        Optional: The number of spaces (1..1024) to use for indentation. Defaults to 4.
    .PARAMETER AsArray
        Optional: If set, the output will be in the form of a string array, otherwise a single string is output.
    .EXAMPLE
        $json | ConvertTo-Json  | Format-Json -Indentation 2
    #>
    [CmdletBinding(DefaultParameterSetName = 'Prettify')]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Json,

        [Parameter(ParameterSetName = 'Minify')]
        [switch]$Minify,

        [Parameter(ParameterSetName = 'Prettify')]
        [ValidateRange(1, 1024)]
        [int]$Indentation = 4,

        [Parameter(ParameterSetName = 'Prettify')]
        [switch]$AsArray
    )

    if ($PSCmdlet.ParameterSetName -eq 'Minify') {
        return ($Json | ConvertFrom-Json) | ConvertTo-Json -Depth 100 -Compress
    }

    # If the input JSON text has been created with ConvertTo-Json -Compress
    # then we first need to reconvert it without compression
    if ($Json -notmatch '\r?\n') {
        $Json = ($Json | ConvertFrom-Json) | ConvertTo-Json -Depth 100
    }

    $indent = 0
    $regexUnlessQuoted = '(?=([^"]*"[^"]*")*[^"]*$)'

    $result = $Json -split '\r?\n' |
        ForEach-Object {
            # If the line contains a ] or } character, 
            # we need to decrement the indentation level, unless:
            #   - it is inside quotes, AND
            #   - it does not contain a [ or {
            if (($_ -match "[}\]]$regexUnlessQuoted") -and ($_ -notmatch "[\{\[]$regexUnlessQuoted")) {
                $indent = [Math]::Max($indent - $Indentation, 0)
            }

            # Replace all colon-space combinations by ": " unless it is inside quotes.
            $line = (' ' * $indent) + ($_.TrimStart() -replace ":\s+$regexUnlessQuoted", ': ')

            # If the line contains a [ or { character, 
            # we need to increment the indentation level, unless:
            #   - it is inside quotes, AND
            #   - it does not contain a ] or }
            if (($_ -match "[\{\[]$regexUnlessQuoted") -and ($_ -notmatch "[}\]]$regexUnlessQuoted")) {
                $indent += $Indentation
            }

            $line
        }

    if ($AsArray) { return $result }
    return $result -Join [Environment]::NewLine
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