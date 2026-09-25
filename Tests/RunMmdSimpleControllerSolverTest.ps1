param([Parameter(Mandatory = $true)][string[]]$ModelPaths)

$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskOutput = Join-Path $taskRoot 'TestArtifacts\SimpleController\Solver'
$taskCompilerRoot = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
$taskSearch = (@(
    (Join-Path $taskRoot '..\AviUtl2PluginLib\MMD\Core'),
    (Join-Path $taskRoot '..\AviUtl2PluginLib\MMD\IO'),
    (Join-Path $taskRoot '..\AviUtl2PluginLib\MMD\Editor\Controller'),
    (Join-Path $taskRoot '..\AviUtl2PluginLib\MMD\Editor\Controller\Math'),
    (Join-Path $taskCompilerRoot 'lib\win64\release')
) | ForEach-Object { [IO.Path]::GetFullPath($_) }) -join ';'

New-Item -ItemType Directory -Force $taskOutput | Out-Null
Push-Location $taskRoot
try {
    $taskArgs = @(
        '-B', '-Q', '-TX.exe',
        ('-E"' + $taskOutput + '"'),
        ('-N0"' + $taskOutput + '"'),
        ('-U"' + $taskSearch + '"'),
        'Tests\MmdSimpleControllerSolverTest.dpr'
    )
    $taskRsp = Join-Path $taskOutput 'test.rsp'
    [IO.File]::WriteAllLines($taskRsp, $taskArgs, [Text.Encoding]::Default)
    & (Join-Path $taskCompilerRoot 'bin\dcc64.exe') ('@' + $taskRsp)
    if ($LASTEXITCODE -ne 0) { throw 'simple controller test compilation failed' }
    & (Join-Path $taskOutput 'MmdSimpleControllerSolverTest.exe') @ModelPaths
    if ($LASTEXITCODE -ne 0) { throw 'simple controller test failed' }
}
finally {
    Pop-Location
}
