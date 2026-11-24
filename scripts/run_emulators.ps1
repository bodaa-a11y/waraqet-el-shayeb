# Keep this terminal open. Start Flutter in a SECOND terminal.
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root
Push-Location functions
try { npm install; if($LASTEXITCODE -ne 0){throw 'npm install failed'}; npm run build; if($LASTEXITCODE -ne 0){throw 'TypeScript compilation failed'} }
finally { Pop-Location }
firebase emulators:start --project demo-el-shayeb --only auth,firestore,functions,storage
