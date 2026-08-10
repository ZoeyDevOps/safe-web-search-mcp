# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Zoey and contributors

[CmdletBinding()]
param(
    [string]$ServerPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

if ([string]::IsNullOrWhiteSpace($ServerPath)) {
    $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ServerPath = Join-Path (Split-Path -Parent $scriptDirectory) 'src\server.ps1'
}

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-ExactProperty {
    param(
        [Parameter(Mandatory = $true)][object]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )

    foreach ($property in $InputObject.PSObject.Properties) {
        if ([string]::Equals($property.Name, $Name, [StringComparison]::Ordinal)) {
            return $property
        }
    }
    return $null
}

function ConvertTo-Frame {
    param([Parameter(Mandatory = $true)][object]$Value)

    return (ConvertTo-Json -InputObject $Value -Depth 20 -Compress)
}

function Assert-ResponseId {
    param(
        [Parameter(Mandatory = $true)][object]$Response,
        [Parameter(Mandatory = $true)][AllowNull()]$ExpectedId,
        [Parameter(Mandatory = $true)][string]$CaseName
    )

    $idProperty = Get-ExactProperty -InputObject $Response -Name 'id'
    Assert-True ($null -ne $idProperty) "$CaseName`: response has no exact-case id member."
    $actualId = $idProperty.Value

    if ($null -eq $ExpectedId) {
        Assert-True ($null -eq $actualId) "$CaseName`: expected a null response id."
        return
    }

    if ($ExpectedId -is [string]) {
        Assert-True ($actualId -is [string]) "$CaseName`: string id changed JSON type."
        Assert-True ([string]::Equals([string]$actualId, [string]$ExpectedId, [StringComparison]::Ordinal)) "$CaseName`: response id did not correlate."
        return
    }

    Assert-True (($actualId -is [int]) -or ($actualId -is [long])) "$CaseName`: integer id changed JSON type."
    Assert-True ([long]$actualId -eq [long]$ExpectedId) "$CaseName`: response id did not correlate."
}

function Assert-ResponseBase {
    param(
        [Parameter(Mandatory = $true)][object]$Response,
        [Parameter(Mandatory = $true)][AllowNull()]$ExpectedId,
        [Parameter(Mandatory = $true)][string]$CaseName
    )

    $jsonrpcProperty = Get-ExactProperty -InputObject $Response -Name 'jsonrpc'
    Assert-True ($null -ne $jsonrpcProperty) "$CaseName`: response has no exact-case jsonrpc member."
    Assert-True ($jsonrpcProperty.Value -is [string]) "$CaseName`: jsonrpc is not a string."
    Assert-True ([string]$jsonrpcProperty.Value -ceq '2.0') "$CaseName`: jsonrpc is not exactly 2.0."
    Assert-ResponseId -Response $Response -ExpectedId $ExpectedId -CaseName $CaseName
}

function Assert-ErrorResponse {
    param(
        [Parameter(Mandatory = $true)][object]$Response,
        [Parameter(Mandatory = $true)][AllowNull()]$ExpectedId,
        [Parameter(Mandatory = $true)][int]$ExpectedCode,
        [Parameter(Mandatory = $true)][string]$ExpectedMessage,
        [Parameter(Mandatory = $true)][string]$CaseName
    )

    Assert-ResponseBase -Response $Response -ExpectedId $ExpectedId -CaseName $CaseName
    Assert-True ($null -eq (Get-ExactProperty -InputObject $Response -Name 'result')) "$CaseName`: error response also contains result."
    $errorProperty = Get-ExactProperty -InputObject $Response -Name 'error'
    Assert-True ($null -ne $errorProperty) "$CaseName`: response has no error member."
    $codeProperty = Get-ExactProperty -InputObject $errorProperty.Value -Name 'code'
    $messageProperty = Get-ExactProperty -InputObject $errorProperty.Value -Name 'message'
    Assert-True ($null -ne $codeProperty -and [int]$codeProperty.Value -eq $ExpectedCode) "$CaseName`: wrong JSON-RPC error code."
    Assert-True ($null -ne $messageProperty -and [string]$messageProperty.Value -ceq $ExpectedMessage) "$CaseName`: wrong JSON-RPC error message."
}

function Assert-EmptyResultResponse {
    param(
        [Parameter(Mandatory = $true)][object]$Response,
        [Parameter(Mandatory = $true)][AllowNull()]$ExpectedId,
        [Parameter(Mandatory = $true)][string]$CaseName
    )

    Assert-ResponseBase -Response $Response -ExpectedId $ExpectedId -CaseName $CaseName
    Assert-True ($null -eq (Get-ExactProperty -InputObject $Response -Name 'error')) "$CaseName`: result response also contains error."
    $resultProperty = Get-ExactProperty -InputObject $Response -Name 'result'
    Assert-True ($null -ne $resultProperty) "$CaseName`: response has no result member."
    Assert-True (@($resultProperty.Value.PSObject.Properties).Count -eq 0) "$CaseName`: expected an empty result object."
}

function Assert-InitializeResponse {
    param(
        [Parameter(Mandatory = $true)][object]$Response,
        [Parameter(Mandatory = $true)][AllowNull()]$ExpectedId,
        [Parameter(Mandatory = $true)][string]$ExpectedProtocolVersion,
        [Parameter(Mandatory = $true)][string]$CaseName
    )

    Assert-ResponseBase -Response $Response -ExpectedId $ExpectedId -CaseName $CaseName
    $resultProperty = Get-ExactProperty -InputObject $Response -Name 'result'
    Assert-True ($null -ne $resultProperty) "$CaseName`: response has no result."
    $protocolProperty = Get-ExactProperty -InputObject $resultProperty.Value -Name 'protocolVersion'
    Assert-True ($null -ne $protocolProperty -and [string]$protocolProperty.Value -ceq $ExpectedProtocolVersion) "$CaseName`: wrong negotiated protocol version."
    $serverInfoProperty = Get-ExactProperty -InputObject $resultProperty.Value -Name 'serverInfo'
    Assert-True ($null -ne $serverInfoProperty) "$CaseName`: response has no serverInfo."
    $nameProperty = Get-ExactProperty -InputObject $serverInfoProperty.Value -Name 'name'
    $versionProperty = Get-ExactProperty -InputObject $serverInfoProperty.Value -Name 'version'
    Assert-True ($null -ne $nameProperty -and [string]$nameProperty.Value -ceq 'safe-web-search') "$CaseName`: wrong server name."
    Assert-True ($null -ne $versionProperty -and [string]$versionProperty.Value -ceq '1.0.0') "$CaseName`: wrong server version."
}

function Assert-ToolsListResponse {
    param(
        [Parameter(Mandatory = $true)][object]$Response,
        [Parameter(Mandatory = $true)][AllowNull()]$ExpectedId,
        [Parameter(Mandatory = $true)][string]$CaseName
    )

    Assert-ResponseBase -Response $Response -ExpectedId $ExpectedId -CaseName $CaseName
    $resultProperty = Get-ExactProperty -InputObject $Response -Name 'result'
    $toolsProperty = Get-ExactProperty -InputObject $resultProperty.Value -Name 'tools'
    $tools = @($toolsProperty.Value)
    Assert-True ($tools.Count -eq 1) "$CaseName`: expected exactly one tool."
    $tool = $tools[0]
    Assert-True ([string](Get-ExactProperty -InputObject $tool -Name 'name').Value -ceq 'search_web') "$CaseName`: wrong tool name."
    $description = [string](Get-ExactProperty -InputObject $tool -Name 'description').Value
    Assert-True ($description -match 'unverified' -and $description -match 'does not open pages' -and $description -match 'financial') "$CaseName`: tool description omits result-trust or high-stakes limits."
    $schema = (Get-ExactProperty -InputObject $tool -Name 'inputSchema').Value
    Assert-True ((Get-ExactProperty -InputObject $schema -Name 'additionalProperties').Value -eq $false) "$CaseName`: schema permits unknown fields."
    $properties = (Get-ExactProperty -InputObject $schema -Name 'properties').Value
    $query = (Get-ExactProperty -InputObject $properties -Name 'query').Value
    $maxResults = (Get-ExactProperty -InputObject $properties -Name 'max_results').Value
    Assert-True ([int](Get-ExactProperty -InputObject $query -Name 'maxLength').Value -eq 300) "$CaseName`: wrong query maximum."
    Assert-True ([int](Get-ExactProperty -InputObject $maxResults -Name 'minimum').Value -eq 1) "$CaseName`: wrong result minimum."
    Assert-True ([int](Get-ExactProperty -InputObject $maxResults -Name 'maximum').Value -eq 6) "$CaseName`: wrong result maximum."
    $annotations = (Get-ExactProperty -InputObject $tool -Name 'annotations').Value
    Assert-True ((Get-ExactProperty -InputObject $annotations -Name 'readOnlyHint').Value -eq $true) "$CaseName`: tool is not marked read-only."
    Assert-True ((Get-ExactProperty -InputObject $annotations -Name 'destructiveHint').Value -eq $false) "$CaseName`: destructive hint changed."
    Assert-True ((Get-ExactProperty -InputObject $annotations -Name 'openWorldHint').Value -eq $true) "$CaseName`: open-world hint changed."
}

function Assert-ToolErrorResponse {
    param(
        [Parameter(Mandatory = $true)][object]$Response,
        [Parameter(Mandatory = $true)][AllowNull()]$ExpectedId,
        [Parameter(Mandatory = $true)][string]$ExpectedText,
        [Parameter(Mandatory = $true)][string]$CaseName
    )

    Assert-ResponseBase -Response $Response -ExpectedId $ExpectedId -CaseName $CaseName
    $resultProperty = Get-ExactProperty -InputObject $Response -Name 'result'
    Assert-True ($null -ne $resultProperty) "$CaseName`: response has no result."
    $isErrorProperty = Get-ExactProperty -InputObject $resultProperty.Value -Name 'isError'
    Assert-True ($null -ne $isErrorProperty -and $isErrorProperty.Value -eq $true) "$CaseName`: tool error is not marked isError."
    $contentProperty = Get-ExactProperty -InputObject $resultProperty.Value -Name 'content'
    $content = @($contentProperty.Value)
    Assert-True ($content.Count -eq 1) "$CaseName`: expected one error content item."
    Assert-True ([string](Get-ExactProperty -InputObject $content[0] -Name 'type').Value -ceq 'text') "$CaseName`: error content is not text."
    Assert-True ([string](Get-ExactProperty -InputObject $content[0] -Name 'text').Value -ceq $ExpectedText) "$CaseName`: wrong tool error text."
}

$inputLines = New-Object System.Collections.ArrayList
$expectations = New-Object System.Collections.ArrayList

function Add-ExpectedFrame {
    param(
        [Parameter(Mandatory = $true)][string]$Line,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('Error', 'EmptyResult', 'Initialize', 'ToolsList', 'ToolError')][string]$Kind,
        [Parameter(Mandatory = $true)][AllowNull()]$Id,
        [int]$Code = 0,
        [string]$Detail = ''
    )

    $null = $inputLines.Add($Line)
    $null = $expectations.Add([pscustomobject]@{
        Name = $Name
        Kind = $Kind
        Id = $Id
        Code = $Code
        Detail = $Detail
    })
}

