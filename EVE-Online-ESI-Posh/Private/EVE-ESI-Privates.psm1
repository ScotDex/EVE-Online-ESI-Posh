function Invoke-EsiRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Uri,
        [Parameter(Mandatory)]
        [string]$Method,
        [object]$Body,
        [hashtable]$Headers,
        [int]$RetryCount = 3
    )

    # A simple 'for' loop is a much cleaner way to handle retries.
    for ($attempt = 1; $attempt -le $RetryCount; $attempt++) {
        try {
            # Use Invoke-RestMethod for JSON APIs. It's simpler and more direct.
            $params = @{
                Uri         = $Uri
                Method      = $Method
                Headers     = $Headers
                ContentType = 'application/json'
                ErrorAction = 'Stop'
            }
            if ($Body) {
                $params.Add('Body', ($Body | ConvertTo-Json -Depth 5))
            }

            Write-Verbose "Attempt $attempt: Sending $Method request to $Uri"
            return Invoke-RestMethod @params
        }
        catch {
            # This is the new, clean error handling block.
            $statusCode = $_.Exception.Response.StatusCode
            Write-Warning "Attempt $attempt failed. Status Code: $statusCode. Details: $($_.Exception.Message)"

            # A 'switch' statement is much cleaner than a long if/elseif block.
            switch ($statusCode) {
                { $_ -in 502, 503, 504 } { # Transient Server Errors
                    Write-Warning "Transient server error detected. Retrying in 5 seconds..."
                    Start-Sleep -Seconds 5
                    continue # Go to the next iteration of the loop
                }
                420 { # ESI Rate Limit Error
                    $resetInSeconds = $_.Exception.Response.Headers['X-Esi-Error-Limit-Reset']
                    Write-Warning "ESI error limit reached. Waiting for $resetInSeconds seconds..."
                    Start-Sleep -Seconds $resetInSeconds
                    continue # Go to the next iteration of the loop
                }
                default {
                    # For any other error (like 401/403 auth errors), fail immediately.
                    throw "A non-recoverable error occurred: $statusCode"
                }
            }
        }
    }

    # If the loop finishes without success, throw a final error.
    throw "The request failed after $RetryCount attempts."
}
