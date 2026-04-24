#!/usr/bin/env python3
"""
Data Migration Script: Monolith SQLite → Microservices PostgreSQL
Source : E:\\smartjudi2\\smartju\\db.sqlite3
Target : Each microservice PostgreSQL DB via docker exec psql
Usage  : python migrate_data.py [--service auth|cases|hearings|documents|legal|notifications|search|all]
"""

import sqlite3
import subprocess
import sys
import io
import csv
import argparse
import traceback
from typing import List, Tuple, Dict

# ─── CONFIG ──────────────────────────────────────────────────────────────────

SQLITE_PATH = r"E:\smartjudi2\smartju\db.sqlite3"
DB_USER = "smartjudi"
DB_PASSWORD = "smartjudi_secret"  # override with --password if needed

SERVICES: Dict[str, Tuple[str, str]] = {
    "auth":          ("microservices-db-auth-1",          "smartjudi_auth"),
    "cases":         ("microservices-db-cases-1",         "smartjudi_cases"),
    "hearings":      ("microservices-db-hearings-1",      "smartjudi_hearings"),
    "documents":     ("microservices-db-documents-1",     "smartjudi_documents"),
    "legal":         ("microservices-db-legal-1",         "smartjudi_legal"),
    "notifications": ("microservices-db-notifications-1", "smartjudi_notifications"),
    "search":        ("microservices-db-search-1",        "smartjudi_search"),
}

# Tables to skip (managed by Django internals or not needed)
SKIP_TABLES = {
    "django_migrations", "django_content_type", "django_session",
    "django_admin_log", "authtoken_token", "token_blacklist_blacklistedtoken",
    "token_blacklist_outstandingtoken", "dashboard_subscriptionplan",
    "dashboard_usersubscription",
}

# Mapping: sqlite_table → (service_key, postgres_table)
# Django FK columns are already stored as {field}_id in SQLite — no rename needed.
TABLE_MAP: Dict[str, Tuple[str, str]] = {
    # ── AUTH ──────────────────────────────────────────────────────────────────
    "auth_permission":              ("auth", "auth_permission"),
    "auth_group":                   ("auth", "auth_group"),
    "auth_group_permissions":       ("auth", "auth_group_permissions"),
    "auth_user":                    ("auth", "auth_user"),
    "auth_user_groups":             ("auth", "auth_user_groups"),
    "auth_user_user_permissions":   ("auth", "auth_user_user_permissions"),
    "accounts_userprofile":         ("auth", "accounts_userprofile"),

    # ── CASES ─────────────────────────────────────────────────────────────────
    "lawsuits_lawsuit":             ("cases", "lawsuits_lawsuit"),
    "lawsuits_casefileitem":        ("cases", "lawsuits_casefileitem"),
    "audit_auditlog":               ("cases", "audit_auditlog"),
    "appeals_appeal":               ("cases", "appeals_appeal"),
    "responses_response":           ("cases", "responses_response"),
    "judgments_judgment":           ("cases", "judgments_judgment"),
    "payments_paymentorder":        ("cases", "payments_paymentorder"),
    "parties_caseeparty":           ("cases", "parties_caseeparty"),
    "parties_party":                ("cases", "parties_party"),

    # ── HEARINGS ──────────────────────────────────────────────────────────────
    "hearings_hearing":             ("hearings", "hearings_hearing"),

    # ── DOCUMENTS ─────────────────────────────────────────────────────────────
    "attachments_attachment":       ("documents", "attachments_attachment"),

    # ── LEGAL ─────────────────────────────────────────────────────────────────
    "courts_governorate":           ("legal", "courts_governorate"),
    "courts_district":              ("legal", "courts_district"),
    "courts_courttype":             ("legal", "courts_courttype"),
    "courts_courtspecialization":   ("legal", "courts_courtspecialization"),
    "courts_court":                 ("legal", "courts_court"),
    "laws_legalcategory":           ("legal", "laws_legalcategory"),
    "laws_law":                     ("legal", "laws_law"),
    "laws_lawchapter":              ("legal", "laws_lawchapter"),
    "laws_lawsection":              ("legal", "laws_lawsection"),
    "laws_lawarticle":              ("legal", "laws_lawarticle"),
    "laws_caselegalreference":      ("legal", "laws_caselegalreference"),
    "laws_legalarticleflat":        ("legal", "laws_legalarticleflat"),
    "laws_legalprocedurenode":      ("legal", "laws_legalprocedurenode"),
    "lawyers_lawyer":               ("legal", "lawyers_lawyer"),
    "lawyers_lawyerfilteroptions":  ("legal", "lawyers_lawyerfilteroptions"),

    # ── NOTIFICATIONS ─────────────────────────────────────────────────────────
    # App renamed: notifications → notifications_app (table prefix changes)
    "notifications_notification":   ("notifications", "notifications_app_notification"),
    "messaging_message":            ("notifications", "messaging_message"),

    # ── SEARCH ────────────────────────────────────────────────────────────────
    # App renamed: logs → search_app (table prefix changes)
    "logs_usersession":             ("search", "search_app_usersession"),
    "logs_searchlog":               ("search", "search_app_searchlog"),
    "logs_aichatlog":               ("search", "search_app_aichatlog"),
}

# Migration order to respect FK dependencies within each service
SERVICE_ORDER = ["auth", "legal", "cases", "hearings", "documents", "notifications", "search"]


# ─── HELPERS ─────────────────────────────────────────────────────────────────

def sqlite_tables(conn: sqlite3.Connection) -> List[str]:
    cur = conn.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
    return [r[0] for r in cur.fetchall()]


def sqlite_columns(conn: sqlite3.Connection, table: str) -> List[str]:
    cur = conn.execute(f"PRAGMA table_info({table})")
    return [r[1] for r in cur.fetchall()]


