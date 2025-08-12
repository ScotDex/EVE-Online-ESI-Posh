Add-Type -AssemblyName System.Web

function Connect-EveApi {
    [CmdletBinding()]
    param(
        [string]$ClientId,
        [string]$SecretKey,
        [string]$CallbackUrl = "https://localhost/callback",
        [string[]]$Scopes
    )

    $scopeString = $Scopes -join ' '
    $state = (New-Guid).ToString()
    # FIX: The EVE API requires the parameter to be 'client_id' (lowercase).
    $authUrl = "https://login.eveonline.com/v2/oauth/authorize/?response_type=code&redirect_uri=$CallbackUrl&client_id=$ClientId&scope=$scopeString&state=$state"

    Write-Host "Your default browser will now open for EVE Online authentication." -ForegroundColor Yellow
    Write-Host "After logging in and authorizing, copy the ENTIRE URL from your browser's address bar and paste it below."
    Start-Process $authUrl

    $redirectUrl = Read-Host "`nPaste the full redirect URL from your browser here"

    try {
        $uri = [System.Uri]$redirectUrl
        $queryParts = [System.Web.HttpUtility]::ParseQueryString($uri.Query)
        $code = $queryParts['code']
        $returnedState = $queryParts['state']
        
        if ($returnedState -ne $state) {
            Write-Error "State mismatch. Authentication cannot be trusted."
            return
        }
        if (-not $code) {
            Write-Error "Could not find authorization code in the provided URL."
            return
        }
    }
    catch {
        Write-Error "Invalid URL provided. Could not parse the authorization code."
        return
    }
    
    # FIX: Standardized all parameter names to PascalCase for the call.
    $token = Get-EveSsoToken -ClientId $ClientId -SecretKey $SecretKey -Code $code

    $characterInfo = Get-EveSsoCharacterID -Token $token
    
    Write-Host "`n✅ Authentication successful for character: $($characterInfo.CharacterName)" -ForegroundColor Green
    
    return $characterInfo
}
# FIX: Removed extra closing brace.

# REFINEMENT: Converted to a standard advanced function.
function Get-EveSsoToken {
    [CmdletBinding()]
    param(
        [string]$ClientId,
        [string]$SecretKey,
        [string]$Code
    )

    $uri = "https://login.eveonline.com/oauth/token"
    $header = @{
        # FIX: Corrected variable name from $secretkey to $SecretKey to match parameter.
        'Authorization' = ("Basic {0}" -f ([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $ClientId, $SecretKey)))))
        'Content-Type'  = "application/x-www-form-urlencoded"
        'Host'          = "login.eveonline.com"
    }
    $parameters = @{
        'grant_type' = 'authorization_code'
        'code'       = $Code
    }

    return Invoke-RestMethod -Uri $uri -Method Post -Headers $header -Body $parameters
}

# FIX: Corrected typo in function name ("RefreshToken").
# REFINEMENT: Converted to a standard advanced function.
function Get-EveSsoRefreshToken {
    [CmdletBinding()]
    param(
        [string]$RefreshToken,
        [string]$ClientId,
        [string]$SecretKey
    )

    $uri = "https://login.eveonline.com/v2/oauth/token"
    $header = @{
        'Authorization' = ("Basic {0}" -f ([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $ClientId, $SecretKey)))))
        'Content-Type'  = "application/x-www-form-urlencoded"
        'Host'          = "login.eveonline.com"
    }
    $parameters = @{
        'grant_type'    = 'refresh_token'
        'refresh_token' = $RefreshToken
    }

    return Invoke-RestMethod -Uri $uri -Method Post -Headers $header -Body $parameters
}

# REFINEMENT: Renamed to standard Verb-Noun and converted to advanced function.
function Test-EveSsoAccessToken {
    [CmdletBinding()]
    param(
        [object]$CharacterToken,
        [string]$ClientId,
        [string]$SecretKey
    )

    $token = $CharacterToken.Token
    # REFINEMENT: More reliable DateTime comparison.
    $expiryTime = [DateTime]::Parse($CharacterToken.ExpiresOn, $null, 'RoundtripKind')
    
    if ($expiryTime -lt (Get-Date).ToUniversalTime().AddMinutes(1)) {
        Write-Verbose "Access token is expired or expiring soon. Refreshing..."
        # FIX: Corrected function call to use the renamed Get-EveSsoRefreshToken.
        $newToken = Get-EveSsoRefreshToken -RefreshToken $token.refresh_token -ClientId $ClientId -SecretKey $SecretKey
        return Get-EveSsoCharacterID -Token $newToken
    }
    
    # If token is still valid, return the original object.
    return $CharacterToken
}

# REFINEMENT: Converted to a standard advanced function.
function Get-EveSsoCharacterID {
    [CmdletBinding()]
    param(
        [object]$Token # The full token object
    )

    $uri = "https://login.eveonline.com/v2/oauth/verify"
    $header = @{
        'Authorization' = "Bearer $($token.access_token)"
        'Host'          = "login.eveonline.com"
    }

    $characterToken = Invoke-RestMethod -Uri $uri -Method Get -Headers $header
    
    $characterToken | Add-Member -MemberType NoteProperty -Name Token -Value $token -Force
    return $characterToken
}