# PharmApp – ChEMBL 35 (PostgreSQL)

A ready-to-use setup to explore **ChEMBL 35** in **PostgreSQL**, with a Python environment for quick queries and downstream analysis.

This guide shows how to:

- Create the Conda environment **`pharmapp_3`** from `pharmapp_3.yml`
- Restore the database from a prebuilt dump **`chembl_35_rdkit_backup.dump`**
- Verify the installation from both **psql** and **Python**

---

## Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
  - [1) Clone this repo](#1-clone-this-repo)
  - [2) Create & activate conda env `pharmapp_3`](#2-create--activate-conda-env-pharmapp_3)
  - [3) Install & prepare PostgreSQL](#3-install--prepare-postgresql)
  - [4) Start PostgreSQL](#4-start-postgresql)
  - [5) Restore ChEMBL 35 database](#5-restore-chembl-35-database)
  - [6) Verify with psql](#6-verify-with-psql)
  - [7) Verify with Python](#7-verify-with-python)
- [Optional: convenience view & search index](#optional-convenience-view--search-index)
- [Troubleshooting](#troubleshooting)
- [Notes on RDKit](#notes-on-rdkit)
- [License](#license)

---

## Prerequisites

- **Conda / Miniconda / Anaconda** installed
- **PostgreSQL** installed (server + client tools)
  - Use a `pg_restore` **version equal or newer** than the one that created the dump
- **Windows 11** (tested) or Linux/macOS  
  Commands below show Windows first; Linux/macOS equivalents are provided where useful

**Download the database dump:**

- `chembl_35_rdkit_backup.dump` (Google Drive folder):  
  <https://drive.google.com/drive/folders/1nqBBNof4q3ywJfrpVUx6PBl0gl3VJfXi?usp=sharing>

Place the file anywhere you like (e.g. `./dump/chembl_35_rdkit_backup.dump` inside this repo).

---

## Quick Start

### 1) Clone this repo

```bash
git clone https://github.com/nghiencuuthuoc/pharmapp-chembl-35.git
cd pharmapp-chembl-35
```

### 2) Create & activate conda env `pharmapp_3`

```bash
# If the environment name is inside the YAML, this is enough:
conda env create -f pharmapp_3.yml

# If you need to force the name:
# conda env create -f pharmapp_3.yml -n pharmapp_3

conda activate pharmapp_3
```

> If `psycopg` isn’t present after activation:
> ```bash
> pip install psycopg
> ```

### 3) Install & prepare PostgreSQL

If you don’t have PostgreSQL yet:

- **Windows:** install from EnterpriseDB or Windows Package Manager. Ensure `psql`, `pg_ctl`, and `pg_restore` are in your PATH.
- **Linux (example Ubuntu):**
  ```bash
  sudo apt-get update
  sudo apt-get install postgresql postgresql-client
  ```
- **macOS (Homebrew):**
  ```bash
  brew install postgresql
  ```

Create a data directory and initialize a cluster (choose a path you control):

**Windows (PowerShell/CMD):**
```bat
set PGDATA=C:\pgdata
mkdir %PGDATA%
initdb -D "%PGDATA%"
```

**Linux/macOS:**
```bash
export PGDATA=$HOME/pgdata
mkdir -p "$PGDATA"
initdb -D "$PGDATA"
```

> By default, the OS user who ran `initdb` becomes the initial **superuser** for this cluster (often your Windows username). You can use that user for all steps below. Creating an extra `postgres` role is optional.

### 4) Start PostgreSQL

**Windows:**
```bat
pg_ctl -D "%PGDATA%" -l "%PGDATA%\logfile" start
```

**Linux/macOS:**
```bash
pg_ctl -D "$PGDATA" -l "$PGDATA/logfile" start
```

Check it’s listening on port 5432:
```bat
REM Windows
netstat -ano | findstr 5432
```
```bash
# Linux/macOS
ss -ltnp | grep 5432 || lsof -i :5432
```

### 5) Restore ChEMBL 35 database

Create an empty database and restore the dump you downloaded.

**Create database (psql):**
```bat
psql -h localhost -p 5432 -U <YOUR_OS_USER> -d postgres -c "CREATE DATABASE chembl_35 OWNER <YOUR_OS_USER>;"
```

**Restore (pg_restore):**
```bat
pg_restore -h localhost -p 5432 -U <YOUR_OS_USER> -d chembl_35 --no-owner --no-privileges "PATH\TO\chembl_35_rdkit_backup.dump"
```

- Replace `<YOUR_OS_USER>` with your actual superuser (the Windows/Linux/macOS account used for `initdb`), or use another superuser you created.
- `--no-owner --no-privileges` avoids permission mismatches from the source system.

> If `pg_restore -l PATH\TO\dump` prints a list of objects, the dump is a valid archive.  
> If it says “not a valid archive”, the file is likely a plain SQL script — then use:
> ```bat
> psql -h localhost -U <YOUR_OS_USER> -d chembl_35 -f "PATH\TO\chembl_35_rdkit_backup.dump"
> ```

### 6) Verify with psql

```bat
psql -h localhost -U <YOUR_OS_USER> -d chembl_35 -c "SELECT current_user, current_database();"
psql -h localhost -U <YOUR_OS_USER> -d chembl_35 -c "\dt"
psql -h localhost -U <YOUR_OS_USER> -d chembl_35 -c "SELECT COUNT(*) AS molecules FROM molecule_dictionary;"
psql -h localhost -U <YOUR_OS_USER> -d chembl_35 -c "SELECT COUNT(*) AS assays FROM assays;"
psql -h localhost -U <YOUR_OS_USER> -d chembl_35 -c "SELECT COUNT(*) AS activities FROM activities;"
```

(You should see ~79 tables including `molecule_dictionary`, `assays`, `activities`, etc.)

Optional post-restore optimize:
```bat
psql -h localhost -U <YOUR_OS_USER> -d chembl_35 -c "VACUUM ANALYZE;"
```

### 7) Verify with Python

Create `test_connection.py`:

```python
import psycopg

conn = psycopg.connect("host=localhost dbname=chembl_35 user=<YOUR_OS_USER>")
with conn.cursor() as cur:
    cur.execute("SELECT chembl_id, pref_name FROM molecule_dictionary ORDER BY chembl_id LIMIT 5;")
    rows = cur.fetchall()
    for r in rows:
        print(r)
```

Run:
```bat
python test_connection.py
```

You should see a few `('CHEMBLxxxxxxx', 'Name or None')` rows printed.

---

## Optional: convenience view & search index

Many ChEMBL entries don’t have `pref_name`. Use synonyms as a fallback display name:

```sql
-- Create a view that chooses pref_name if present, otherwise a preferred synonym
CREATE OR REPLACE VIEW v_molecule_display_name AS
WITH ranked AS (
  SELECT
    md.chembl_id,
    md.pref_name,
    ms.synonyms,
    ms.syn_type,
    ROW_NUMBER() OVER (
      PARTITION BY md.chembl_id
      ORDER BY CASE ms.syn_type
        WHEN 'INN' THEN 1
        WHEN 'BAN' THEN 2
        WHEN 'USAN' THEN 3
        WHEN 'TRADE_NAME' THEN 4
        WHEN 'SYNONYMS' THEN 5
        ELSE 6
      END, LENGTH(ms.synonyms)
    ) AS rnk
  FROM molecule_dictionary md
  LEFT JOIN molecule_synonyms ms USING (chembl_id)
)
SELECT
  chembl_id,
  COALESCE(NULLIF(pref_name,''), synonyms) AS display_name
FROM ranked
WHERE rnk = 1;
```

Optional fuzzy search acceleration (PostgreSQL `pg_trgm`):
```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_vmol_display_trgm
  ON v_molecule_display_name USING gin (display_name gin_trgm_ops);
```

Example:
```sql
SELECT * FROM v_molecule_display_name WHERE display_name ILIKE '%ibuprofen%';
```

---

## Troubleshooting

- **`FATAL: role "postgres" does not exist`**  
  Your cluster was initialized without a `postgres` role (common on Windows). Log in as the OS init user and either:
  - Use that user as owner everywhere, or
  - Create the role:
    ```sql
    CREATE ROLE postgres WITH LOGIN SUPERUSER PASSWORD 'YourStrong!Pass';
    ```

- **`FATAL: database "<user>" does not exist`**  
  `psql -U <user>` defaults to DB `<user>`. Specify a DB explicitly, e.g. `-d postgres` or `-d chembl_35`.

- **Windows `psql` shows `GSSAPI` or code page warnings**  
  - Disable GSS encryption when connecting:
    ```bat
    psql ... --no-gssenc
    ```
  - Switch console to UTF-8 to avoid code page warnings:
    ```bat
    chcp 65001
    ```

- **`pg_restore: error: not a valid archive`**  
  The file is plain SQL. Use `psql -f` instead of `pg_restore`.

- **Permissions / ownership errors during restore**  
  Add `--no-owner --no-privileges` to `pg_restore`, create DB as your superuser.

- **`pg_restore` version mismatch**  
  Use a `pg_restore` **>=** the server version used to create the dump.

---

## Notes on RDKit

- The provided dump name includes `rdkit`, but the schema may not require the PostgreSQL RDKit extension.  
- If you need chemical operators/types inside PostgreSQL, you must install the RDKit extension built for your PostgreSQL version (Windows builds can be tricky).  
- You can always process molecules with **RDKit (Python)** outside the DB regardless of the DB extension.

---

## License

This repository is for research and educational purposes. See `LICENSE` if provided in the repo. ChEMBL is provided by the ChEMBL group at EMBL-EBI under their respective terms.

---

### Appendix: One-shot Windows script (optional)

Create `scripts\restore_chembl35.bat` and edit the paths/user:

```bat
@echo off
setlocal

REM ==== EDIT THESE ====
set PGDATA=C:\pgdata
set DUMP=C:\path\to\chembl_35_rdkit_backup.dump
set PGUSER=%USERNAME%
set PGPORT=5432
REM ====================

chcp 65001 >nul

REM Start server (no-op if already running)
pg_ctl -D "%PGDATA%" -l "%PGDATA%\logfile" start
ping 127.0.0.1 -n 3 >nul

REM Create DB and restore
psql -h localhost -p %PGPORT% -U %PGUSER% -d postgres -c "DROP DATABASE IF EXISTS chembl_35;"
psql -h localhost -p %PGPORT% -U %PGUSER% -d postgres -c "CREATE DATABASE chembl_35 OWNER "%PGUSER%";"

pg_restore -h localhost -p %PGPORT% -U %PGUSER% -d chembl_35 --no-owner --no-privileges "%DUMP%"

REM Smoke tests
psql -h localhost -p %PGPORT% -U %PGUSER% -d chembl_35 -c "SELECT COUNT(*) AS molecules FROM molecule_dictionary;"
psql -h localhost -p %PGPORT% -U %PGUSER% -d chembl_35 -c "VACUUM ANALYZE;"

echo Done.
endlocal
pause
```
