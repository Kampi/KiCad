# Coding Standards — KiCad Part-DB Integration

These instructions apply to all Python files under `app/`.

## Language & Compatibility

- Target **Python 3.8+**; avoid features introduced in later versions.
- Follow **PEP 8** for formatting (max line length: 99 chars).
- Use **type hints** on all function signatures and return types.
- Prefer `pathlib.Path` over `os.path` for filesystem operations.

## Documentation

- Every module must have a module-level docstring explaining its purpose.
- Every public function/method must have a docstring with `Args:` and
  `Returns:` sections (Google style).
- Do **not** add comments that merely restate the code — only explain
  *why*, not *what*.

## Error Handling

- Catch specific exception types (`requests.HTTPError`, `FileNotFoundError`, …);
  never use bare `except:`.
- Propagate exceptions as `PartDBError` from within `PartDBClient`.
- The CLI (`app.py`) is the only place that calls `sys.exit()`.
- Log errors at `logging.ERROR`, warnings at `logging.WARNING`.

## API Communication

- All HTTP calls go through `PartDBClient` — no `requests` calls in `app.py`.
- The API key **must never** appear in logs, tracebacks, or error messages.
- Honour `--dry-run`: no write operations when this flag is set.

## Logging

- Use `logging.getLogger(__name__)` in every module.
- `INFO` for normal progress milestones.
- `DEBUG` for per-item detail (enabled via `--verbose`).
- `WARNING` for non-fatal issues (e.g. failed attachment upload).
- `ERROR` for fatal conditions before `sys.exit()`.

## Security

- Validate all file paths before opening them.
- Do not follow symlinks outside the expected release directory.
- Never construct shell commands from user-supplied input.

## Testing

- Write functions so that they can be tested without a live Part-DB instance
  (dependency injection via the `client` parameter, `--dry-run` flag).
- Avoid global state; pass configuration explicitly.

## Code Style

- Use **lowerCamelCase** for all function names, method names, and variable
  names: `processBoM`, `releaseDir`, `bomEntries`.
- Module-level constants remain in **SCREAMING\_SNAKE\_CASE**: `DEFAULT_CATEGORY_MAP`.
- `if`, `elif`, and `while` conditions are always wrapped in parentheses:
  `if (condition):`.
- Keyword arguments in function calls always use spaces around `=`:
  `func(arg = value)`.
- Exactly **one** blank line between functions or methods — never two or more.
