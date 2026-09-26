param([Parameter(Mandatory = $true)][string]$ModelPath)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskOutput = Join-Path $taskRoot 'TestArtifacts\TimelinePoseSync'
$taskCompilerRoot = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'

Push-Location $taskRoot
try {
    New-Item -ItemType Directory -Force $taskOutput | Out-Null
    $taskSources = [regex]::Matches(
        (Get-Content MMDAnimationStudio.dpr -Raw), "in '([^']+)'")
    $taskDirs = @((Join-Path $taskRoot 'Source\Lib'),
        (Join-Path $taskRoot 'Source\AI\Controller'),
        (Join-Path $taskRoot 'Source\Plugin\Model\Render'),
        (Join-Path $taskRoot 'Source\Plugin\Model\Runtime\Pose'))
    $taskDirs += $taskSources | ForEach-Object {
        [IO.Path]::GetFullPath(
            (Join-Path $taskRoot (Split-Path $_.Groups[1].Value)))
    }
    $taskDirs += Get-ChildItem Source\Plugin\Model -Directory -Recurse |
        Select-Object -ExpandProperty FullName
    $taskDirs += Get-ChildItem ..\AviUtl2PluginLib\MMD, ..\AviUtl2PluginLib\Lib -Directory -Recurse |
        Select-Object -ExpandProperty FullName
    $taskDirs += Join-Path $taskCompilerRoot 'lib\win64\release'
    $taskSearch = ($taskDirs | Select-Object -Unique) -join ';'
    foreach ($taskName in @('MmdPoseSharedMemoryTest',
        'MmdModelRotationTest',
        'MmdProControllerOutputTest',
        'MmdTimelinePoseBindingTest', 'MmdTimelinePoseEditorFrameTest')) {
        $taskRsp = Join-Path $taskOutput ($taskName + '.rsp')
        $taskArgs = @(
            '-B', '-Q', '-TX.exe',
            ('-E"' + $taskOutput + '"'),
            ('-N0"' + $taskOutput + '"'),
            ('-U"' + $taskSearch + '"'),
            ('Tests\' + $taskName + '.dpr')
        )
        [IO.File]::WriteAllLines($taskRsp, $taskArgs, [Text.Encoding]::Default)
        & (Join-Path $taskCompilerRoot 'bin\dcc64.exe') ('@' + $taskRsp)
        if ($LASTEXITCODE -ne 0) { throw "$taskName compilation failed" }
        & (Join-Path $taskOutput ($taskName + '.exe')) $ModelPath
        if ($LASTEXITCODE -ne 0) { throw "$taskName failed" }
    }
}
finally {
    Pop-Location
}
