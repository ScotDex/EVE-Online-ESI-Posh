# File: function.template.ps1

# This is a template for generating PowerShell functions that interact with the EVE Online ESI API.
# The parts enclosed in curly braces {} are placeholders that will be replaced by a script
# that reads the ESI Swagger/OpenAPI specification and generates the actual function code.

# Defines a PowerShell function. {FunctionName} will be replaced by the name of the cmdlet,
# typically in a Verb-Noun format like Get-EsiCharactersCharacterId.
function {FunctionName} {
    <#
    .SYNOPSIS
        # {Synopsis} will be replaced by a brief description of the function's purpose,
        # extracted from the ESI specification.
        {Synopsis}
    .DESCRIPTION
        # {Description} will be replaced by a more detailed description of the function,
        # extracted from the ESI specification.
        {Description}
    #>
    [CmdletBinding()]
    param(
        # The generator will build this entire block of parameters
        {ParameterBlock}
    )

    # --- Static Logic ---
    # This section contains logic that is common to all generated functions and
    # doesn't depend on the specific ESI endpoint being called.

    # Sets the base URI for the ESI endpoint. {UriPath} will be replaced by the specific
    # path for this endpoint, e.g., /v5/characters/{character_id}/.
    $URI = "https://esi.evetech.net{UriPath}"
    # Sets the HTTP method for the request (e.g., GET, POST, PUT, DELETE).
    $Method = "{Method}"
    # Initializes an empty hashtable for request headers.
    $Header = @{}
    # Initializes the request body to null.
    $Body = $null

    # --- Dynamically Generated Logic ---
    # This section contains logic that is specific to the ESI endpoint being called.
    # The generator script analyzes the ESI specification for the endpoint and
    # generates the necessary code to handle parameters and build the request.

    # {QueryParameterLogic} will be replaced by code that handles query parameters.
    # It will take the values provided to the cmdlet parameters and add them to the $URI.
    {QueryParameterLogic}

    # {HeaderLogic} will be replaced by code that handles request headers.
    # It will take the values provided to the cmdlet parameters and add them to the $Header hashtable.
    {HeaderLogic}
    
    # {PathParameterLogic} will be replaced by code that handles path parameters.
    # It will take the values provided to the cmdlet parameters and substitute them into the {UriPath} placeholder in the $URI.
    {PathParameterLogic}

    # {BodyLogic} will be replaced by code that handles the request body,
    # typically for POST or PUT requests. It will take the values provided to the
    # cmdlet parameters and format them as the request body ($Body).
    {BodyLogic}

    # Call the central helper function to execute the request
    # NOTE: You will need to have a robust 'Invoke-EsiRequest' function available.
    Invoke-EsiRequest -URI $URI -Method $Method -Header $Header -Body $Body -OutputType $OutputType
}
# Exports the generated function so it's available when the module is imported.
# {FunctionName} ensures that the correct function name is exported.
Export-ModuleMember -Function {FunctionName}