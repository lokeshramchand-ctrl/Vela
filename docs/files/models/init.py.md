# File: `models/__init__.py`

## Purpose
Marks `models/` as a Python package so `schemas.py` can be imported as `models.schemas`.

## Responsibilities
None — the file is completely empty.

## Imports
None.

## Exports
None.

## Execution Flow
Same as `database/__init__.py` — executed (as a no-op) whenever `models` is first imported, before the specific submodule (`models.schemas`) loads.

## Functions (plain English)
No functions exist in this file.

## Classes
No classes exist in this file.

## Interfaces
Not applicable.

## Hooks
Not applicable.

## Utilities
Not applicable.

## Dependencies
None.

## Side Effects
None.

## Performance Considerations
None.

## Possible Interview Questions
- "Every module in this codebase imports from `models.schemas` directly (`from models.schemas import X`) rather than `from models import X`. What would you need to change here to support the shorter form?" (Add explicit re-exports, e.g. `from .schemas import *` or named imports, to this file — currently it provides none.)