function Add-NotificationFrame {
    param([Parameter(Mandatory = $true)][string]$Line)
    $null = $inputLines.Add($Line)
}

$invalidRequest = 'Invalid Request.'
$invalidParams = 'Invalid params.'
$argumentError = 'Invalid search_web arguments: query must be a string and no unknown fields are allowed.'
$maxResultsError = 'Invalid search_web arguments: max_results must be an integer from 1 to 6.'

Add-ExpectedFrame -Line '{' -Name 'malformed JSON' -Kind Error -Id $null -Code -32700 -Detail 'Parse error.'
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'recover-1'; method = 'ping' })) -Name 'recovery after malformed JSON' -Kind EmptyResult -Id 'recover-1'
Add-ExpectedFrame -Line '1' -Name 'scalar request' -Kind Error -Id $null -Code -32600 -Detail $invalidRequest
Add-ExpectedFrame -Line '[{}]' -Name 'batch-shaped request' -Kind Error -Id $null -Code -32600 -Detail $invalidRequest
Add-ExpectedFrame -Line '{}' -Name 'empty request object' -Kind Error -Id $null -Code -32600 -Detail $invalidRequest
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ id = 10; method = 'ping' })) -Name 'missing jsonrpc preserves readable id' -Kind Error -Id 10 -Code -32600 -Detail $invalidRequest
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '1.0'; id = 'bad-version'; method = 'ping' })) -Name 'wrong jsonrpc preserves readable id' -Kind Error -Id 'bad-version' -Code -32600 -Detail $invalidRequest
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ Jsonrpc = '2.0'; id = 'jsonrpc-case'; method = 'ping' })) -Name 'jsonrpc field is case-sensitive' -Kind Error -Id 'jsonrpc-case' -Code -32600 -Detail $invalidRequest
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'method-case'; Method = 'ping' })) -Name 'method field is case-sensitive' -Kind Error -Id 'method-case' -Code -32600 -Detail $invalidRequest
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'method-type'; method = 7 })) -Name 'method must be a string' -Kind Error -Id 'method-type' -Code -32600 -Detail $invalidRequest

Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 42; method = 'ping' })) -Name 'integer id correlation' -Kind EmptyResult -Id 42
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = [long]9223372036854775807; method = 'ping' })) -Name 'Int64 id correlation' -Kind EmptyResult -Id ([long]9223372036854775807)
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'string-id'; method = 'ping' })) -Name 'string id correlation' -Kind EmptyResult -Id 'string-id'
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = ''; method = 'ping' })) -Name 'empty string id correlation' -Kind EmptyResult -Id ''
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = $null; method = 'ping' })) -Name 'null id rejection' -Kind Error -Id $null -Code -32600 -Detail $invalidRequest
Add-ExpectedFrame -Line '{"jsonrpc":"2.0","id":[7],"method":"ping"}' -Name 'array id rejection' -Kind Error -Id $null -Code -32600 -Detail $invalidRequest
Add-ExpectedFrame -Line '{"jsonrpc":"2.0","id":{"value":7},"method":"ping"}' -Name 'object id rejection' -Kind Error -Id $null -Code -32600 -Detail $invalidRequest
Add-ExpectedFrame -Line '{"jsonrpc":"2.0","id":1.5,"method":"ping"}' -Name 'fractional id rejection' -Kind Error -Id $null -Code -32600 -Detail $invalidRequest
Add-ExpectedFrame -Line '{"jsonrpc":"2.0","id":true,"method":"ping"}' -Name 'boolean id rejection' -Kind Error -Id $null -Code -32600 -Detail $invalidRequest

