param([Parameter(Mandatory = $true)][string]$ModelPath)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
Push-Location $taskRoot
try {
    $taskOutput = Join-Path $taskRoot 'TestArtifacts\ModelSettingsSession'
    New-Item -ItemType Directory -Force $taskOutput | Out-Null
    $taskCompilerRoot = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
    $taskSources = [regex]::Matches((Get-Content MMD_Model_Filter.dpr -Raw), "in '([^']+)'")
    $taskDirs = @((Join-Path $taskRoot 'Source\Lib'))
    $taskDirs += $taskSources | ForEach-Object {
        [IO.Path]::GetFullPath((Join-Path $taskRoot (Split-Path $_.Groups[1].Value)))
    }
    $taskDirs += Get-ChildItem ..\AviUtl2PluginLib\MMD, ..\AviUtl2PluginLib\Lib\DarkTheme -Directory -Recurse |
        Select-Object -ExpandProperty FullName
    $taskDirs += Join-Path $taskCompilerRoot 'lib\win64\release'
    $taskSearch = ($taskDirs | Select-Object -Unique) -join ';'
    $taskRsp = Join-Path $taskOutput 'test.rsp'
    $taskArgs = @('-B', '-Q', '-TX.exe', ('-E"' + $taskOutput + '"'),
        ('-N0"' + $taskOutput + '"'), ('-U"' + $taskSearch + '"'),
        'Tests\MmdModelSettingsSessionTest.dpr')
    [IO.File]::WriteAllLines($taskRsp, $taskArgs, [Text.Encoding]::Default)
    & (Join-Path $taskCompilerRoot 'bin\dcc64.exe') ('@' + $taskRsp)
    if ($LASTEXITCODE -ne 0) { throw 'Settings session test compilation failed' }
    & (Join-Path $taskOutput 'MmdModelSettingsSessionTest.exe') $ModelPath
    if ($LASTEXITCODE -ne 0) { throw 'Settings session regression failed' }
}
finally {
    Pop-Location
}
