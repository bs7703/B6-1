#!/usr/bin/env python3
"""실제 SQLite 실행으로 제출 로그를 재생성한다. 사용자 DB는 수정하지 않는다.

실행: python3 verify_submission.py
표준 라이브러리만 사용하며 매번 새 메모리 DB를 생성한다.
"""

import json
import platform
import sqlite3
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LOGS = ROOT / "result_log"
TABLES = ("categories", "authors", "users", "books", "loans")


def statements(text):
    pending = ""
    for line in text.splitlines(keepends=True):
        pending += line
        if sqlite3.complete_statement(pending):
            yield pending.strip()
            pending = ""
    if pending.strip():
        raise ValueError("마지막 SQL 문에 세미콜론이 없거나 미완성 문이 있습니다.")


def fresh_db(with_data=True):
    connection = sqlite3.connect(":memory:")
    connection.execute("PRAGMA foreign_keys = ON")
    connection.executescript((ROOT / "create_table.sql").read_text(encoding="utf-8"))
    if with_data:
        connection.executescript((ROOT / "insert_items.sql").read_text(encoding="utf-8"))
    return connection


def table_text(columns, rows):
    def value(item):
        return "NULL" if item is None else str(item)

    def width(item):
        return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in item)

    data = [list(columns)] + [[value(item) for item in row] for row in rows]
    sizes = [max(width(row[i]) for row in data) for i in range(len(columns))]
    lines = []
    for index, row in enumerate(data):
        lines.append(" | ".join(item + " " * (sizes[i] - width(item))
                                for i, item in enumerate(row)).rstrip())
        if index == 0:
            lines.append("-+-".join("-" * size for size in sizes))
    lines.append(f"rows: {len(rows)}")
    return "\n".join(lines)


def run_file(connection, path):
    entries = []
    transcript = [f"SQLite {sqlite3.sqlite_version}; Python {platform.python_version()}",
                  "Engine: Python sqlite3; real execution, not copied expected output.",
                  "Reference date: 2026-10-02; NULL is printed explicitly.",
                  f"File: {path}; foreign_keys={connection.execute('PRAGMA foreign_keys').fetchone()[0]}"]
    for number, statement in enumerate(statements((ROOT / path).read_text(encoding="utf-8")), 1):
        cursor = connection.execute(statement)
        columns = [item[0] for item in cursor.description] if cursor.description else []
        rows = cursor.fetchall()
        entries.append({"sql": statement, "columns": columns, "rows": rows})
        transcript.extend([f"\n=== {path} statement {number} ===", statement,
                           table_text(columns, rows) if columns else "completed"])
    return entries, "\n".join(transcript) + "\n"


def write_log(name, text):
    (LOGS / name).write_text(text, encoding="utf-8")


