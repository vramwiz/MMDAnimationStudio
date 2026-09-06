param(
    [string]$AviUtl2Path = 'D:\aviutl2_v2.1.6a\aviutl2.exe'
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskAviUtl = $null

Push-Location $taskRoot
try {
    if (-not (Test-Path -LiteralPath $AviUtl2Path)) {
        throw "AviUtl2 was not found: $AviUtl2Path"
    }
    if (-not (Get-Process aviutl2 -ErrorAction SilentlyContinue)) {
        $taskAviUtl = Start-Process -FilePath $AviUtl2Path `
            -WindowStyle Hidden -PassThru
    }
    $taskPipeFound = $false
    for ($taskTry = 0; $taskTry -lt 30; $taskTry++) {
        Start-Sleep -Milliseconds 300
        if (Get-ChildItem \\.\pipe\ -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'MMD.AI.Preview.v1' }) {
            $taskPipeFound = $true
            break
        }
    }
    if (-not $taskPipeFound) { throw 'MMD.AI.Preview.v1 was not created' }

    $taskStart = [Diagnostics.ProcessStartInfo]::new()
    $taskStart.FileName = Join-Path $taskRoot 'MMDAIPreview.exe'
    $taskStart.Arguments = '--mcp'
    $taskStart.WorkingDirectory = $taskRoot
    $taskStart.UseShellExecute = $false
    $taskStart.CreateNoWindow = $true
    $taskStart.RedirectStandardInput = $true
    $taskStart.RedirectStandardOutput = $true
    $taskStart.RedirectStandardError = $true
    $taskMcp = [Diagnostics.Process]::new()
    $taskMcp.StartInfo = $taskStart
    if (-not $taskMcp.Start()) { throw 'MCP server did not start' }
    try {
        $taskMcp.StandardInput.WriteLine(
            '{"jsonrpc":"2.0","id":1,"method":"initialize","params":' +
            '{"protocolVersion":"2025-06-18","capabilities":{},' +
            '"clientInfo":{"name":"mmd-test","version":"1"}}}')
        $taskMcp.StandardInput.WriteLine(
            '{"jsonrpc":"2.0","method":"notifications/initialized"}')
        $taskMcp.StandardInput.WriteLine(
            '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}')
        $taskMcp.StandardInput.WriteLine(
            '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":' +
            '{"name":"get_pose_catalog_context","arguments":{}}}')
        $taskMcp.StandardInput.Close()
        $taskResponses = @()
        while (-not $taskMcp.StandardOutput.EndOfStream) {
            $taskLine = $taskMcp.StandardOutput.ReadLine()
            if ($taskLine) { $taskResponses += $taskLine | ConvertFrom-Json }
        }
        $taskMcp.WaitForExit(10000) | Out-Null
        if (-not $taskMcp.HasExited) { throw 'MCP server did not stop at EOF' }
        if ($taskMcp.ExitCode -ne 0) {
            throw ('MCP server failed: ' + $taskMcp.StandardError.ReadToEnd())
        }
    }
    finally {
        if (-not $taskMcp.HasExited) { $taskMcp.Kill() }
        $taskMcp.Dispose()
    }

    if ($taskResponses.Count -ne 3) {
        throw "Expected 3 MCP responses, got $($taskResponses.Count)"
    }
    if ($taskResponses[0].result.serverInfo.name -ne 'mmd-animation-studio') {
        throw 'initialize response has wrong server name'
    }
    if ($taskResponses[1].result.tools.Count -ne 6) {
        throw 'tools/list did not expose six MMD tools'
    }
    if ($taskResponses[2].result.isError -or
        $taskResponses[2].result.structuredContent.status -ne 'ok' -or
        -not $taskResponses[2].result.structuredContent.active) {
        throw 'get_pose_catalog_context MCP call failed'
    }
    Write-Host 'MmdAiMcpProtocolTest: PASS'
}
finally {
    if ($taskAviUtl -and -not $taskAviUtl.HasExited) {
        Stop-Process -Id $taskAviUtl.Id -Force
    }
    Pop-Location
}