Add-NotificationFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; method = 'notifications/initialized' }))
Add-NotificationFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; method = 'unknown/notification'; params = [ordered]@{} }))
Add-NotificationFrame -Line (ConvertTo-Frame ([ordered]@{
    jsonrpc = '2.0'
    method = 'tools/call'
    params = [ordered]@{ name = 'search_web'; arguments = [ordered]@{ query = '' } }
}))
Add-NotificationFrame -Line (ConvertTo-Frame ([ordered]@{
    jsonrpc = '2.0'
    ID = 'uppercase-is-not-an-id'
    method = 'tools/call'
    params = [ordered]@{ name = 'search_web'; arguments = [ordered]@{ query = '' } }
}))
$null = $inputLines.Add('   ')

foreach ($protocolVersion in @('2025-11-25', '2025-06-18')) {
    $caseId = "initialize-$protocolVersion"
    Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{
        jsonrpc = '2.0'
        id = $caseId
        method = 'initialize'
        params = [ordered]@{ protocolVersion = $protocolVersion }
    })) -Name "initialize $protocolVersion" -Kind Initialize -Id $caseId -Detail $protocolVersion
}
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{
    jsonrpc = '2.0'
    id = 'initialize-fallback'
    method = 'initialize'
    params = [ordered]@{ protocolVersion = '2026-07-28' }
})) -Name 'unsupported protocol falls back to latest supported legacy version' -Kind Initialize -Id 'initialize-fallback' -Detail '2025-11-25'
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'initialize-no-params'; method = 'initialize' })) -Name 'initialize requires params' -Kind Error -Id 'initialize-no-params' -Code -32602 -Detail $invalidParams
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'initialize-empty'; method = 'initialize'; params = [ordered]@{} })) -Name 'initialize rejects empty params' -Kind Error -Id 'initialize-empty' -Code -32602 -Detail $invalidParams
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'params-case'; method = 'initialize'; Params = [ordered]@{ protocolVersion = '2025-11-25' } })) -Name 'params field is case-sensitive' -Kind Error -Id 'params-case' -Code -32602 -Detail $invalidParams
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'discover'; method = 'server/discover' })) -Name 'legacy discovery fallback signal' -Kind Error -Id 'discover' -Code -32601 -Detail 'Method not found.'

Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'ping-empty-params'; method = 'ping'; params = [ordered]@{} })) -Name 'ping accepts empty params' -Kind EmptyResult -Id 'ping-empty-params'
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'ping-null-params'; method = 'ping'; params = $null })) -Name 'ping accepts null params' -Kind EmptyResult -Id 'ping-null-params'
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'ping-array-params'; method = 'ping'; params = @(1) })) -Name 'params must be an object' -Kind Error -Id 'ping-array-params' -Code -32602 -Detail $invalidParams
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'tools'; method = 'tools/list'; params = [ordered]@{} })) -Name 'tool discovery schema' -Kind ToolsList -Id 'tools'
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'method-value-case'; method = 'Tools/List' })) -Name 'method values are case-sensitive' -Kind Error -Id 'method-value-case' -Code -32601 -Detail 'Method not found.'

Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'call-empty-params'; method = 'tools/call'; params = [ordered]@{} })) -Name 'tools call rejects empty params' -Kind Error -Id 'call-empty-params' -Code -32602 -Detail $invalidParams
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'unknown-tool'; method = 'tools/call'; params = [ordered]@{ name = 'other'; arguments = [ordered]@{} } })) -Name 'unknown tool' -Kind Error -Id 'unknown-tool' -Code -32602 -Detail 'Unknown tool.'
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'tool-name-case'; method = 'tools/call'; params = [ordered]@{ name = 'Search_Web'; arguments = [ordered]@{} } })) -Name 'tool names are case-sensitive' -Kind Error -Id 'tool-name-case' -Code -32602 -Detail 'Unknown tool.'
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'missing-arguments'; method = 'tools/call'; params = [ordered]@{ name = 'search_web' } })) -Name 'missing arguments object' -Kind Error -Id 'missing-arguments' -Code -32602 -Detail $invalidParams
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'arguments-case'; method = 'tools/call'; params = [ordered]@{ name = 'search_web'; Arguments = [ordered]@{} } })) -Name 'arguments field is case-sensitive' -Kind Error -Id 'arguments-case' -Code -32602 -Detail $invalidParams
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'empty-arguments'; method = 'tools/call'; params = [ordered]@{ name = 'search_web'; arguments = [ordered]@{} } })) -Name 'empty arguments object' -Kind ToolError -Id 'empty-arguments' -Detail $argumentError
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'query-type'; method = 'tools/call'; params = [ordered]@{ name = 'search_web'; arguments = [ordered]@{ query = 9 } } })) -Name 'query type validation' -Kind ToolError -Id 'query-type' -Detail $argumentError
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'query-case'; method = 'tools/call'; params = [ordered]@{ name = 'search_web'; arguments = [ordered]@{ Query = 'unused' } } })) -Name 'query field is case-sensitive' -Kind ToolError -Id 'query-case' -Detail $argumentError
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'extra-argument'; method = 'tools/call'; params = [ordered]@{ name = 'search_web'; arguments = [ordered]@{ query = ''; extra = 1 } } })) -Name 'unknown argument rejection' -Kind ToolError -Id 'extra-argument' -Detail $argumentError
foreach ($entry in @(
    [pscustomobject]@{ Id = 'max-zero'; Value = 0 },
    [pscustomobject]@{ Id = 'max-seven'; Value = 7 },
    [pscustomobject]@{ Id = 'max-fraction'; Value = 1.5 },
    [pscustomobject]@{ Id = 'max-string'; Value = '2' },
    [pscustomobject]@{ Id = 'max-boolean'; Value = $true }
)) {
    Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{
        jsonrpc = '2.0'
        id = $entry.Id
        method = 'tools/call'
        params = [ordered]@{ name = 'search_web'; arguments = [ordered]@{ query = ''; max_results = $entry.Value } }
    })) -Name "invalid max_results $($entry.Id)" -Kind ToolError -Id $entry.Id -Detail $maxResultsError
}

Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{
    jsonrpc = '2.0'
    id = 'empty-query'
    method = 'tools/call'
    params = [ordered]@{ name = 'search_web'; arguments = [ordered]@{ query = '' } }
})) -Name 'empty query fails before transport' -Kind ToolError -Id 'empty-query' -Detail 'Web search failed: query must not be empty.'
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{
    jsonrpc = '2.0'
    id = 'long-query'
    method = 'tools/call'
    params = [ordered]@{ name = 'search_web'; arguments = [ordered]@{ query = ('A' * 301) } }
})) -Name 'oversized query fails before transport' -Kind ToolError -Id 'long-query' -Detail 'Web search failed: query must be 300 characters or fewer.'
$secretMarker = 'SAFE_SECRET_MARKER_4F8089'
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{
    jsonrpc = '2.0'
    id = 'control-query'
    method = 'tools/call'
    params = [ordered]@{ name = 'search_web'; arguments = [ordered]@{ query = ($secretMarker + [char]1) } }
})) -Name 'control character query fails before transport' -Kind ToolError -Id 'control-query' -Detail 'Web search failed: query contains unsupported control characters.'

