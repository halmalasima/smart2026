#!/usr/bin/env python3
"""
RAG Indexing Script with retry + progress resume.
Indexes yemen_legal_dataset.sql → HuggingFace RAG Space.
Usage: python index_legal_rag.py
"""

import os
import re
import sys
import time
import json
import requests
from pathlib import Path
from typing import List, Dict

SQL_FILE    = r"f:\smart2026\yemen_legal_dataset.sql"
RAG_API_URL = "https://smartgudi-smartjudi-rag.hf.space"
ENDPOINT    = f"{RAG_API_URL}/add_documents"
PROGRESS_FILE = "rag_index_progress.json"

BATCH_SIZE   = 10   # smaller batches → fewer disconnects
MAX_RETRIES  = 5
RETRY_DELAY  = 8    # seconds between retries
TIMEOUT      = 120  # seconds per request

# ─── PARSER ──────────────────────────────────────────────────────────────────

def parse_sql_file(path: str) -> List[Dict]:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        content = f.read()

    m = re.search(r"INSERT\s+INTO\s+\w+\s*\(([^)]+)\)\s*VALUES", content, re.IGNORECASE)
    if not m:
        return []
    columns = [c.strip() for c in m.group(1).split(",")]
    values_section = content[m.end():].strip()

    # State-machine row extractor
    rows, current, depth, in_q = [], "", 0, False
    i = 0
    while i < len(values_section):
        ch = values_section[i]
        if ch == "'" and not in_q:
            in_q = True; current += ch
        elif ch == "'" and in_q:
            if i + 1 < len(values_section) and values_section[i+1] == "'":
                current += "''"; i += 1
            else:
                in_q = False; current += ch
        elif ch == "(" and not in_q:
            if depth == 0: current = "("
            else: current += ch
            depth += 1
        elif ch == ")" and not in_q:
            depth -= 1; current += ch
            if depth == 0 and current.startswith("("):
                rows.append(current.strip()); current = ""
        else:
            current += ch
        i += 1

    docs = []
    for row_str in rows:
        inner = row_str[1:-1]
        vals, buf, in_q2 = [], "", False
        for j, ch in enumerate(inner):
            if ch == "'" and not in_q2:
                in_q2 = True
            elif ch == "'" and in_q2:
                if j + 1 < len(inner) and inner[j+1] == "'":
                    buf += "'"; continue
                else:
                    in_q2 = False
            elif ch == "," and not in_q2:
                vals.append(buf.strip().strip("'")); buf = ""; continue
            else:
                buf += ch
        vals.append(buf.strip().strip("'"))
        if len(vals) == len(columns):
            docs.append(dict(zip(columns, vals)))
    return docs

# ─── CHUNKING ────────────────────────────────────────────────────────────────

def chunk_docs(docs: List[Dict], max_chars=1500) -> List[str]:
    chunks = []
    for d in docs:
        header = (
            f"المصدر: {d.get('source_title','')}\n"
            f"الكتاب: {d.get('book_title','')}\n"
            f"الباب: {d.get('chapter_title','')}\n"
            f"المادة: {d.get('article_number','')}\n\n"
        )
        body = d.get("article_text", "")
        text = header + body
        if not text.strip():
            continue
        # Simple fixed-size split — no overlap to avoid memory issues
        for i in range(0, max(1, len(text)), max_chars):
            chunk = text[i:i + max_chars]
            if chunk.strip():
                chunks.append(chunk)
    return chunks

# ─── UPLOAD ──────────────────────────────────────────────────────────────────

def upload_batch(texts: List[str]) -> bool:
    files = []
    for idx, text in enumerate(texts):
        files.append(("files", (f"doc_{idx}.txt", text.encode("utf-8"), "text/plain")))
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            r = requests.post(ENDPOINT, files=files, timeout=TIMEOUT)
            if r.status_code == 200:
                return True
            print(f"    HTTP {r.status_code} — retry {attempt}/{MAX_RETRIES}")
        except Exception as e:
            print(f"    Error: {e} — retry {attempt}/{MAX_RETRIES}")
        time.sleep(RETRY_DELAY * attempt)
    return False

# ─── PROGRESS ────────────────────────────────────────────────────────────────

def load_progress() -> int:
    if Path(PROGRESS_FILE).exists():
        try:
            return json.loads(Path(PROGRESS_FILE).read_text())["done_batches"]
        except Exception:
            pass
    return 0

def save_progress(done: int):
    Path(PROGRESS_FILE).write_text(json.dumps({"done_batches": done}))

# ─── MAIN ────────────────────────────────────────────────────────────────────

def main():
    print(f"Parsing: {SQL_FILE}")
    docs = parse_sql_file(SQL_FILE)
    print(f"  → {len(docs)} articles")

    chunks = chunk_docs(docs)
    print(f"  → {len(chunks)} chunks")

    batches = [chunks[i:i+BATCH_SIZE] for i in range(0, len(chunks), BATCH_SIZE)]
    total = len(batches)

    start_batch = load_progress()
    if start_batch:
        print(f"  Resuming from batch {start_batch + 1}/{total}")

    failed = 0
    for bi in range(start_batch, total):
        batch = batches[bi]
        ok = upload_batch(batch)
        if ok:
            save_progress(bi + 1)
            pct = (bi + 1) / total * 100
            print(f"  [{bi+1}/{total}] {pct:.1f}% ✓", end="\r")
        else:
            failed += 1
            print(f"\n  ✗ Batch {bi+1} failed after {MAX_RETRIES} retries — skipping")

    # Clear progress file on completion
    if Path(PROGRESS_FILE).exists():
        Path(PROGRESS_FILE).unlink()

    print(f"\n\n✅ Done — {total - failed}/{total} batches indexed successfully.")
    if failed:
        print(f"   ⚠ {failed} batches failed — re-run to retry from last position.")

if __name__ == "__main__":
    main()
