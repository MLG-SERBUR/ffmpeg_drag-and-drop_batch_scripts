param(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceDirectory,

    [string]$OutputDirectory,

    [string]$OutputSuffix = ''
)

$SearchEncodeOptions = [ordered]@{
    InputFilter       = '*.MOV'
    ExcludedFiles     = @('IMG_4643.MOV', 'IMG_4644.MOV')
    Encoder           = 'libsvtav1'
    Preset            = 4
    MinVmaf           = 95
    SearchEncoderArgs = @(
        'copyts',
        'copytb=1',
        'enc_time_base=demux',
        'fps_mode=passthrough'
    )
    AudioEncoder      = 'copy'
    OutputExtension  = '.mp4'
    VideoTimingOptions = ''
}

if ([string]::IsNullOrWhiteSpace($SourceDirectory)) {
    Write-Host 'Usage: .\iphone_search_encode.ps1 <SourceDirectory> [-OutputDirectory <Directory>] [-OutputSuffix <Suffix>]'
    Write-Host ''
    Write-Host 'Arguments:'
    Write-Host '  <SourceDirectory>            Required. Directory containing the source videos.'
    Write-Host '  -OutputDirectory <Directory>  Optional. Defaults to an "encoded" subdirectory in the source directory.'
    Write-Host '  -OutputSuffix <Suffix>        Optional. Defaults to no suffix.'
    exit 2
}

$ErrorActionPreference = 'Stop'

$environmentNames = @(
    'VIDEO_ENCODER',
    'VIDEO_TIMING_OPTIONS',
    'AUDIO_ENCODER',
    'OUTPUT_SUFFIX',
    'OUTPUT_DIR',
    'OUTPUT_EXT',
    'DELIVERY_NO_PAUSE',
    'DELIVERY_ALLOW_EMPTY_SUFFIX'
)
$originalEnvironment = @{}
foreach ($name in $environmentNames) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

try {
    if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
        throw "Source directory not found: $SourceDirectory"
    }
    $SourceDirectory = (Resolve-Path -LiteralPath $SourceDirectory).Path

    if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
        $OutputDirectory = Join-Path $SourceDirectory 'encoded'
    }
    if (-not (Test-Path -LiteralPath $OutputDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }
    $OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
    if (-not $OutputDirectory.EndsWith([IO.Path]::DirectorySeparatorChar)) {
        $OutputDirectory += [IO.Path]::DirectorySeparatorChar
    }

    $abAv1 = Get-Command ab-av1 -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    $deliveryScript = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\delivery.cmd')).Path
    $videoFiles = @(
        Get-ChildItem -LiteralPath $SourceDirectory -File -Filter $SearchEncodeOptions.InputFilter |
            Where-Object { $_.Name -notin $SearchEncodeOptions.ExcludedFiles } |
            Sort-Object Name
    )

    if ($videoFiles.Count -eq 0) {
        throw "No eligible source videos found in $SourceDirectory."
    }

    foreach ($video in $videoFiles) {
        Write-Host "`n=== Searching CRF: $($video.Name) ==="
        $minVmaf = ([double]$SearchEncodeOptions.MinVmaf).ToString(
            'R',
            [Globalization.CultureInfo]::InvariantCulture
        )
        $searchArgs = @(
            'crf-search', '-i', $video.FullName,
            '--encoder', $SearchEncodeOptions.Encoder,
            '--preset', [string]$SearchEncodeOptions.Preset,
            '--min-vmaf', $minVmaf
        )
        foreach ($encoderArg in $SearchEncodeOptions.SearchEncoderArgs) {
            $searchArgs += @('--enc', [string]$encoderArg)
        }
        $searchArgs += @('--stdout-format', 'json')

        $searchOutput = @(& $abAv1.Source @searchArgs)
        $searchExitCode = $LASTEXITCODE
        if ($searchExitCode -ne 0) {
            throw "CRF search failed for $($video.Name) (exit code $searchExitCode)."
        }

        $searchResult = $null
        foreach ($line in $searchOutput) {
            if ([string]$line -match '^\s*\{.*\}\s*$') {
                $message = [string]$line | ConvertFrom-Json
                if ($message.type -eq 'crf-search-done') {
                    $searchResult = $message
                }
            }
        }

        if ($null -eq $searchResult -or $null -eq $searchResult.crf) {
            throw "CRF search returned no successful result for $($video.Name)."
        }

        $crfText = ([double]$searchResult.crf).ToString(
            'R',
            [Globalization.CultureInfo]::InvariantCulture
        )
        Write-Host "Selected CRF $crfText (sample VMAF $($searchResult.vmaf))"

        $env:VIDEO_ENCODER = "$($SearchEncodeOptions.Encoder) -crf $crfText -preset $($SearchEncodeOptions.Preset)"
        $env:AUDIO_ENCODER = [string]$SearchEncodeOptions.AudioEncoder
        $env:OUTPUT_SUFFIX = $OutputSuffix
        $env:OUTPUT_DIR = $OutputDirectory
        $env:OUTPUT_EXT = [string]$SearchEncodeOptions.OutputExtension
        $env:DELIVERY_NO_PAUSE = '1'
        $env:DELIVERY_ALLOW_EMPTY_SUFFIX = '1'
        if ([string]::IsNullOrWhiteSpace($SearchEncodeOptions.VideoTimingOptions)) {
            Remove-Item Env:VIDEO_TIMING_OPTIONS -ErrorAction SilentlyContinue
        }
        else {
            $env:VIDEO_TIMING_OPTIONS = [string]$SearchEncodeOptions.VideoTimingOptions
        }

        Write-Host "=== Encoding: $($video.Name) ==="
        & $deliveryScript $video.FullName
        $deliveryExitCode = $LASTEXITCODE
        if ($deliveryExitCode -ne 0) {
            throw "Delivery encode failed for $($video.Name) (exit code $deliveryExitCode)."
        }
    }

    Write-Host "`nAll $($videoFiles.Count) videos searched and encoded successfully in $OutputDirectory"
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
finally {
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], 'Process')
    }
}
