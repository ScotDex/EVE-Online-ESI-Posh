# File: Build-Module.ps1

# --- 1. SETUP ---
Set-Location "F:\GitHub\EVE-Online-ESI-Posh\" # Set to your project root
$templatePath = ".\function.template.ps1"

# --- 2. CHECK API VERSION ---
Write-Host "Fetching latest ESI Swagger specification..." -ForegroundColor Cyan
$ModSwagger = Invoke-RestMethod -Uri "https://esi.evetech.net/_latest/swagger.json?datasource=tranquility"
$ManiFestFile = Get-Item '.\EVE-Online-ESI-Posh\EVE-Online-ESI-Posh.psd1'
$CurrentSwaggerVersion = (Get-Content $ManiFestFile.FullName | Where-Object { $_ -like "ModuleVersion = *" }).Split("'")[1]

if ($CurrentSwaggerVersion -eq $ModSwagger.info.version) {
    Write-Host "Module version ($CurrentSwaggerVersion) is already up to date with the ESI spec. Nothing to do." -ForegroundColor Green
    exit
}
Write-Host "New ESI version detected ($($ModSwagger.info.version)). Rebuilding module..." -ForegroundColor Yellow

# --- 3. ANALYSIS PASS: Parse the API spec into structured objects ---
Write-Host "Analyzing API endpoints..."
$AllPathEndpoints = $ModSwagger.paths.PSObject.Properties
$BuildFunctions = foreach ($PathEndpoint in $AllPathEndpoints) {
    $CurrentEndPoint = $ModSwagger.paths.$($PathEndpoint.name)
    $Methods = ($CurrentEndPoint.PSObject.Properties).Name

    foreach ($Method in $Methods) {
        $CurrentEndPointDetails = $CurrentEndPoint.$Method
        
        # Resolve any referenced parameters
        $ESIParameters = foreach ($ESIParameter in $CurrentEndPointDetails.parameters) {
            if ($ESIParameter.'$ref') {
                $refName = $ESIParameter.'$ref'.Split('/')[-1]
                $ModSwagger.parameters.$refName
            }
            else { $ESIParameter }
        }

        # Create an intermediate object holding all the info needed to build a function
        [PSCustomObject]@{
            FunctionName    = ($CurrentEndPointDetails.operationId -replace "_", "-") # Convert to Verb-Noun-ish
            Version         = $ModSwagger.info.version
            ESIMethod       = $Method.ToUpper()
            ESIPath         = $PathEndpoint.Name
            ESIParameters   = $ESIParameters
            ESITags         = $CurrentEndPointDetails.tags
            ESISummary      = $CurrentEndPointDetails.summary
            ESIDescription  = $CurrentEndPointDetails.description
        }
    }
}
Write-Host "Analysis complete. Found $($BuildFunctions.Count) API endpoints."

# --- 4. GENERATION PASS: Use the template to write the module files ---
Write-Host "Generating module files..."
$templateContent = Get-Content -Path $templatePath -Raw
$outputRoot = ".\EVE-Online-ESI-Posh\Public"

# Group functions by their API tag and create a .psm1 file for each
$BuildFunctions.ESITags | Select-Object -Unique | Sort-Object | ForEach-Object {
    $tagName = $_
    $outputFile = Join-Path -Path $outputRoot -ChildPath "$($tagName).psm1"
    Write-Host "  Generating file for tag: $tagName -> $($outputFile)"
    # Clear the file to start fresh
    Clear-Content -Path $outputFile

    $functionsForThisFile = $BuildFunctions | Where-Object { $tagName -in $_.ESITags } | Sort-Object FunctionName

    foreach ($functionInfo in $functionsForThisFile) {
        # Build the dynamic parts of the function from our structured object
        $parameterBlockLines = @()
        $queryLogicLines = @()
        $headerLogicLines = @()
        $pathLogicLines = @()
        $bodyLogicLines = @()

        # Dynamically build the parameter block based on the API spec
        foreach ($param in $functionInfo.ESIParameters) {
            if ($param.required) { $parameterBlockLines += "        [Parameter(Mandatory)]" }
            # Add more logic here for types, ValidateSet, etc.
            $paramName = $param.name -replace '-', '_' # Ensure valid variable name
            $parameterBlockLines += "        [string]`$$($paramName)"
        }
        $parameterBlockLines += '        [Parameter(Mandatory=$false)] [ValidateSet("PS","json","PSfull")] [string]$OutputType = "PS"'
        $parameterBlockString = $parameterBlockLines -join "`r`n"

        # Dynamically build the logic for handling different parameter types
        # (This is a simplified example; a full implementation would be more complex)
        foreach ($param in $functionInfo.ESIParameters) {
            $paramName = $param.name -replace '-', '_'
            switch ($param.in) {
                'path'  { $pathLogicLines += "    `$URI = `$URI -replace '{'$($param.name)'}', `$$($paramName)" }
                'query' { $queryLogicLines += "    if (`$PSBoundParameters.ContainsKey('$($paramName)')) { `$URI = Add-QueryParameter -Uri `$URI -Key '$($param.name)' -Value `$$($paramName) }" }
                'header'{ $headerLogicLines += "    `$Header['$($param.name)'] = `$$($paramName)" }
                'body'  { $bodyLogicLines += "    `$Body = `$$($paramName)" }
            }
        }
        
        # Replace placeholders in the template with our generated code blocks
        $finalFunctionCode = $templateContent -replace '\{FunctionName\}', $functionInfo.FunctionName `
                                              -replace '\{Synopsis\}', $functionInfo.ESISummary `
                                              -replace '\{Description\}', $functionInfo.ESIDescription `
                                              -replace '\{ParameterBlock\}', $parameterBlockString `
                                              -replace '\{Method\}', $functionInfo.ESIMethod `
                                              -replace '\{UriPath\}', $functionInfo.ESIPath `
                                              -replace '\{QueryParameterLogic\}', ($queryLogicLines -join "`r`n") `
                                              -replace '\{HeaderLogic\}', ($headerLogicLines -join "`r`n") `
                                              -replace '\{PathParameterLogic\}', ($pathLogicLines -join "`r`n") `
                                              -replace '\{BodyLogic\}', ($bodyLogicLines -join "`r`n")

        # Write the completed function text to the file
        $finalFunctionCode | Add-Content -Path $outputFile
    }
}

# --- 5. FINALIZE ---
Write-Host "Updating module manifest..."
Update-ModuleManifest -Path $ManiFestFile.FullName -ModuleVersion $ModSwagger.info.version -Description $ModSwagger.info.description
Write-Host "✅ Module rebuild complete." -ForegroundColor Green