$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskOutput = Join-Path $taskRoot 'TestArtifacts\AiPoseBridge'
$taskCompilerRoot = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'

Push-Location $taskRoot
try {
    New-Item -ItemType Directory -Force $taskOutput | Out-Null
    $taskDirs = @(
        (Join-Path $taskRoot 'Source\AI'),
        (Join-Path $taskRoot '..\AviUtl2PluginLib\MMD\AI'),
        (Join-Path $taskRoot '..\AviUtl2PluginLib\MMD\Core'),
        (Join-Path $taskRoot '..\AviUtl2PluginLib\MMD\IO'),
        (Join-Path $taskCompilerRoot 'lib\win64\release')
    )
    $taskSearch = $taskDirs -join ';'
    $taskRsp = Join-Path $taskOutput 'test.rsp'
    $taskArgs = @(
        '-B', '-Q', '-TX.exe',
        ('-E"' + $taskOutput + '"'),
        ('-N0"' + $taskOutput + '"'),
        ('-U"' + $taskSearch + '"'),
        'Tests\MmdAiPoseBridgeTest.dpr'
    )
    [IO.File]::WriteAllLines($taskRsp, $taskArgs, [Text.Encoding]::Default)
    & (Join-Path $taskCompilerRoot 'bin\dcc64.exe') ('@' + $taskRsp)
    if ($LASTEXITCODE -ne 0) { throw 'AI pose bridge test compilation failed' }
    & (Join-Path $taskOutput 'MmdAiPoseBridgeTest.exe')
    if ($LASTEXITCODE -ne 0) { throw 'AI pose bridge regression failed' }
}
finally {
    Pop-Location
}
