"""Remove the obsolete local additive catalog without touching other data."""

import os

from app.migration import cleanup_legacy_additives


if __name__ == "__main__":
    path = os.environ.get("LEGACY_DB_PATH")
    print("Legacy additive catalog removed." if cleanup_legacy_additives(path) else "No legacy database found.")
