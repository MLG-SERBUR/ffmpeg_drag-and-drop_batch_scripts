$SearchEncodeOptions = [ordered]@{
    SourceDirectory      = 'F:\final\S\S'
    InputFilter          = '*.MOV'
    ExcludedFiles        = @('IMG_4643.MOV', 'IMG_4644.MOV')
    Encoder              = 'libsvtav1'
    Preset               = 4
    MinVmaf              = 95
    SearchEncoderArgs    = @(
        'copyts',
        'copytb=1',
        'enc_time_base=demux',
        'fps_mode=passthrough'
    )
    AudioEncoder         = 'copy'
    OutputSuffix         = '_av1'
    OutputDirectory      = ''
    OutputExtension      = '.mp4'
    VideoTimingOptions   = ''
}
