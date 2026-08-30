#!/usr/bin/env pwsh
# Quick smoke test for the Jinja2 Oracle Service.
# Assumes the service is already running on http://localhost:5000.

$base = 'http://localhost:5000'

function Show($label, $obj) {
    Write-Host "`n--- $label ---" -ForegroundColor Cyan
    $obj | ConvertTo-Json -Depth 5 | Write-Host
}

# /health
Show '/health' (Invoke-RestMethod "$base/health")

# /render — success
Show '/render (success)' (Invoke-RestMethod "$base/render" -Method Post -ContentType 'application/json' -Body (
    @{ request_id='t1'; template='Hello {{ name | upper }}!'; context=@{name='world'}; undefined_mode='strict' } | ConvertTo-Json -Depth 5
))

# /render — UndefinedError
Show '/render (UndefinedError)' (Invoke-RestMethod "$base/render" -Method Post -ContentType 'application/json' -Body (
    @{ request_id='t2'; template='{{ missing }}'; context=@{}; undefined_mode='strict' } | ConvertTo-Json -Depth 5
))

# /validate — valid
Show '/validate (valid)' (Invoke-RestMethod "$base/validate" -Method Post -ContentType 'application/json' -Body (
    @{ template='{% if x %}ok{% endif %}' } | ConvertTo-Json
))

# /validate — syntax error
Show '/validate (syntax error)' (Invoke-RestMethod "$base/validate" -Method Post -ContentType 'application/json' -Body (
    @{ template='{% if %}oops' } | ConvertTo-Json
))

# /batch
$batchBody = @(
    @{ request_id='b1'; template='{{ x + y }}'; context=@{x=1; y=2} }
    @{ request_id='b2'; template='{{ z }}';     context=@{} }
) | ConvertTo-Json -Depth 5
Show '/batch' (Invoke-RestMethod "$base/batch" -Method Post -ContentType 'application/json' -Body $batchBody)

# /capabilities
Show '/capabilities' (Invoke-RestMethod "$base/capabilities")

Write-Host "`nSmoke test complete." -ForegroundColor Green