def sqlite_rows(conn: sqlite3.Connection, table: str) -> List[tuple]:
    cur = conn.execute(f"SELECT * FROM {table}")
    return cur.fetchall()


def run_psql(container: str, db: str, sql: str, stdin_data: str = None) -> bool:
    cmd = ["docker", "exec", "-i", container,
           "psql", "-U", DB_USER, "-d", db, "--no-psqlrc", "-q"]
    result = subprocess.run(
        cmd,
        input=stdin_data or sql,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode != 0:
        print(f"    ✗ psql error: {result.stderr.strip()[:300]}")
        return False
    return True


def pg_table_columns(container: str, db: str, table: str) -> List[str]:
    """Get actual column names from the Postgres table."""
    cmd = ["docker", "exec", "-i", container,
           "psql", "-U", DB_USER, "-d", db, "--no-psqlrc", "-t", "-A",
           "-c", f"SELECT column_name FROM information_schema.columns "
                 f"WHERE table_name='{table}' ORDER BY ordinal_position"]
    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    cols = [r.strip() for r in result.stdout.splitlines() if r.strip()]
    return cols


def rows_to_csv(rows: List[tuple], null_placeholder: str = "\\N") -> str:
    buf = io.StringIO()
    writer = csv.writer(buf, quoting=csv.QUOTE_MINIMAL)
    for row in rows:
        writer.writerow(["" if v is None else v for v in row])
    return buf.getvalue()


def reset_sequence(container: str, db: str, table: str) -> None:
    sql = (
        f"SELECT setval(pg_get_serial_sequence('{table}', 'id'), "
        f"COALESCE(MAX(id), 0) + 1, false) FROM {table};"
    )
    run_psql(container, db, sql)


def migrate_table(
    conn: sqlite3.Connection,
    sqlite_table: str,
    service: str,
    pg_table: str,
    pg_columns_filter: bool = True,
) -> int:
    container, db = SERVICES[service]

    # Get SQLite columns and rows
    sqlite_cols = sqlite_columns(conn, sqlite_table)
    rows = sqlite_rows(conn, sqlite_table)
    if not rows:
        print(f"    (empty — skipped)")
        return 0

    # Get actual Postgres columns to align (handles added/removed fields)
    pg_cols = pg_table_columns(container, db, pg_table)
    if not pg_cols:
        print(f"    ✗ Table '{pg_table}' not found in Postgres — skipping")
        return 0

    # Intersect: only columns present in BOTH SQLite and Postgres
    common_cols = [c for c in sqlite_cols if c in pg_cols]
    if not common_cols:
        print(f"    ✗ No common columns — skipping")
        return 0

    # Build index map for SQLite row values
    col_idx = {c: i for i, c in enumerate(sqlite_cols)}
    selected_rows = [tuple(row[col_idx[c]] for c in common_cols) for row in rows]

    # Truncate destination table first
    run_psql(container, db, f"TRUNCATE TABLE {pg_table} CASCADE;")

    # COPY via CSV stdin
    csv_data = rows_to_csv(selected_rows)
    cols_str = ", ".join(common_cols)
    copy_sql = f"COPY {pg_table} ({cols_str}) FROM STDIN WITH (FORMAT csv, NULL '');\n"
    stdin = copy_sql + csv_data

    ok = run_psql(container, db, "", stdin_data=stdin)
    if ok:
        # Reset PK sequence if 'id' column exists
        if "id" in common_cols:
            reset_sequence(container, db, pg_table)
        return len(selected_rows)
    return 0


# ─── MAIN ────────────────────────────────────────────────────────────────────

def migrate_service(conn: sqlite3.Connection, target_service: str) -> None:
    container, db = SERVICES[target_service]
    print(f"\n{'='*60}")
    print(f"  Service: {target_service}  →  container: {container}")
    print(f"{'='*60}")

    tables_in_sqlite = set(sqlite_tables(conn))
    total_rows = 0

    for sqlite_tbl, (svc, pg_tbl) in TABLE_MAP.items():
        if svc != target_service:
            continue
        if sqlite_tbl in SKIP_TABLES:
            continue
        if sqlite_tbl not in tables_in_sqlite:
            print(f"  [SKIP ] {sqlite_tbl} (not in SQLite)")
            continue

        print(f"  [COPY ] {sqlite_tbl} → {pg_tbl} ... ", end="", flush=True)
        try:
            count = migrate_table(conn, sqlite_tbl, target_service, pg_tbl)
            print(f"{count} rows ✓")
            total_rows += count
        except Exception as e:
            print(f"ERROR: {e}")
            traceback.print_exc()

    print(f"\n  Total rows migrated: {total_rows}")


def main():
    parser = argparse.ArgumentParser(description="Migrate monolith SQLite → microservices PostgreSQL")
    parser.add_argument("--service", default="all",
                        choices=list(SERVICES.keys()) + ["all"],
                        help="Which service to migrate (default: all)")
    parser.add_argument("--sqlite", default=SQLITE_PATH,
                        help="Path to SQLite DB file")
    parser.add_argument("--password", default=DB_PASSWORD,
                        help="PostgreSQL password")
    args = parser.parse_args()

    print(f"Opening SQLite: {args.sqlite}")
    try:
        conn = sqlite3.connect(args.sqlite)
        conn.row_factory = None
    except Exception as e:
        print(f"Cannot open SQLite: {e}")
        sys.exit(1)

    targets = SERVICE_ORDER if args.service == "all" else [args.service]

    for svc in targets:
        migrate_service(conn, svc)

    conn.close()
    print("\n✅ Migration complete.")


if __name__ == "__main__":
    main()
