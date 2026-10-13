param(
    [string]$SourceDirectory
)

$ErrorActionPreference = 'Stop'
$optionsPath = Join-Path $PSScriptRoot 'search_encode_options.ps1'
. $optionsPath

if (-not $SearchEncodeOptions) {
    throw "Options script did not define SearchEncodeOptions: $optionsPath"
}

if (-not $SourceDirectory) {
    $SourceDirectory = $SearchEncodeOptions.SourceDirectory
}

$environmentNames = @(
    'VIDEO_ENCODER',
    'VIDEO_TIMING_OPTIONS',
    'AUDIO_ENCODER',
    'OUTPUT_SUFFIX',
    'OUTPUT_DIR',
    'OUTPUT_EXT',
    'DELIVERY_NO_PAUSE'
)
$originalEnvironment = @{}
foreach ($name in $environmentNames) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

try {
    if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
        throw "Source directory not found: $SourceDirectory"
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
        $env:OUTPUT_SUFFIX = [string]$SearchEncodeOptions.OutputSuffix
        $env:OUTPUT_DIR = [string]$SearchEncodeOptions.OutputDirectory
        $env:OUTPUT_EXT = [string]$SearchEncodeOptions.OutputExtension
        $env:DELIVERY_NO_PAUSE = '1'
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

    Write-Host "`nAll $($videoFiles.Count) videos searched and encoded successfully."
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
