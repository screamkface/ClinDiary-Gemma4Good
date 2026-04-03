from __future__ import annotations

import json
from typing import Any

from sqlalchemy import JSON
from sqlalchemy.types import TypeDecorator, UserDefinedType


class _PgVector(UserDefinedType):
    cache_ok = True

    def get_col_spec(self, **kw: Any) -> str:
        return "vector"


class VectorListType(TypeDecorator):
    impl = JSON
    cache_ok = True

    def load_dialect_impl(self, dialect):
        if dialect.name == "postgresql":
            return dialect.type_descriptor(_PgVector())
        return dialect.type_descriptor(JSON())

    def process_bind_param(self, value, dialect):
        if value is None:
            return None
        normalized = [float(item) for item in value]
        if dialect.name == "postgresql":
            return "[" + ",".join(f"{item:.10f}".rstrip("0").rstrip(".") for item in normalized) + "]"
        return normalized

    def process_result_value(self, value, dialect):
        if value is None:
            return None
        if isinstance(value, list):
            return [float(item) for item in value]
        if isinstance(value, str):
            payload = value.strip()
            if payload.startswith("[") and payload.endswith("]"):
                inner = payload[1:-1].strip()
                if not inner:
                    return []
                return [float(item.strip()) for item in inner.split(",") if item.strip()]
            try:
                decoded = json.loads(payload)
            except json.JSONDecodeError:
                return value
            if isinstance(decoded, list):
                return [float(item) for item in decoded]
        return value
