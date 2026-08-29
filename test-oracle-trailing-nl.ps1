. "$PSScriptRoot/Tests/Helpers/OracleClient.ps1"

$proc = Start-OracleService -TimeoutSeconds 20
Write-Host "Oracle started"

# Test 1: comment at start
$t1 = "{# Comment at start -#}`nContent line.`n"
$r1 = Invoke-OracleRender -Template $t1 -Context @{} -UndefinedMode 'default'
Write-Host "Comment at start  : [$r1] length=$($r1.Length)"

# Test 2: comment at end  
$t2 = "Content line.`n{# Comment at end -#}`n"
$r2 = Invoke-OracleRender -Template $t2 -Context @{} -UndefinedMode 'default'
Write-Host "Comment at end    : [$r2] length=$($r2.Length)"

# Test 3: plain text with trailing newline
$t3 = "Content line.`n"
$r3 = Invoke-OracleRender -Template $t3 -Context @{} -UndefinedMode 'default'
Write-Host "Plain trailing nl : [$r3] length=$($r3.Length)"

# Test 4: variable at end with trailing newline
$t4 = "{{ x }}`n"
$r4 = Invoke-OracleRender -Template $t4 -Context @{x='Value'} -UndefinedMode 'default'
Write-Host "Variable at end   : [$r4] length=$($r4.Length)"

# Test 5: if block ending with -%}
$t5 = "{% if true -%}`nContent`n{% endif -%}`n"
$r5 = Invoke-OracleRender -Template $t5 -Context @{} -UndefinedMode 'default'
Write-Host "if block -%}      : [$r5] length=$($r5.Length)"

Stop-OracleService -Process $proc
