# Load the System.Web assembly to access HttpUtility for URL parsing.
Add-Type -AssemblyName System.Web

# Define the Connect-EveApi function. This function handles the initial OAuth 2.0
# authorization flow with the EVE Online SSO server.
function Connect-EveApi {
 # Enable advanced function features like common parameters.
    [CmdletBinding()]
 # Define the parameters for the function.
    param(
 # Client ID provided by CCP for your EVE Online application.
        [string]$ClientId,
 # Secret key provided by CCP for your EVE Online application.
        [string]$SecretKey,
 # The URL where the user will be redirected after authorization. Defaults to localhost for development.
        [string]$CallbackUrl = "https://localhost/callback",
        [string[]]$Scopes
    )

    $scopeString = $Scopes -join ' '
    $state = (New-Guid).ToString()
    # FIX: The EVE API requires the parameter to be 'client_id' (lowercase).
    $authUrl = "https://login.eveonline.com/v2/oauth/authorize/?response_type=code&redirect_uri=$CallbackUrl&client_id=$ClientId&scope=$scopeString&state=$state"
 
 # Inform the user about the next steps.
    Write-Host "Your default browser will now open for EVE Online authentication." -ForegroundColor Yellow
    Write-Host "After logging in and authorizing, copy the ENTIRE URL from your browser's address bar and paste it below."
 # Open the authorization URL in the user's default browser.
    Start-Process $authUrl
 
 # Prompt the user to paste the redirect URL.
    $redirectUrl = Read-Host "`nPaste the full redirect URL from your browser here"
 
 # Attempt to parse the redirect URL to extract the authorization code and state.
    try {
 # Create a Uri object from the pasted URL.
        $uri = [System.Uri]$redirectUrl
 # Parse the query string parameters.
        $queryParts = [System.Web.HttpUtility]::ParseQueryString($uri.Query)
 # Extract the 'code' parameter (authorization code).
        $code = $queryParts['code']
 # Extract the 'state' parameter.
        $returnedState = $queryParts['state']
 
 # Validate the returned state against the original state to prevent CSRF attacks.
        if ($returnedState -ne $state) {
            Write-Error "State mismatch. Authentication cannot be trusted."
            return
        }
 # Check if the authorization code was successfully extracted.
        if (-not $code) {
            Write-Error "Could not find authorization code in the provided URL."
            return
        }
    }
    catch {
        Write-Error "Invalid URL provided. Could not parse the authorization code."
        return
    }
    
 # Use the extracted code to request an access token from the EVE SSO token endpoint.
    # FIX: Standardized all parameter names to PascalCase for the call.
    $token = Get-EveSsoToken -ClientId $ClientId -SecretKey $SecretKey -Code $code
 
 # Use the access token to verify the token and retrieve character information.
    $characterInfo = Get-EveSsoCharacterID -Token $token
    
 # Confirm successful authentication to the user.
    Write-Host "`n✅ Authentication successful for character: $($characterInfo.CharacterName)" -ForegroundColor Green
    
 # Return the character information object, which also contains the token details.
    return $characterInfo
}
# FIX: Removed extra closing brace.

# REFINEMENT: Converted to a standard advanced function.
function Get-EveSsoToken {
    [CmdletBinding()]
 # Define parameters for obtaining an access token.
    param(
 # Client ID for authentication.
        [string]$ClientId,
 # Secret key for authentication.
        [string]$SecretKey,
 # The authorization code received from the SSO callback.
        [string]$Code
    )

    $uri = "https://login.eveonline.com/oauth/token"
    $header = @{
        # FIX: Corrected variable name from $secretkey to $SecretKey to match parameter.
        'Authorization' = ("Basic {0}" -f ([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $ClientId, $SecretKey)))))
        'Content-Type'  = "application/x-www-form-urlencoded"
 # Explicitly set the Host header as required by the API.
        'Host'          = "login.eveonline.com"
    }
 # Define the body parameters for the POST request.
    $parameters = @{
        'grant_type' = 'authorization_code'
 # The authorization code obtained in the Connect-EveApi function.
        'code'       = $Code
    }

    return Invoke-RestMethod -Uri $uri -Method Post -Headers $header -Body $parameters
}

# FIX: Corrected typo in function name ("RefreshToken").
# REFINEMENT: Converted to a standard advanced function.
function Get-EveSsoRefreshToken {
    [CmdletBinding()]
 # Define parameters for refreshing an access token.
    param(
 # The refresh token received from a previous token exchange.
        [string]$RefreshToken,
 # Client ID for authentication.
        [string]$ClientId,
 # Secret key for authentication.
        [string]$SecretKey
    )

    $uri = "https://login.eveonline.com/v2/oauth/token"
    $header = @{
        'Authorization' = ("Basic {0}" -f ([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $ClientId, $SecretKey)))))
        'Content-Type'  = "application/x-www-form-urlencoded"
        'Host'          = "login.eveonline.com"
    }
 # Define the body parameters for the POST request.
    $parameters = @{
        'grant_type'    = 'refresh_token'
 # The refresh token used for the refresh request.
        'refresh_token' = $RefreshToken
    }

 # Send the POST request to the token endpoint to get a new access token.
    return Invoke-RestMethod -Uri $uri -Method Post -Headers $header -Body $parameters
}

# REFINEMENT: Renamed to standard Verb-Noun and converted to advanced function.
function Test-EveSsoAccessToken {
    [CmdletBinding()]
 # Define parameters for testing and potentially refreshing an access token.
    param(
 # The character token object, which includes the access token and expiry information.
        [object]$CharacterToken,
 # Client ID for refreshing the token.
        [string]$ClientId,
 # Secret key for refreshing the token.
        [string]$SecretKey
    )
 
 # Extract the token object from the character token object.
    $token = $CharacterToken.Token
    # REFINEMENT: More reliable DateTime comparison.
 # Parse the expiry time of the access token.
    $expiryTime = [DateTime]::Parse($CharacterToken.ExpiresOn, $null, 'RoundtripKind')
 
 # Check if the access token is expired or about to expire (within the next minute).
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
 # Define parameter for verifying the access token and getting character info.
    param(
        [object]$Token # The full token object
    )

 # Define the URI for the token verification endpoint.
    $uri = "https://login.eveonline.com/v2/oauth/verify"
 # Define the headers for the GET request.
    $header = @{
 # Include the access token in the Authorization header.
        'Authorization' = "Bearer $($token.access_token)"
 # Explicitly set the Host header.
        'Host'          = "login.eveonline.com"
    }
 
 # Send the GET request to the verification endpoint.
    $characterToken = Invoke-RestMethod -Uri $uri -Method Get -Headers $header
    
 # Add the original token object as a NoteProperty to the returned character info object for easy access.
    $characterToken | Add-Member -MemberType NoteProperty -Name Token -Value $token -Force
    return $characterToken
}