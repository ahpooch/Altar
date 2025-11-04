#!/usr/bin/env python3
from jinja2 import Environment

template_str = """<ul>
    {% for item in items %}
    <li>{{ item }}</li>
    {% endfor %}
</ul>"""

items = ["one", "two"]

print("=== Test 1: trim_blocks=False, lstrip_blocks=False (default) ===")
env1 = Environment(trim_blocks=False, lstrip_blocks=False)
template1 = env1.from_string(template_str)
result1 = template1.render(items=items)
print("Result:")
print(result1)
print("\nEscaped:")
print(repr(result1))

print("\n=== Test 2: trim_blocks=True, lstrip_blocks=False ===")
env2 = Environment(trim_blocks=True, lstrip_blocks=False)
template2 = env2.from_string(template_str)
result2 = template2.render(items=items)
print("Result:")
print(result2)
print("\nEscaped:")
print(repr(result2))

print("\n=== Test 3: trim_blocks=False, lstrip_blocks=True ===")
env3 = Environment(trim_blocks=False, lstrip_blocks=True)
template3 = env3.from_string(template_str)
result3 = template3.render(items=items)
print("Result:")
print(result3)
print("\nEscaped:")
print(repr(result3))

print("\n=== Test 4: trim_blocks=True, lstrip_blocks=True ===")
env4 = Environment(trim_blocks=True, lstrip_blocks=True)
template4 = env4.from_string(template_str)
result4 = template4.render(items=items)
print("Result:")
print(result4)
print("\nEscaped:")
print(repr(result4))