$boundaryPrefix = '{"jsonrpc":"2.0","id":"boundary-ok","method":"ping","params":{"pad":"'
$boundarySuffix = '"}}'
$boundaryPadLength = 65536 - $boundaryPrefix.Length - $boundarySuffix.Length
Assert-True ($boundaryPadLength -gt 0) 'Boundary test could not be constructed.'
$boundaryLine = $boundaryPrefix + ('A' * $boundaryPadLength) + $boundarySuffix
Assert-True ($boundaryLine.Length -eq 65536) 'Accepted boundary frame is not exactly 65,536 characters.'
Add-ExpectedFrame -Line $boundaryLine -Name '65,536 character frame' -Kind EmptyResult -Id 'boundary-ok'

$oversizedLine = $boundaryPrefix + ('A' * ($boundaryPadLength + 1)) + $boundarySuffix
Assert-True ($oversizedLine.Length -eq 65537) 'Oversized frame is not exactly 65,537 characters.'
Add-ExpectedFrame -Line $oversizedLine -Name '65,537 character frame' -Kind Error -Id $null -Code -32600 -Detail 'Invalid Request: input line is too long.'

function New-DepthFrame {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][int]$ArrayDepth
    )

    $open = ('[' * $ArrayDepth) -join ''
    $close = (']' * $ArrayDepth) -join ''
    return '{"jsonrpc":"2.0","id":"' + $Id + '","method":"ping","params":{"nest":' + $open + '0' + $close + '}}'
}

Add-ExpectedFrame -Line (New-DepthFrame -Id 'depth-32' -ArrayDepth 30) -Name 'JSON nesting depth 32' -Kind EmptyResult -Id 'depth-32'
Add-ExpectedFrame -Line (New-DepthFrame -Id 'depth-33' -ArrayDepth 31) -Name 'JSON nesting depth 33' -Kind Error -Id $null -Code -32600 -Detail 'Invalid Request: JSON nesting is too deep.'
Add-ExpectedFrame -Line (ConvertTo-Frame ([ordered]@{ jsonrpc = '2.0'; id = 'recover-final'; method = 'ping' })) -Name 'final recovery ping' -Kind EmptyResult -Id 'recover-final'

$resolvedServerPath = (Resolve-Path -LiteralPath $ServerPath).Path
Assert-True ([IO.Path]::IsPathRooted($resolvedServerPath)) 'Server path did not resolve to an absolute path.'
Assert-True (-not $resolvedServerPath.Contains('"')) 'Server path contains an unsupported quote character.'
$serverHashBefore = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedServerPath).Hash

