"""Shared bridge errors, timestamps and bounds for SQLite/API identifiers."""
from datetime import datetime, timezone

MAX_ID = 2**53 - 1


class BridgeError(Exception):
    def __init__(self, code, message, status=400):
        self.code, self.message, self.status = code, message, status
        super().__init__(message)


def now():
    return datetime.now(timezone.utc).isoformat()


def valid_id(value):
    return type(value) is int and 1 <= value <= MAX_ID


def page_bounds(page, page_size, *, status=400):
    """Return a safe SQLite LIMIT/OFFSET without coercing bools or huge ints."""
    if (type(page) is not int or type(page_size) is not int
            or not 1 <= page_size <= 100 or not 1 <= page <= MAX_ID // page_size):
        raise BridgeError('VALIDATION_FAILED', '페이지 범위를 확인하세요.', status)
    return page_size, (page - 1) * page_size
