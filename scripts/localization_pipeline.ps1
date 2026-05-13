param(
  [Parameter(Position = 0)]
  [string]$Command = 'audit',

  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$mobileDir = Join-Path $PSScriptRoot '..\apps\mobile'
if (-not (Test-Path -LiteralPath $mobileDir)) {
  throw "apps/mobile not found next to scripts folder."
}

Push-Location $mobileDir
try {
  & dart run tool/localization_pipeline.dart $Command @Args
  if (-not $?) {
    exit $LASTEXITCODE
  }
}
finally {
  Pop-Location
}