# Exercise the regex timeout and the shared total parse deadline without
# invoking the transport. The prelude contains declarations and functions but
# stops before the line-delimited JSON main loop.
$serverSource = [IO.File]::ReadAllText($resolvedServerPath)
$mainLoopMatch = [regex]::Match($serverSource, '(?m)^while \(\$true\) \{\r?$')
Assert-True ($mainLoopMatch.Success) 'Could not isolate the server function prelude for the parse-budget probe.'
$parseProbe = @'
try {
    # Parsing/status probes must remain pure and offline. Dispose the transport
    # first so an accidental network call fails immediately.
    if ($null -ne $script:HttpClient) { $script:HttpClient.Dispose(); $script:HttpClient = $null }
    if ($null -ne $handler) { $handler.Dispose(); $handler = $null }

    function Assert-ProbeCondition {
        param([bool]$Condition, [string]$Message)
        if (-not $Condition) { throw $Message }
    }

    function Assert-ProbeThrowsExact {
        param([scriptblock]$Action, [string]$ExpectedMessage, [string]$CaseName)
        $caught = $false
        try {
            & $Action
        } catch {
            if ($_.Exception.Message -cne $ExpectedMessage) {
                throw "$CaseName returned an unexpected error: $($_.Exception.Message)"
            }
            $caught = $true
        }
        if (-not $caught) { throw "$CaseName did not fail closed." }
    }

    $htmlStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $htmlText = ConvertFrom-HtmlText -Html '<div>Duck<span>Duck</span>Go</div><p>Volume <b>today</b>,<br>Second &amp; third</p><script>ignore</script><style>ignore</style>' -ParseStopwatch $htmlStopwatch
    Assert-ProbeCondition ($htmlText -ceq 'DuckDuckGo | Volume today, | Second & third') 'HTML conversion lost a block boundary or inserted inline punctuation spaces.'
    $listStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $listText = ConvertFrom-HtmlText -Html '<ul><li>First</li><li>[<b>LM Studio Engine Protocol</b>] Second</li></ul>' -ParseStopwatch $listStopwatch
    Assert-ProbeCondition ($listText -ceq 'First | [LM Studio Engine Protocol] Second') 'HTML conversion lost list boundaries or bracketed inline text.'
    $nestedBlockStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $nestedBlockText = ConvertFrom-HtmlText -Html 'Alpha<div>Beta</div>Gamma<hr>Delta|Epsilon |edge|' -ParseStopwatch $nestedBlockStopwatch
    Assert-ProbeCondition ($nestedBlockText -ceq 'Alpha | Beta | Gamma | Delta|Epsilon |edge|') 'HTML conversion lost an opening block boundary or changed a literal pipe.'
    $unclosedHiddenStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $unclosedHiddenText = ConvertFrom-HtmlText -Html '<p>Visible</p><script>HIDDEN INSTRUCTION <a href="https://bad.example/">bad</a>' -ParseStopwatch $unclosedHiddenStopwatch
    Assert-ProbeCondition ($unclosedHiddenText -ceq 'Visible') 'Unclosed hidden HTML leaked into visible text.'

    # Regression 1: a buffer that ends in the middle of a tag is truncation this
    # server caused by cutting at a length budget, not malformed provider
    # markup. Scanning stops and returns what was parsed instead of throwing.
    $cutTagStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $cutTagSnippet = Find-DuckDuckGoSnippetHtml -Html '<div class="result__body">lead text <span class="resu' -ParseStopwatch $cutTagStopwatch
    Assert-ProbeCondition ($cutTagSnippet -ceq '') 'A segment cut in the middle of a tag must not fail the whole search.'
    $cutBeforeStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $cutAfterSnippet = Find-DuckDuckGoSnippetHtml -Html '<div class="result__snippet">Kept text</div><div class="result__ext' -ParseStopwatch $cutBeforeStopwatch
    Assert-ProbeCondition ($cutAfterSnippet -ceq 'Kept text') 'A snippet before a truncated tag must still be returned.'

    # Regression 2: title HTML cut at its length budget reaches ConvertFrom-HtmlText
    # mid-tag. The text parsed so far is kept rather than discarded.
    $cutTitleStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $cutTitleText = ConvertFrom-HtmlText -Html 'Result title <b>bold</b> and <span class="hi' -ParseStopwatch $cutTitleStopwatch
    Assert-ProbeCondition ($cutTitleText -ceq 'Result title bold and') 'A title cut mid-tag must keep the text already parsed.'

    # Regression 3: one hidden element inside a different hidden element is
    # ordinary markup. <noscript><iframe> appears on many real pages, and
    # <noscript><style> is just as common.
    $noscriptIframeStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $noscriptIframeText = ConvertFrom-HtmlText -Html '<p>Visible</p><noscript><iframe src="https://tracker.example/"></iframe></noscript><p>After</p>' -ParseStopwatch $noscriptIframeStopwatch
    Assert-ProbeCondition ($noscriptIframeText -ceq 'Visible | After') 'A noscript wrapping an iframe must be skipped, not treated as fatal.'
    $noscriptStyleStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $noscriptStyleText = ConvertFrom-HtmlText -Html '<p>Visible</p><noscript><style>.a{content:"</noscript>"}</style></noscript><p>After</p>' -ParseStopwatch $noscriptStyleStopwatch
    Assert-ProbeCondition ($noscriptStyleText -ceq 'Visible | After') 'A close tag inside raw text was mistaken for an element boundary.'

    # Regression 4: a length cut that lands inside text used to drop the snippet
    # with no error at all. The snippet window now runs between result anchors,
    # which are real tag boundaries, so the snippet is found either way.
    $farSnippetPadding = '<span>' + ('x' * 7000) + '</span>'
    $farSnippetHtml = '<div class="result"><a class="result__a" href="https://example.com/page">Title One</a>' + $farSnippetPadding + '<a class="result__snippet" href="#">Snippet text</a></div>'
    $farSnippetParsed = ConvertFrom-DuckDuckGoHtml -Html $farSnippetHtml -Query 'far snippet' -MaxResults 1
    Assert-ProbeCondition ($farSnippetParsed.results.Count -eq 1) 'Expected one parsed result for the distant-snippet page.'
    Assert-ProbeCondition ($farSnippetParsed.results[0].title -ceq 'Title One') 'Distant-snippet page lost its title.'
    Assert-ProbeCondition ($farSnippetParsed.results[0].snippet -ceq 'Snippet text') 'A snippet past the old 6000-character cut was silently lost.'

    # A malformed tag in the interior of a buffer is not truncation and must
    # still fail closed, so the fixes above cannot be mistaken for disabling the
    # parser's suspicion of bad markup.
    Assert-ProbeThrowsExact -Action {
        $interiorStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $null = ConvertFrom-HtmlText -Html '<p>Alpha <span class="x"<b>bad</b> trailing text</p>' -ParseStopwatch $interiorStopwatch
    } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'interior malformed tag'
    Assert-ProbeThrowsExact -Action {
        $interiorSnippetStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $null = Find-DuckDuckGoSnippetHtml -Html '<div class="a"<x>text</div><div class="result__snippet">s</div>' -ParseStopwatch $interiorSnippetStopwatch
    } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'interior malformed tag during snippet search'

    # Real-page fixtures. These are captured provider markup with per-request
    # tokens and third-party result content replaced by placeholders, so the
    # structure is real even though nothing quoted from the web remains. Hand
    # written fixtures never reproduced the layout that broke the parser.
    $fixtureDirectory = $env:SAFE_WEB_SEARCH_FIXTURE_DIR
    Assert-ProbeCondition (-not [string]::IsNullOrWhiteSpace($fixtureDirectory)) 'Fixture directory was not provided to the parse probe.'
    foreach ($fixtureCase in @(
        @{ File = 'duckduckgo-html-results.html'; Name = 'captured results page' },
        @{ File = 'duckduckgo-html-results-noscript.html'; Name = 'captured results page with a noscript-wrapped iframe' }
    )) {
        $fixturePath = Join-Path $fixtureDirectory $fixtureCase.File
        Assert-ProbeCondition (Test-Path -LiteralPath $fixturePath -PathType Leaf) "Missing real-page fixture $($fixtureCase.File)."
        $fixtureHtml = [IO.File]::ReadAllText($fixturePath)
        $fixtureParsed = ConvertFrom-DuckDuckGoHtml -Html $fixtureHtml -Query 'test' -MaxResults 6
        Assert-ProbeCondition ($fixtureParsed.result_count -eq 6) "Real-page fixture '$($fixtureCase.Name)' did not yield six results."
        Assert-ProbeCondition ($fixtureParsed.results[0].title -ceq 'Example Result 1 Title') "Real-page fixture '$($fixtureCase.Name)' lost its first title."
        # Protocol-relative provider redirect links must still resolve.
        Assert-ProbeCondition ($fixtureParsed.results[0].url -ceq 'https://example.com/result-1') "Real-page fixture '$($fixtureCase.Name)' did not unwrap a relative redirect link."
        # Inline <b> highlighting is removed without inserting stray spaces.
        Assert-ProbeCondition ($fixtureParsed.results[0].snippet -clike 'Example snippet text for result 1.*') "Real-page fixture '$($fixtureCase.Name)' lost or mangled its snippet."
        Assert-ProbeCondition ($fixtureParsed.freshness -ceq 'unknown') "Real-page fixture '$($fixtureCase.Name)' lost freshness metadata."
        Assert-ProbeCondition ($fixtureParsed.result_pages_opened -eq $false) "Real-page fixture '$($fixtureCase.Name)' changed the page-not-opened marker."
    }

    $knownUtc = [DateTime]::ParseExact(
        '2026-08-10T12:34:56.789Z',
        "yyyy-MM-dd'T'HH:mm:ss.fff'Z'",
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
    )
    Assert-ProbeCondition ((ConvertTo-UtcTimestamp -Timestamp $knownUtc) -ceq '2026-08-10T12:34:56.789Z') 'UTC timestamp formatting is not deterministic.'

    Assert-SearchResponseStatus -StatusCode 200
    Assert-ProbeThrowsExact -Action { Assert-SearchResponseStatus -StatusCode 202 } -ExpectedMessage 'Search provider refused or deferred the request (HTTP 202). No bypass or automatic retry was attempted.' -CaseName 'HTTP 202 provider response'
    Assert-ProbeThrowsExact -Action { Assert-SearchResponseStatus -StatusCode 403 } -ExpectedMessage 'Search provider refused or deferred the request (HTTP 403). No bypass or automatic retry was attempted.' -CaseName 'HTTP 403 provider response'
    Assert-ProbeThrowsExact -Action { Assert-SearchResponseStatus -StatusCode 429 } -ExpectedMessage 'Search provider refused or deferred the request (HTTP 429). No bypass or automatic retry was attempted.' -CaseName 'HTTP 429 provider response'
    Assert-ProbeThrowsExact -Action { Assert-SearchResponseStatus -StatusCode 500 } -ExpectedMessage 'Search provider returned HTTP 500.' -CaseName 'HTTP 500 provider response'

    # Prove the production request path consults status handling, using an
    # in-memory fake client that cannot contact a network.
    $fakeClient = New-Object psobject
    $fakeClient | Add-Member -MemberType ScriptMethod -Name SendAsync -Value {
        param($request, $completionOption)
        $taskSource = New-Object 'System.Threading.Tasks.TaskCompletionSource[System.Net.Http.HttpResponseMessage]'
        $taskSource.SetResult((New-Object System.Net.Http.HttpResponseMessage([System.Net.HttpStatusCode]::Accepted)))
        return $taskSource.Task
    }
    $fakeClient | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
    $script:HttpClient = $fakeClient
    $script:SearchHistory = @()
    Assert-ProbeThrowsExact -Action { Invoke-SafeWebSearch -Query 'offline status wiring' -MaxResults 1 } -ExpectedMessage 'Search provider refused or deferred the request (HTTP 202). No bypass or automatic retry was attempted.' -CaseName 'production HTTP status wiring'
    $script:HttpClient.Dispose()
    $script:HttpClient = $null

    $rateNow = [DateTime]::UtcNow
    $script:SearchHistory = @(1..60 | ForEach-Object { $rateNow.AddSeconds(-1) })
    Assert-ProbeThrowsExact -Action { Invoke-SafeWebSearch -Query 'offline hourly limit' -MaxResults 1 } -ExpectedMessage 'Local safety limit reached (60 searches per hour). Stop retrying or rephrasing and end this search sequence.' -CaseName 'hourly limit precedence'
    $script:SearchHistory = @(1..10 | ForEach-Object { $rateNow.AddSeconds(-1) })
    Assert-ProbeThrowsExact -Action { Invoke-SafeWebSearch -Query 'offline minute limit' -MaxResults 1 } -ExpectedMessage 'Local safety limit reached (10 searches per minute). Stop retrying or rephrasing and wait at least 60 seconds before another search.' -CaseName 'minute rate limit'
    $script:SearchHistory = @()

    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html " `r`n " -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned an empty page. The request may have been blocked. Do not immediately retry.' -CaseName 'blank provider page'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html '<html><body><form id="challenge"></form></body></html>' -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'unrecognized provider page'
    $hiddenAnchorHtml = '<!-- <a class="result__a" href="https://comment.example/">Comment</a> --><script><a class="result__a" href="https://script.example/">Script</a></script><template><a class="result__a" href="https://template.example/">Template</a></template><noscript><a class="result__a" href="https://noscript.example/">No script</a></noscript>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $hiddenAnchorHtml -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'hidden anchor markup'
    $rawTextAnchorHtml = '<textarea><a class="result__a" href="https://textarea.example/">Text area</a></textarea><title><a class="result__a" href="https://title.example/">Title</a></title><xmp><a class="result__a" href="https://xmp.example/">XMP</a></xmp><iframe><a class="result__a" href="https://iframe.example/">Frame fallback</a></iframe><plaintext><a class="result__a" href="https://plaintext.example/">Plain text</a>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $rawTextAnchorHtml -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'raw text container anchors'
    $nestedTemplateHtml = '<template><template>inner</template><a class="result__a" href="https://nested.example/">Nested tail</a></template>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $nestedTemplateHtml -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'nested hidden container'
    $unclosedNestedTemplateHtml = '<template><template>inner</template><a class="result__a" href="https://nested-unclosed.example/">Nested unclosed tail</a>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $unclosedNestedTemplateHtml -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'unclosed nested hidden container'
    $nestedSelfClosingTemplateHtml = '<template><template/></template><a class="result__a" href="https://nested-self-closing.example/">Nested self-closing tail</a>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $nestedSelfClosingTemplateHtml -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'nested self-closing hidden container'
    $quotedScriptCloseHtml = '<script data-x=">foo</script>"><a class="result__a" href="https://quoted-script-close.example/">Leaked script tail</a><div class="result__snippet">Leaked snippet</div>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $quotedScriptCloseHtml -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'hidden close text inside script attribute'
    $quotedTemplateCloseHtml = '<template data="> </template>"><a class="result__a" href="https://quoted-template-close.example/">Leaked template tail</a>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $quotedTemplateCloseHtml -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'hidden close text inside template attribute'
    $selfClosingHiddenHtml = '<script/><a class="result__a" href="https://self-closing-script.example/">Leaked self-closing tail</a>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $selfClosingHiddenHtml -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'self-closing hidden container'
    $mixedHiddenHtml = '<template><script>raw </template><a class="result__a" href="https://mixed-hidden.example/">Leaked mixed-hidden tail</a>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $mixedHiddenHtml -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'mixed hidden containers'
    $cdataAnchorHtml = '<svg><![CDATA[x > <a class="result__a" href="https://cdata.example/">CDATA fake</a><div class="result__snippet">CDATA snippet</div> ]]></svg>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $cdataAnchorHtml -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'foreign-content CDATA anchor text'
    $quotedAttributeHtml = '<div data-template=''<a class="result__a" href="https://attribute.example/">Attribute text</a>''></div>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $quotedAttributeHtml -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'tag-like markup in an attribute'
    $twoAttributeBypassHtml = '<div data-a=">" data-b="<a class=''result__a'' href=''https://two-attribute.example/''>Fake</a>"></div>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $twoAttributeBypassHtml -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'tag-like markup after quoted greater-than'
    $unquotedAttributeHtml = '<div data=<a class="result__a" href="https://unquoted.example/">Attribute tail</a>></div>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $unquotedAttributeHtml -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'tag-like markup in an unquoted attribute'
    $attributeTextHtml = '<a data-x="class=''result__a'' href=''https://attribute-text.example/''">Fake</a>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $attributeTextHtml -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'attribute-like text inside one value'
    $splitAttributeTextHtml = '<a data-x="class=''result__a''" data-y="href=''https://split-attribute.example/''">Fake</a>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $splitAttributeTextHtml -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'attribute-like text split across values'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html '<a class="notresult__attack" href="https://lookalike.example/">Lookalike class</a>' -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'lookalike result class'
    $nonHtmlSpace = [char]0x00A0
    $nonHtmlSpaceClass = '<a class="prefix' + $nonHtmlSpace + 'result__a" href="https://nbsp.example/">NBSP lookalike</a>'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html $nonHtmlSpaceClass -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider returned no recognizable result structure. This may mean no results, a provider block, or a page-layout change. Do not immediately retry.' -CaseName 'non-HTML class whitespace'
    Assert-ProbeThrowsExact -Action { ConvertFrom-DuckDuckGoHtml -Html '<a class="result__a" href="javascript:alert(1)">Bad result</a>' -Query 'offline' -MaxResults 1 } -ExpectedMessage 'Search provider result markup contained no usable HTTP(S) results. Its layout may have changed. Do not immediately retry.' -CaseName 'unusable result markup'

    $fixtureHtml = '<a class="featured result__a primary" href="/l/?uddg=https%3A%2F%2Fexample.com%2Frelease">Example <b>Release</b></a><div class="summary result__snippet primary">First <b>item</b>,<br>Second &amp; third.</div><a class="result__a" href="https://second.example/">Second result</a><div class="result__snippet">Unused</div>'
    $parsedFixture = ConvertFrom-DuckDuckGoHtml -Html $fixtureHtml -Query 'offline fixture' -MaxResults 1
    Assert-ProbeCondition ([string]$parsedFixture.query -ceq 'offline fixture') 'Parsed result did not preserve the query.'
    Assert-ProbeCondition ([string]$parsedFixture.provider -ceq 'DuckDuckGo HTML') 'Parsed result provider changed.'
    Assert-ProbeCondition ([string]$parsedFixture.content_kind -ceq 'unverified_search_result_snippets') 'Parsed result omitted its content kind.'
    Assert-ProbeCondition ([string]$parsedFixture.freshness -ceq 'unknown') 'Parsed result made an unsupported freshness claim.'
    Assert-ProbeCondition ($parsedFixture.result_pages_opened -eq $false) 'Parsed result incorrectly claims that result pages were opened.'
    Assert-ProbeCondition ([int]$parsedFixture.result_count -eq 1) 'Parsed result did not enforce the requested result cap.'
    Assert-ProbeCondition (@($parsedFixture.results).Count -eq 1) 'Parsed result array size is incorrect.'
    Assert-ProbeCondition ([string]$parsedFixture.results[0].title -ceq 'Example Release') 'Inline title markup was not removed cleanly.'
    Assert-ProbeCondition ([string]$parsedFixture.results[0].url -ceq 'https://example.com/release') 'DuckDuckGo redirect URL was not decoded.'
    Assert-ProbeCondition ([string]$parsedFixture.results[0].snippet -ceq 'First item, | Second & third.') 'Snippet inline or block markup was not represented correctly.'
    Assert-ProbeCondition ([string]$parsedFixture.search_completed_at_utc -cmatch '\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z') 'Search completion timestamp is not UTC RFC 3339 format.'
    Assert-ProbeCondition ([string]$parsedFixture.usage_notice -match 'high-stakes decisions') 'Parsed result omitted its high-stakes usage limit.'
    Assert-ProbeCondition ([string]$parsedFixture.security_notice -match 'untrusted web content') 'Parsed result omitted its untrusted-content warning.'

    $quotedGreaterHtml = '<a data-note="x > HIDDEN INSTRUCTION" href="https://quoted-greater.example/" class="result__a">Actual title</a><div class="result__snippet">Actual snippet</div>'
    $quotedGreaterResult = ConvertFrom-DuckDuckGoHtml -Html $quotedGreaterHtml -Query 'quoted greater' -MaxResults 1
    Assert-ProbeCondition ([string]$quotedGreaterResult.results[0].title -ceq 'Actual title') 'A greater-than sign inside a quoted attribute corrupted the title boundary.'
    Assert-ProbeCondition ([string]$quotedGreaterResult.results[0].url -ceq 'https://quoted-greater.example/') 'Quote-aware attribute extraction changed the real href.'
    $visibleAfterHiddenHtml = '<script data-x=">foo"></script><a class="result__a" href="https://visible-after-hidden.example/">Visible result</a><div class="result__snippet">Visible snippet</div>'
    $visibleAfterHiddenResult = ConvertFrom-DuckDuckGoHtml -Html $visibleAfterHiddenHtml -Query 'visible after hidden' -MaxResults 1
    Assert-ProbeCondition ([string]$visibleAfterHiddenResult.results[0].title -ceq 'Visible result') 'A well-formed hidden region swallowed the following visible result.'
    Assert-ProbeCondition ([string]$visibleAfterHiddenResult.results[0].url -ceq 'https://visible-after-hidden.example/') 'A well-formed hidden region changed the following result URL.'

    $adversarialInput = ('a' * 50000) + '!'
    $adversarialStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $timedOut = $false
    try {
        $null = Invoke-SafeRegexMatch -InputText $adversarialInput -Pattern '^(a+)+$' -ParseStopwatch $adversarialStopwatch
    } catch {
        if ($_.Exception.Message -notmatch 'parsing time limit') { throw }
        $timedOut = $true
    }
    if (-not $timedOut) { throw 'Adversarial regex did not hit its bounded timeout.' }
    if ($adversarialStopwatch.ElapsedMilliseconds -gt 4000) { throw 'Adversarial regex exceeded the test time ceiling.' }

    $boundedStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $boundedMatches = Invoke-SafeRegexMatches -InputText ('a' * 1000) -Pattern 'a' -ParseStopwatch $boundedStopwatch -MaxMatches 32
    if (@($boundedMatches).Count -ne 32) { throw 'Anchor candidate materialization was not bounded to 32 matches.' }

    $sharedStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Start-Sleep -Milliseconds 2600
    $deadlineEnforced = $false
    try {
        $null = Invoke-SafeRegexReplace -InputText 'safe' -Pattern 'safe' -Replacement 'ok' -ParseStopwatch $sharedStopwatch
    } catch {
        if ($_.Exception.Message -notmatch 'total parsing time limit') { throw }
        $deadlineEnforced = $true
    }
    if (-not $deadlineEnforced) { throw 'Shared total parse deadline was not enforced.' }
} finally {
    if ($null -ne $script:HttpClient) { $script:HttpClient.Dispose() }
    if ($null -ne $handler) { $handler.Dispose() }
}
'@
$probeScript = [scriptblock]::Create($serverSource.Substring(0, $mainLoopMatch.Index) + $parseProbe)
$env:SAFE_WEB_SEARCH_FIXTURE_DIR = Join-Path (Split-Path -Parent $PSCommandPath) 'fixtures'
try {
    $null = & $probeScript
} finally {
    Remove-Item -LiteralPath 'Env:\SAFE_WEB_SEARCH_FIXTURE_DIR' -ErrorAction SilentlyContinue
}

