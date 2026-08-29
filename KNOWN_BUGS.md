# Known Bugs

## Bug with `not` unary operator when it is before property-access expression like `loop.last`.
see: c:\Users\User\Documents\GitHub\Altar\Tests\Integration\TrailingNewlines.Tests.ps1
test: comma-separated items using loop.last produces no trailing comma
template: {% for i in items %}{{ i }}{% if not loop.last %},{% endif %}{% endfor %}
error: Template error at template:2800:31 - Unexpected keyword in expression: not