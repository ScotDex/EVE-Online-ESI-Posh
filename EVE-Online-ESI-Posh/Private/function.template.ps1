# File: function.template.ps1

function {FunctionName} {
    <#
    .SYNOPSIS
        {Synopsis}
    .DESCRIPTION
        {Description}
    #>
    [CmdletBinding()]
    param(
        # The generator will build this entire block of parameters
        {ParameterBlock}
    )

    # --- Static Logic ---
    $URI = "https://esi.evetech.net{UriPath}"
    $Method = "{Method}"
    $Header = @{}
    $Body = $null

    # --- Dynamically Generated Logic ---
    {QueryParameterLogic}

    {HeaderLogic}
    
    {PathParameterLogic}

    {BodyLogic}

    # Call the central helper function to execute the request
    # NOTE: You will need to have a robust 'Invoke-EsiRequest' function available.
    Invoke-EsiRequest -URI $URI -Method $Method -Header $Header -Body $Body -OutputType $OutputType
}
Export-ModuleMember -Function {FunctionName}