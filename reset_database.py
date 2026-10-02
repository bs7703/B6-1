#!/usr/bin/env python3
"""연습용 SQLite DB 전체 초기화 후 테이블 및 데이터를 다시 생성한다.

사용: python3 reset_database.py [DB 경로]
기본 DB: 이 스크립트와 같은 폴더의 library_practice.db
입력 파일: 같은 폴더의 create_table.sql, insert_items.sql
주의: 대상 DB의 모든 테이블, 데이터, 인덱스, 뷰, 트리거가 교체된다.
"""

import argparse
import sqlite3
import sys
import time
from pathlib import Path


def main():
    folder = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("database", nargs="?", default=str(folder / "library_practice.db"))
    args = parser.parse_args()
    db_path = Path(args.database).expanduser().resolve()
    schema_path = folder / "create_table.sql"
    items_path = folder / "insert_items.sql"

    if sqlite3.sqlite_version_info < (3, 37, 0):
        raise RuntimeError("Python의 SQLite가 3.37.0 이상이어야 합니다. Python을 업데이트하세요.")
    if db_path in {schema_path, items_path, Path(__file__).resolve(), folder / "db_alias.sh"}:
        raise ValueError("SQL 또는 스크립트 파일을 DB 경로로 지정할 수 없습니다.")
    if not db_path.parent.is_dir():
        raise FileNotFoundError("대상 DB의 부모 폴더가 없습니다: " + str(db_path.parent))

    # SQL 오류를 확인한 후에만 대상 DB를 변경한다.
    schema = schema_path.read_text(encoding="utf-8")
    items = items_path.read_text(encoding="utf-8")
    staging = sqlite3.connect(":memory:")
    try:
        staging.execute("PRAGMA foreign_keys = ON")
        staging.executescript(schema)
        staging.executescript(items)
        if staging.execute("PRAGMA foreign_keys").fetchone()[0] != 1:
            raise RuntimeError("외래키 검사가 비활성화되어 있습니다.")
        if staging.execute("PRAGMA foreign_key_check").fetchall():
            raise RuntimeError("생성된 데이터에 외래키 제약 위반이 있습니다.")
        if staging.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            raise RuntimeError("생성된 데이터베이스의 무결성 검사에 실패했습니다.")

        counts = [(name, staging.execute("SELECT COUNT(*) FROM " + name).fetchone()[0])
                  for name in ("categories", "authors", "users", "books", "loans")]
        active = staging.execute(
            "SELECT COUNT(*) FROM loans WHERE return_date IS NULL"
        ).fetchone()[0]

        deadline = time.monotonic() + 10

        def check_timeout(status, remaining, total):
            if time.monotonic() > deadline:
                raise TimeoutError("DB가 사용 중입니다. 다른 작업을 끝내고 다시 실행하세요.")

        # SQLite 백업 API로 DB 전체를 교체한다. 기존 파일을 rm으로 삭제하지 않는다.
        target = sqlite3.connect(str(db_path), timeout=5)
        try:
            staging.backup(target, pages=64, progress=check_timeout, sleep=0.1)
        finally:
            target.close()
    finally:
        staging.close()

    print("초기화 완료:", db_path)
    for name, count in counts:
        print(f"{name}: {count}")
    print(f"현재 대출: {active}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, sqlite3.Error, RuntimeError, ValueError) as error:
        print("초기화 실패:", error, file=sys.stderr)
        sys.exit(1)
