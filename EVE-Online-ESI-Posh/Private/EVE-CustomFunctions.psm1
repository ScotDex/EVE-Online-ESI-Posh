function Get-CommandDefaultParameter
{
	<#
	.SYNOPSIS
	Retrieves the default parameter values for a given PowerShell command.
	.DESCRIPTION
	This function parses the Abstract Syntax Tree (AST) of a specified command's script block to identify parameters that have default values defined and returns them in a hashtable.
	#>
	[CmdletBinding()]
	[OutputType([hashtable])]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$CommandName
	)
	try
	{	
		# Get the command object using get-command. Stop on error if the command is not found.
		$command = get-command $CommandName -ErrorAction Stop
		
		# Access the Abstract Syntax Tree (AST) of the command's script block.
		$ast = $command.ScriptBlock.Ast

		# Find all nodes in the AST that are of type ParameterAst (representing parameters).
		# The second argument '$true' ensures that the search includes nested nodes.
		# Filter these parameter nodes to only include those that have a DefaultValue defined.
		# Then, process each matching parameter node.
        $defaultParamsHashtable = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.ParameterAst] }, $true) |
            Where-Object { $_.DefaultValue } |
            ForEach-Object -Begin { @{} } -Process {
                # Get the parameter name from the variable path of the parameter node.
                $name = $_.Name.VariablePath.UserPath
                
                # Get the default value as text from the extent of the DefaultValue property.
                # Trim any single or double quotes from the beginning and end of the value string.
                $value = $_.DefaultValue.Extent.Text.Trim("'").Trim('"')
                
                # Add the key-value pair to the hash table
                $PSItem[$name] = $value
            }
		# Return the created hashtable containing the default parameter values.
		return $defaultParamsHashtable
catch{
	# If an error occurs during the process (e.g., command not found or issues parsing AST), write an error message.
	write-Error -message "Failed to analyse $CommandName"
}