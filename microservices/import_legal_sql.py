#!/usr/bin/env python3
"""
Import yemen_legal_dataset.sql → legal service PostgreSQL (legal_articles table).
Handles malformed SQL (stray commas between INSERT blocks).
"""

import re
import subprocess
import sys
import argparse
from typing import List, Dict

SQL_FILE = r"d:\smart2026\yemen_legal_dataset.sql"
CONTAINER = "microservices-db-legal-1"
DB = "smartjudi_legal"
DB_USER = "smartjudi"
TABLE = "legal_articles"
COLUMNS = "(source_title, book_title, section_title, chapter_title, branch_title, article_number, article_text, created_at)"
BATCH = 200


def run_psql(sql: str) -> bool:
    cmd = ["docker", "exec", "-i", CONTAINER,
           "psql", "-U", DB_USER, "-d", DB, "--no-psqlrc", "-q"]
    result = subprocess.run(cmd, input=sql, capture_output=True,
                            text=True, encoding="utf-8", errors="replace")
    if result.returncode != 0 or "ERROR" in result.stderr:
        print(f"  psql error: {result.stderr.strip()[:200]}")
        return False
    return True


def parse_sql_file(sql_file_path: str) -> List[dict]:
    """
    State-machine parser from original load_legal_data_from_sql.py.
    Handles '' escaped quotes and nested parentheses correctly.
    Returns list of dicts: {column: value}.
    """
    with open(sql_file_path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    insert_match = re.search(
        r"INSERT\s+INTO\s+(\w+)\s*\(([^)]+)\)\s*VALUES", content, re.IGNORECASE
    )
    if not insert_match:
        return []

    columns = [c.strip() for c in insert_match.group(2).split(",")]
    values_section = content[insert_match.end():].strip()

    rows = []
    current_row = ""
    paren_depth = 0
    in_quotes = False
    i = 0
    while i < len(values_section):
        char = values_section[i]
        if char == "'" and not in_quotes:
            in_quotes = True
            current_row += char
        elif char == "'" and in_quotes:
            if i + 1 < len(values_section) and values_section[i + 1] == "'":
                current_row += "''"
                i += 1
            else:
                in_quotes = False
                current_row += char
        elif char == "(" and not in_quotes:
            if paren_depth == 0:
                current_row = "("
            else:
                current_row += char
            paren_depth += 1
        elif char == ")" and not in_quotes:
            paren_depth -= 1
            current_row += char
            if paren_depth == 0 and current_row.strip().startswith("("):
                rows.append(current_row.strip())
                current_row = ""
        else:
            current_row += char
        i += 1

    # Parse each row tuple into a dict
    docs = []
    for row_str in rows:
        inner = row_str[1:-1]  # strip ()
        values = []
        buf = ""
        in_q = False
        for j, ch in enumerate(inner):
            if ch == "'" and not in_q:
                in_q = True
            elif ch == "'" and in_q:
                if j + 1 < len(inner) and inner[j + 1] == "'":
                    buf += "'"
                    continue
                else:
                    in_q = False
            elif ch == "," and not in_q:
                values.append(buf.strip().strip("'"))
                buf = ""
                continue
            else:
                buf += ch
        values.append(buf.strip().strip("'"))

        if len(values) == len(columns):
            docs.append(dict(zip(columns, values)))
    return docs


def escape_pg(val: str) -> str:
    """Escape a string value for PostgreSQL dollar-quoting fallback via standard escaping."""
    return val.replace("'", "''")


def main():
    print(f"Reading & parsing: {SQL_FILE}")
    docs = parse_sql_file(SQL_FILE)
    print(f"Found {len(docs)} rows")

    if not docs:
        print("No rows found — exiting.")
        sys.exit(1)

    # Clear existing data
    print("Truncating existing data...")
    run_psql(f"TRUNCATE TABLE {TABLE};")

    # Insert in batches using escaped string literals
    total = 0
    cols_list = ["source_title", "book_title", "section_title",
                 "chapter_title", "branch_title", "article_number",
                 "article_text", "created_at"]
    cols_str = ", ".join(cols_list)

    for i in range(0, len(docs), BATCH):
        batch = docs[i:i + BATCH]
        value_parts = []
        for d in batch:
            row = (
                f"('{escape_pg(d.get('source_title',''))}'"
                f",'{escape_pg(d.get('book_title',''))}'"
                f",'{escape_pg(d.get('section_title',''))}'"
                f",'{escape_pg(d.get('chapter_title',''))}'"
                f",'{escape_pg(d.get('branch_title',''))}'"
                f",'{escape_pg(d.get('article_number',''))}'"
                f",'{escape_pg(d.get('article_text',''))}'"
                f",NOW())"
            )
            value_parts.append(row)

        sql = f"INSERT INTO {TABLE} ({cols_str}) VALUES\n" + ",\n".join(value_parts) + "\nON CONFLICT DO NOTHING;\n"
        ok = run_psql(sql)
        if ok:
            total += len(batch)
            print(f"  Inserted {total}/{len(docs)} rows...", end="\r")
        else:
            print(f"\n  Batch {i//BATCH + 1} failed — retrying row-by-row...")
            for row_sql in value_parts:
                s = f"INSERT INTO {TABLE} ({cols_str}) VALUES\n{row_sql}\nON CONFLICT DO NOTHING;\n"
                if run_psql(s):
                    total += 1

    run_psql(f"SELECT setval(pg_get_serial_sequence('{TABLE}', 'id'), COALESCE(MAX(id),0)+1, false) FROM {TABLE};")
    print(f"\n✅ Done — {total} rows imported into '{TABLE}'.")


if __name__ == "__main__":
    main()
