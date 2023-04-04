function global:Get-KvAccessToken {
    [CmdletBinding()] 
    Param()

    PROCESS {
        [Console]::ResetColor()

        $useAzContext = $false
        $contextAvailable = $false

        if (Get-Module -ListAvailable -Name Az.Accounts) {

            if (Test-CommandExists Get-AzContext) {
                $contextCheck = Get-AzContext

                Write-Verbose "CommandExists Get-AzContext"

                if ($null -ne $contextCheck.Account -And $null -ne $contextCheck.Environment -And $null -ne $contextCheck.Tenant) {
                    $useAzContext = $true
                    $contextAvailable = $true
                }
            }
        }

        if ((Get-Module -ListAvailable -Name AzureRm) -And ($useAzContext -eq $false)) {

            if (Test-CommandExists Get-AzureRmContext) {
                $currentAzureContext = Get-AzureRmContext

                Write-Verbose "CommandExists Get-AzureRmContext"

                if ($null -ne $currentAzureContext.Account -And $null -ne $currentAzureContext.Environment -And $null -ne $currentAzureContext.Tenant) {
                    $useAzContext = $false
                    $contextAvailable = $true
                }
            }
            else
            {
                Write-Verbose "No attempt will be made to get an Azure token."
            }
        } 
        
        try
        {
            if ($contextAvailable -And $useAzContext) {
                
                Write-Verbose "Getting Azure token using Az Context."
                
                $keyvaultresource = "https://vault.azure.net"
                $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
                $token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, $keyvaultresource).AccessToken
   
                Write-Output $token
            }elseif($contextAvailable -And ($useAzContext -eq $false)) {
            
                Write-Verbose "Getting Azure token using AzureRM Context."

                #https://github.com/Azure/azure-powershell/issues/4818
                $tokenCache = $currentAzureContext.TokenCache
                $cachedTokens = $tokenCache.ReadItems() | Where-Object { $_.TenantId -eq $currentAzureContext.Tenant.Id.ToString() }
                $RefreshToken = $cachedTokens.RefreshToken

                $url = "https://login.windows.net/$($currentAzureContext.Tenant.Id.ToString())/oauth2/token"
                $body = "grant_type=refresh_token&refresh_token=$($RefreshToken)"
                $body += "&resource=https%3A%2F%2Fvault.azure.net"
                $response = Invoke-RestMethod $url -Method POST -Body $body
                Write-Output $response.access_token
            }
            else
            {
                Write-Warning "No Azure Context found, please log in using your Azure account."
            }
        }
        catch
        {
             return;
        }
    }
}