$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
Assert-True (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf) 'Windows PowerShell 5.1 was not found.'

$testWorkingDirectory = Join-Path ([IO.Path]::GetTempPath()) ('safe-web-search-mcp-offline-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $testWorkingDirectory
$process = $null
$stdout = ''
$stderr = ''
$leftWorkingDirectoryForInspection = $false
try {
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $windowsPowerShell
    $startInfo.Arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + $resolvedServerPath + '"'
    $startInfo.WorkingDirectory = $testWorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $startInfo.StandardOutputEncoding = $utf8
    $startInfo.StandardErrorEncoding = $utf8

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    Assert-True ($process.Start()) 'Failed to start the MCP server process.'
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.AutoFlush = $true
    foreach ($inputLine in $inputLines) {
        $process.StandardInput.WriteLine([string]$inputLine)
    }
    $process.StandardInput.Close()

    if (-not $process.WaitForExit(20000)) {
        $process.Kill()
        $process.WaitForExit()
        throw 'MCP server did not exit within 20 seconds. No live network request is part of this suite.'
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    Assert-True ($process.ExitCode -eq 0) "MCP server exited with code $($process.ExitCode)."
} finally {
    if ($null -ne $process) {
        $process.Dispose()
    }

    $sideEffects = @(Get-ChildItem -LiteralPath $testWorkingDirectory -Force)
    if ($sideEffects.Count -eq 0) {
        Remove-Item -LiteralPath $testWorkingDirectory -Force
    } else {
        $leftWorkingDirectoryForInspection = $true
    }
}

$serverHashAfter = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedServerPath).Hash
Assert-True ($serverHashAfter -ceq $serverHashBefore) 'The server modified its own source file.'
Assert-True (-not $leftWorkingDirectoryForInspection) "The server created files in its isolated working directory: $testWorkingDirectory"
Assert-True ($stdout.IndexOf($secretMarker, [StringComparison]::Ordinal) -lt 0) 'The secret marker leaked to MCP stdout.'
Assert-True ($stderr.IndexOf($secretMarker, [StringComparison]::Ordinal) -lt 0) 'The secret marker leaked to MCP stderr.'

$stdoutBody = $stdout.TrimEnd([char[]]@("`r", "`n"))
Assert-True (-not [string]::IsNullOrWhiteSpace($stdoutBody)) 'MCP server produced no stdout responses.'
$stdoutLines = @($stdoutBody -split "`r?`n")
Assert-True ($stdoutLines.Count -eq $expectations.Count) "Expected $($expectations.Count) responses but received $($stdoutLines.Count). Notifications may have produced output or a request response may be missing."

for ($index = 0; $index -lt $stdoutLines.Count; $index++) {
    $line = [string]$stdoutLines[$index]
    $expectation = $expectations[$index]
    Assert-True (-not [string]::IsNullOrWhiteSpace($line)) "$($expectation.Name): stdout contains a blank protocol line."
    Assert-True ($line[0] -eq '{' -and $line[$line.Length - 1] -eq '}') "$($expectation.Name): stdout contains non-JSON framing text."
    try {
        $response = $line | ConvertFrom-Json
    } catch {
        throw "$($expectation.Name): stdout line is not valid JSON: $($_.Exception.Message)"
    }

    switch ($expectation.Kind) {
        'Error' {
            Assert-ErrorResponse -Response $response -ExpectedId $expectation.Id -ExpectedCode $expectation.Code -ExpectedMessage $expectation.Detail -CaseName $expectation.Name
        }
        'EmptyResult' {
            Assert-EmptyResultResponse -Response $response -ExpectedId $expectation.Id -CaseName $expectation.Name
        }
        'Initialize' {
            Assert-InitializeResponse -Response $response -ExpectedId $expectation.Id -ExpectedProtocolVersion $expectation.Detail -CaseName $expectation.Name
        }
        'ToolsList' {
            Assert-ToolsListResponse -Response $response -ExpectedId $expectation.Id -CaseName $expectation.Name
        }
        'ToolError' {
            Assert-ToolErrorResponse -Response $response -ExpectedId $expectation.Id -ExpectedText $expectation.Detail -CaseName $expectation.Name
        }
        default {
            throw "$($expectation.Name): unknown expectation kind."
        }
    }
}

$stderrBody = $stderr.TrimEnd([char[]]@("`r", "`n"))
$stderrLines = if ([string]::IsNullOrEmpty($stderrBody)) { @() } else { @($stderrBody -split "`r?`n") }
$expectedStderr = @(
    'safe-web-search: search failed: query must not be empty.',
    'safe-web-search: search failed: query must be 300 characters or fewer.',
    'safe-web-search: search failed: query contains unsupported control characters.'
)
Assert-True ($stderrLines.Count -eq $expectedStderr.Count) "Expected $($expectedStderr.Count) sanitized stderr lines but received $($stderrLines.Count)."
for ($index = 0; $index -lt $expectedStderr.Count; $index++) {
    Assert-True ([string]$stderrLines[$index] -ceq [string]$expectedStderr[$index]) "Unexpected stderr output at line $($index + 1)."
}

Write-Output "PASS: $($expectations.Count) offline MCP responses validated; notifications were silent; no live search request was sent."
