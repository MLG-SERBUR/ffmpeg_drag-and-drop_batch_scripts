param(
    [string]$SourceDirectory = 'F:\final\S\S'
)

$ErrorActionPreference = 'Stop'
$vmafThreshold = 95.0
$excludedFiles = @('IMG_4643.MOV', 'IMG_4644.MOV')
$environmentNames = @(
    'VIDEO_ENCODER',
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
        Get-ChildItem -LiteralPath $SourceDirectory -File -Filter '*.MOV' |
            Where-Object { $_.Name -notin $excludedFiles } |
            Sort-Object Name
    )

    if ($videoFiles.Count -eq 0) {
        throw "No eligible .MOV source videos found in $SourceDirectory."
    }

    foreach ($video in $videoFiles) {
        Write-Host "`n=== Searching CRF: $($video.Name) ==="
        $searchArgs = @(
            'crf-search', '-i', $video.FullName,
            '--encoder', 'libsvtav1',
            '--preset', '4',
            '--min-vmaf', "$vmafThreshold",
            '--enc', 'copyts',
            '--enc', 'copytb=1',
            '--enc', 'enc_time_base=demux',
            '--enc', 'fps_mode=passthrough',
            '--stdout-format', 'json'
        )
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

        $env:VIDEO_ENCODER = "libsvtav1 -crf $crfText -preset 4"
        $env:AUDIO_ENCODER = 'copy'
        $env:OUTPUT_SUFFIX = '_av1'
        $env:OUTPUT_DIR = ''
        $env:OUTPUT_EXT = '.mp4'
        $env:DELIVERY_NO_PAUSE = '1'

        Write-Host "=== Encoding: $($video.Name) ==="
        & $deliveryScript $video.FullName
        $deliveryExitCode = $LASTEXITCODE
        if ($deliveryExitCode -ne 0) {
            throw "Delivery encode failed for $($video.Name) (exit code $deliveryExitCode)."
        }

        $outputPath = Join-Path $video.DirectoryName ($video.BaseName + '_av1.mp4')
        if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
            throw "Delivery completed without creating the expected output: $outputPath"
        }

        Write-Host "=== Full-file VMAF: $($video.Name) ==="
        $vmafOutput = @(& $abAv1.Source vmaf --reference $video.FullName --distorted $outputPath)
        $vmafExitCode = $LASTEXITCODE
        if ($vmafExitCode -ne 0) {
            throw "VMAF verification failed for $($video.Name) (exit code $vmafExitCode)."
        }

        $scoreLine = $vmafOutput |
            Where-Object { [string]$_ -match '^\s*\d+(?:\.\d+)?\s*$' } |
            Select-Object -Last 1
        $score = 0.0
        if ($null -eq $scoreLine -or -not [double]::TryParse(
            ([string]$scoreLine).Trim(),
            [Globalization.NumberStyles]::Float,
            [Globalization.CultureInfo]::InvariantCulture,
            [ref]$score
        )) {
            throw "Could not parse the VMAF score for $($video.Name)."
        }

        if ($score -lt $vmafThreshold) {
            throw "VMAF verification failed for $($video.Name): $score is below $vmafThreshold."
        }

        Write-Host ("[PASS] {0}: VMAF {1:F2}" -f $video.Name, $score)
    }

    Write-Host "`nAll $($videoFiles.Count) videos encoded and verified at VMAF $vmafThreshold or higher."
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
