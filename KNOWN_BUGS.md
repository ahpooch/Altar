# Known Bugs

## Bug with `not` unary operator when it is before property-access expression like `loop.last`.
see: c:\Users\User\Documents\GitHub\Altar\Tests\Integration\TrailingNewlines.Tests.ps1
test: comma-separated items using loop.last produces no trailing comma
template: {% for i in items %}{{ i }}{% if not loop.last %},{% endif %}{% endfor %}
error: Template error at template:2800:31 - Unexpected keyword in expression: not

## Compatibility issues in Filters.Tests.ps1
Failure | Reason
string filter should convert null to empty string | Altar returns "", Jinja2 returns "None"
ljust / rjust | Jinja2 doesn't have these filters (oracle: No filter named 'ljust'/'rjust')
replace filter should handle count=0 as replace all | Altar replaces all; Jinja2 treats count=0 as "replace none"
attr filter should get attribute value | Jinja2's `attr` uses `getattr(obj, name)` (Python attribute access), which fails on plain dicts — `getattr({"name":"John"}, "name")` raises `AttributeError → UndefinedError`. Altar uses hashtable key lookup (`$value[$name]`), which is the correct PowerShell equivalent. Oracle call removed from the test.
default filter should provide default value for null | Altar returns "N/A", Jinja2 returns "None"

## Hanging forever bug
Using `{-#` instead of `{#-` will hang Altar forever
```
$template = @"
{-#
Comment at start
spanning multiple lines
-#}
Content line.
"@
$context = @{}
Invoke-AltarTemplate -Template $template -Context $context       
```