def check_constraints(connection):
    report = [f"SQLite {sqlite3.sqlite_version}; Engine: Python sqlite3",
              f"PRAGMA foreign_keys = {connection.execute('PRAGMA foreign_keys').fetchone()[0]}",
              "Every case uses SAVEPOINT and is rolled back; seed data is preserved."]

    def failure(label, sql, expected):
        before = list(connection.iterdump())
        connection.execute("SAVEPOINT check_case")
        try:
            try:
                connection.execute(sql).fetchall()
            except sqlite3.IntegrityError as error:
                if expected not in str(error):
                    raise AssertionError(f"Unexpected error in {label}: {error}") from error
                report.extend([f"\nPASS: {label}", sql,
                               f"Actual error: {error}",
                               f"SQLite error: {getattr(error, 'sqlite_errorname', 'unavailable')}"])
            else:
                raise AssertionError(f"Expected failure: {label}")
        finally:
            connection.execute("ROLLBACK TO check_case")
            connection.execute("RELEASE check_case")
        assert list(connection.iterdump()) == before, label
        report.append("Data unchanged: yes")

    for fk, sql in [
        ("books.category_id", "INSERT INTO books VALUES(9001,'검증 도서',1,999)"),
        ("books.author_id", "INSERT INTO books VALUES(9001,'검증 도서',999,1)"),
        ("loans.user_id", "INSERT INTO loans VALUES(9001,999,30,'2026-10-02',NULL)"),
        ("loans.book_id", "INSERT INTO loans VALUES(9001,1,999,'2026-10-02',NULL)"),
    ]:
        failure("missing parent: " + fk, sql, "FOREIGN KEY")
    for table, column in [("categories", "category_id"), ("authors", "author_id"),
                          ("users", "user_id"), ("books", "book_id")]:
        failure("ON DELETE RESTRICT: " + table,
                f"DELETE FROM {table} WHERE {column}=1", "FOREIGN KEY")
    failure("category PK duplicate", "INSERT INTO categories VALUES(1,'중복')", "UNIQUE")
    failure("category cannot be NULL", "INSERT INTO books VALUES(9001,'검증 도서',1,NULL)", "NOT NULL")
    failure("one active loan per book", "INSERT INTO loans VALUES(9001,2,1,'2026-10-02',NULL)", "UNIQUE")
    failure("return before loan", "INSERT INTO loans VALUES(9001,1,30,'2026-10-02','2026-10-01')", "CHECK")
    failure("date format", "INSERT INTO loans VALUES(9001,1,30,'2026/10/02',NULL)", "CHECK")
    failure("title length", "INSERT INTO books VALUES(9001,'123456789012345678901',1,1)", "CHECK")

    for parent, pk, child, fk in [("authors", "author_id", "books", "author_id"),
                                  ("categories", "category_id", "books", "category_id"),
                                  ("users", "user_id", "loans", "user_id"),
                                  ("books", "book_id", "loans", "book_id")]:
        connection.execute("SAVEPOINT check_case")
        try:
            expected = connection.execute(f"SELECT COUNT(*) FROM {child} WHERE {fk}=1").fetchone()[0]
            connection.execute(f"UPDATE {parent} SET {pk}=1001 WHERE {pk}=1")
            actual = connection.execute(f"SELECT COUNT(*) FROM {child} WHERE {fk}=1001").fetchone()[0]
            assert expected > 0 and actual == expected
            assert connection.execute(f"SELECT COUNT(*) FROM {child} WHERE {fk}=1").fetchone()[0] == 0
            report.extend([f"\nPASS: ON UPDATE CASCADE {parent}.{pk} -> {child}.{fk}",
                           f"Parent ID changed: 1 -> 1001; child rows changed: {actual}"])
        finally:
            connection.execute("ROLLBACK TO check_case")
            connection.execute("RELEASE check_case")

    # 같은 책의 반납 완료 이력은 여러 건 저장할 수 있음을 확인한다.
    connection.execute("SAVEPOINT check_case")
    try:
        connection.execute("INSERT INTO loans VALUES(9001,1,1,'2024-01-01','2024-01-02')")
        report.append("\nPASS: returned history for the same book is allowed by the partial UNIQUE index")
    finally:
        connection.execute("ROLLBACK TO check_case")
        connection.execute("RELEASE check_case")
    assert connection.execute("PRAGMA foreign_key_check").fetchall() == []
    assert connection.execute("PRAGMA integrity_check").fetchone() == ("ok",)
    report.extend(["\nPRAGMA foreign_key_check: 0 rows", "PRAGMA integrity_check: ok"])
    return "\n".join(report) + "\n"


