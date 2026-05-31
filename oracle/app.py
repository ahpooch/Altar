#!/usr/bin/env python3
"""
Jinja2 Oracle Service
---------------------
A RESTful HTTP service that exposes canonical Jinja2 rendering behavior
for compatibility testing of the PowerShell Template Engine (Altar).

Jinja2 is the source of truth. This service contains no templating logic
of its own — it only proxies calls to the Jinja2 API.
"""

import sys
import platform
import jinja2

from flask import Flask, request, jsonify
from jinja2 import (
    Environment,
    Undefined,
    StrictUndefined,
    TemplateSyntaxError,
)

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------

app = Flask(__name__)
app.json.sort_keys = False  # preserve key insertion order in JSON responses

JINJA2_VERSION: str = jinja2.__version__

# Mapping of string mode names to Jinja2 Undefined classes
UNDEFINED_MAP: dict = {
    "strict":  StrictUndefined,
    "default": Undefined,
}

DEFAULT_UNDEFINED_MODE = "strict"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_env(undefined_mode: str | None) -> Environment:
    """
    Create a fresh Jinja2 Environment for each request.
    No global state is mutated between requests.
    """
    mode = (undefined_mode or DEFAULT_UNDEFINED_MODE).lower()
    undefined_class = UNDEFINED_MAP.get(mode, StrictUndefined)

    return Environment(
        undefined=undefined_class,
        autoescape=False,
        trim_blocks=False,
        lstrip_blocks=False,
        keep_trailing_newline=True,
        optimized=True,
        enable_async=False,
    )


def _render_one(item: dict) -> dict:
    """
    Render a single template request.
    Returns a response dict in the unified response format.
    """
    request_id     = item.get("request_id")
    template_str   = item.get("template", "")
    context        = item.get("context") or {}
    undefined_mode = item.get("undefined_mode")

    base = {
        "success": False,
        "version": JINJA2_VERSION,
    }
    if request_id is not None:
        base["request_id"] = request_id

    try:
        env    = _make_env(undefined_mode)
        tmpl   = env.from_string(template_str)
        output = tmpl.render(**context)
        return {**base, "success": True, "output": output}

    except Exception as exc:
        return {
            **base,
            "success":   False,
            "exception": type(exc).__name__,
            "message":   str(exc),
        }


def _ast_node_to_dict(node) -> dict | list | str | int | float | bool | None:
    """
    Recursively serialize a Jinja2 AST node into a JSON-compatible structure.
    """
    if node is None:
        return None

    if isinstance(node, jinja2.nodes.Node):
        result = {"node_type": type(node).__name__}
        for field_name, field_value in node.iter_fields():
            result[field_name] = _ast_node_to_dict(field_value)
        return result

    if isinstance(node, list):
        return [_ast_node_to_dict(child) for child in node]

    # Primitives (str, int, float, bool, None) — return as-is
    return node


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@app.post("/render")
def render():
    """
    POST /render — render a single Jinja2 template.

    Request body (JSON):
        request_id     : str   (optional) — echoed back unchanged
        template       : str   — Jinja2 template string
        context        : dict  — template variables
        undefined_mode : str   — "strict" (default) | "default"

    Success response:
        { "request_id": ..., "success": true, "version": "...", "output": "..." }

    Error response:
        { "request_id": ..., "success": false, "version": "...",
          "exception": "UndefinedError", "message": "..." }
    """
    data   = request.get_json(force=True, silent=True) or {}
    result = _render_one(data)
    return jsonify(result)


@app.post("/batch")
def batch():
    """
    POST /batch — render multiple templates in a single HTTP request.

    Request body (JSON): array of objects with the same structure as /render.

    Response: array of results with the same structure as /render.
    """
    data = request.get_json(force=True, silent=True)

    if not isinstance(data, list):
        return jsonify({
            "success":   False,
            "version":   JINJA2_VERSION,
            "exception": "ValueError",
            "message":   "Request body must be a JSON array",
        }), 400

    results = [_render_one(item) for item in data]
    return jsonify(results)


