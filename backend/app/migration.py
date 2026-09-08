"""One-time, narrowly scoped cleanup for the original local catalog."""

import os
import sqlite3


DEFAULT_LEGACY_DB_PATH = os.path.abspath(
    os.path.join(os.path.dirname(os.path.dirname(__file__)), "instance", "addiguard.db")
)


def cleanup_legacy_additives(db_path: str | None = None) -> bool:
    """Drop only the obsolete additives table, preserving all other tables."""
    path = os.path.abspath(db_path or DEFAULT_LEGACY_DB_PATH)
    if not os.path.isfile(path):
        return False
    with sqlite3.connect(path) as connection:
        connection.execute("DROP TABLE IF EXISTS additives")
        connection.commit()
    return True