def main():
    if sqlite3.sqlite_version_info < (3, 37, 0):
        raise RuntimeError("SQLite 3.37.0 or later is required")
    LOGS.mkdir(exist_ok=True)
    connection = fresh_db()
    try:
        counts = {table: connection.execute("SELECT COUNT(*) FROM " + table).fetchone()[0]
                  for table in TABLES}
        assert list(counts.values()) == [10, 12, 30, 30, 185]
        assert all(number >= 10 for number in counts.values())
        write_log("table_counts.log", table_text(["table", "row_count"], list(counts.items()))
                  + "\nPASS: every table has at least 10 rows.\n")

        query_rows, query_log = run_file(connection, "library_queries.sql")
        core_rows, core_log = run_file(connection, "bonus/core.sql")
        assert len(query_rows) == 12 and len(core_rows) == 3
        assert query_rows[7]["rows"] == [(8, "황석영")]
        assert query_rows[11]["rows"] == [(30, "돈의 속성")]
        assert query_rows[8]["rows"][-3:] == [(8, "역사", 0), (9, "예술", 0), (10, "여행", 0)]
        assert [list(entry["rows"][0]) for entry in core_rows] == [
            [30, 22, 8, 73.33], [185, 163, 22, 9, 2, 11], [30, 26, 4, 11, 6.17]]
        user23 = next(row for row in query_rows[9]["rows"] if row[0] == 23)
        assert user23[2:] == (0, 0)
        assert query_rows[10]["rows"][-1][2:] == (0, 0, None)
        write_log("query_results.log", query_log)
        write_log("core_query_results.log", core_log)

        _, join_log = run_file(connection, "bonus/join_sub.sql")
        write_log("join_sub_query_results.log", join_log)
        _, plan_log = run_file(connection, "bonus/index_examples.sql")
        write_log("index_query_plans.log", plan_log)

        intermediate = """SELECT u.user_id, u.name, COUNT(l.loan_id) AS loan_count,
SUM(CASE WHEN l.loan_id IS NOT NULL AND l.return_date IS NULL THEN 1 ELSE 0 END) AS active_count
FROM users u LEFT JOIN loans l ON l.user_id=u.user_id
GROUP BY u.user_id,u.name ORDER BY u.user_id"""
        cursor = connection.execute(intermediate)
        summary = cursor.fetchall()
        assert len(summary) == 30 and sum(row[2] for row in summary) == 185
        write_log("user_loan_summary.log", intermediate + ";\n"
                  + table_text([column[0] for column in cursor.description], summary) + "\n")

        write_log("integrity_results.log", check_constraints(connection))
        try:
            connection.executescript((ROOT / "bonus/wrong_fk_insert.sql").read_text(encoding="utf-8"))
        except sqlite3.IntegrityError as error:
            assert "FOREIGN KEY" in str(error)
            write_log("wrong_fk_insert.log", "Engine: Python sqlite3\n"
                      "File: bonus/wrong_fk_insert.sql\nActual error: " + str(error)
                      + "\nPASS: invalid category insertion rejected; book_id=32 was not inserted.\n")
        else:
            raise AssertionError("Invalid foreign key insertion succeeded")
        assert connection.execute("SELECT COUNT(*) FROM books WHERE book_id=32").fetchone()[0] == 0

        empty = fresh_db(with_data=False)
        try:
            empty_core, empty_log = run_file(empty, "bonus/core.sql")
            assert empty_core[0]["rows"] == [(0, 0, 0, None)]
            assert empty_core[1]["rows"] == [(0, 0, 0, 0, 0, 0)]
            assert empty_core[2]["rows"] == [(0, 0, 0, 0, None)]
            write_log("empty_database_results.log", empty_log + "PASS: no data counts are 0; undefined averages/percentages are NULL.\n")
        finally:
            empty.close()

        # 수정 전의 실제 결과를 스냅샷에 사용한다. 수정은 임시 DB에서만 실행한다.
        evidence = {"engine": "Python sqlite3", "sqlite_version": sqlite3.sqlite_version,
                    "table_counts": counts, "core": core_rows,
                    "inner_join": query_rows[4], "left_join": query_rows[7],
                    "category_counts": query_rows[8]}
        (LOGS / "evidence_results.json").write_text(
            json.dumps(evidence, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

        modified, modify_log = run_file(connection, "modify.sql")
        assert len(modified) == 2 and all(len(entry["rows"]) == 1 for entry in modified)
        assert connection.execute("SELECT COUNT(*) FROM loans").fetchone()[0] == 184
        assert connection.execute("SELECT COUNT(*) FROM loans WHERE return_date IS NULL").fetchone()[0] == 21
        repeated, repeated_log = run_file(connection, "modify.sql")
        assert all(not entry["rows"] for entry in repeated)
        write_log("modify_results.log", modify_log + "\nAfter update/delete: loans=184, active=21\n"
                  + repeated_log + "PASS: repeat execution changes zero rows.\n")
        write_log("all_query_results.log", "All 17 queries: 12 reads + 3 core metrics + 2 mutations.\n\n"
                  + query_log + core_log + modify_log
                  + "\nPASS: all 17 statements executed successfully.\n")
        print("PASS: all tables >=10 rows; 17 queries; NULL/zero handling; FK/RESTRICT/CASCADE; targeted UPDATE/DELETE.")
        print("Logs:", LOGS)
    finally:
        connection.close()


if __name__ == "__main__":
    main()