@app.post("/parse")
def parse():
    """
    POST /parse — parse a template and return its AST.

    Request body (JSON):
        request_id : str  (optional)
        template   : str  — Jinja2 template string

    Success response:
        { "request_id": ..., "success": true, "version": "...", "ast": { ... } }

    Error response (TemplateSyntaxError):
        { "request_id": ..., "success": false, "version": "...",
          "exception": "TemplateSyntaxError", "message": "...", "line": N }
    """
    data         = request.get_json(force=True, silent=True) or {}
    request_id   = data.get("request_id")
    template_str = data.get("template", "")

    base = {"success": False, "version": JINJA2_VERSION}
    if request_id is not None:
        base["request_id"] = request_id

    try:
        env = _make_env(DEFAULT_UNDEFINED_MODE)
        ast = env.parse(template_str)
        return jsonify({**base, "success": True, "ast": _ast_node_to_dict(ast)})

    except TemplateSyntaxError as exc:
        return jsonify({
            **base,
            "success":   False,
            "exception": type(exc).__name__,
            "message":   str(exc),
            "line":      exc.lineno,
        })
    except Exception as exc:
        return jsonify({
            **base,
            "success":   False,
            "exception": type(exc).__name__,
            "message":   str(exc),
        })


@app.post("/validate")
def validate():
    """
    POST /validate — validate template syntax without rendering.

    Request body (JSON):
        request_id : str  (optional)
        template   : str  — Jinja2 template string

    Success response:
        { "request_id": ..., "success": true, "version": "..." }

    Error response:
        { "request_id": ..., "success": false, "version": "...",
          "exception": "TemplateSyntaxError", "message": "...", "line": N }
    """
    data         = request.get_json(force=True, silent=True) or {}
    request_id   = data.get("request_id")
    template_str = data.get("template", "")

    base = {"success": False, "version": JINJA2_VERSION}
    if request_id is not None:
        base["request_id"] = request_id

    try:
        env = _make_env(DEFAULT_UNDEFINED_MODE)
        env.parse(template_str)  # parse only, no rendering
        return jsonify({**base, "success": True})

    except TemplateSyntaxError as exc:
        return jsonify({
            **base,
            "success":   False,
            "exception": type(exc).__name__,
            "message":   str(exc),
            "line":      exc.lineno,
        })
    except Exception as exc:
        return jsonify({
            **base,
            "success":   False,
            "exception": type(exc).__name__,
            "message":   str(exc),
        })


@app.get("/health")
def health():
    """
    GET /health — service liveness check.

    Response:
        { "status": "ok", "version": "3.1.x" }
    """
    return jsonify({
        "status":  "ok",
        "version": JINJA2_VERSION,
    })


@app.get("/environment")
def environment():
    """
    GET /environment — Jinja2 environment configuration and capabilities.

    Filters, tests and extensions are built dynamically via the Jinja2 API.
    Hard-coding these values is not permitted.

    Response:
        {
          "version": "3.1.x",
          "python_version": "3.11.x",
          "environment": { ... },
          "extensions": [...],
          "filters": [...],
          "tests": [...]
        }
    """
    env = _make_env(DEFAULT_UNDEFINED_MODE)

    return jsonify({
        "version":        JINJA2_VERSION,
        "python_version": platform.python_version(),
        "environment": {
            "undefined":             type(env.undefined).__name__,
            "autoescape":            env.autoescape,
            "trim_blocks":           env.trim_blocks,
            "lstrip_blocks":         env.lstrip_blocks,
            "newline_sequence":      env.newline_sequence,
            "keep_trailing_newline": env.keep_trailing_newline,
            "optimized":             env.optimized,
            "enable_async":          env.enable_async,
        },
        "extensions": list(env.extensions.keys()),
        "filters":    sorted(env.filters.keys()),
        "tests":      sorted(env.tests.keys()),
    })


@app.get("/capabilities")
def capabilities():
    """
    GET /capabilities — machine-readable list of oracle capabilities.

    Intended for future API evolution without breaking client logic.

    Response:
        {
          "render": true,
          "batch": true,
          "parse": true,
          "validate": true,
          "environment": true,
          "strict_undefined": true,
          "default_undefined": true,
          "ast_export": true
        }
    """
    return jsonify({
        "render":            True,
        "batch":             True,
        "parse":             True,
        "validate":          True,
        "environment":       True,
        "strict_undefined":  True,
        "default_undefined": True,
        "ast_export":        True,
    })


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 5000
    print(f"Jinja2 Oracle Service v{JINJA2_VERSION} starting on port {port}", flush=True)
    app.run(host="0.0.0.0", port=port, debug=False)
