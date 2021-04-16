[CmdletBinding()]
param (
  [string] $Executable = '7z.exe',

  [int] $CompressionLevel = 1,

  [string] $CompressFolder,

  [string] $benchTemp = (Join-Path $env:TEMP 'Compare7ZAlgo')
)

function Get-SupportedCompressionAlgos {
  $7zi = & "$Executable" i
  $s = $false
  foreach ($l in $7zi) {
    if ($l -match "Codecs\:") {
      $s = $true
      continue
    }
    if ($s -And [string]::IsNullOrEmpty($l)) {
      break
    }
    if ($s) {
      $l = $l.Split(' ') | Where-Object -FilterScript { -Not [string]::IsNullOrEmpty($_) }
      @{
        name = $l[3]
        e    = $l[1].Contains('E')
        d    = $l[1].Contains('D')
      }
    }
  }
}

function Test-Algo {
  [CmdletBinding()]
  param (
    [Parameter()]
    [psobject] $CompressionAlgo
  )
  New-Item -ItemType Directory $benchTemp -ErrorAction SilentlyContinue | Out-Null
  $tgtFile = "$benchTemp\tb.$($CompressionAlgo.name).$($CompressionAlgo.name)"
  $el = 0
  $outsize = 0
  $meas = Measure-Command {
    $out = try {
      $cmdline = @("a" , "-m$CompressionLevel=$($CompressionAlgo.name)", "$tgtFile", "$CompressFolder")
      Write-Host "-> $cmdline"
      & "$Executable" $cmdline
      $el = $LASTEXITCODE
      if ($el -eq 0) {
        $outsize = (Get-Item $tgtFile).length / 1MB
      }
    }
    finally {
      Remove-Item $tgtFile -ErrorAction SilentlyContinue | Out-Null
    }
  }
  Write-Host "--> $($meas.TotalSeconds) sec / $($outsize) MB"
  if ($el -ne 0) {
    Write-Host "--> error, lastexitcode = $el, not using this measurement"
  }
  else {
    @{
      name        = $CompressionAlgo.name
      measurement = $meas
      output      = $out
      outsize     = $outsize
    }
  }
}

$results = Get-SupportedCompressionAlgos | Where-Object -FilterScript { $_.e } | ForEach-Object {
  Test-Algo $_
}

$results
