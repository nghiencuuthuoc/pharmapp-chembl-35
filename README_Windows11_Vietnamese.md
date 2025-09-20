# PharmApp – ChEMBL 35 trên **Windows 11** (Hướng dẫn nhanh – Tiếng Việt)

Tài liệu này hướng dẫn bạn cài đặt **PostgreSQL**, khôi phục cơ sở dữ liệu **ChEMBL 35** từ file dump
**`chembl_35_rdkit_backup.dump`**, và kiểm tra kết nối bằng **psql** và **Python** với môi trường Conda **`pharmapp_3`** (tạo từ `pharmapp_3.yml`).

---

## Bạn sẽ thiết lập những gì

- PostgreSQL chạy cục bộ trên cổng **5432**.
- Cơ sở dữ liệu **`chembl_35`** khôi phục từ dump **`chembl_35_rdkit_backup.dump`**.
- Môi trường Python **`pharmapp_3`** để truy vấn thử dữ liệu.

> **Tải dump** từ Google Drive:  
> https://drive.google.com/drive/folders/1nqBBNof4q3ywJfrpVUx6PBl0gl3VJfXi?usp=sharing

---

## Đường dẫn mẫu dùng trong hướng dẫn (bạn có thể thay đổi)

- **PGDATA**: `E:\PharmAppDev\pgdata`
- **File dump**: `E:\DrugDev\NCT-App\CheMBL-35\dump\chembl_35_rdkit_backup.dump`
- **Tên DB**: `chembl_35`
- **Chủ sở hữu DB**: user Windows của bạn (ví dụ: `NCT`)

> Nếu tên user Windows có **khoảng trắng**, hãy luôn đặt trong dấu ngoặc kép khi dùng trong SQL, ví dụ: `ALTER ROLE "John Doe" ...`.

---

## 0) Yêu cầu trước (Windows 11)

- Cài **Conda** (Anaconda / Miniconda).
- Cài **PostgreSQL** (bao gồm `psql`, `pg_ctl`, `pg_restore`).  
  Thêm thư mục `bin` của PostgreSQL vào **PATH** để gọi được các lệnh trên từ mọi cửa sổ dòng lệnh.

> Mẹo: Mở **PowerShell** mới sau khi cài PostgreSQL để PATH có hiệu lực.

---

## 1) Tạo & kích hoạt môi trường Conda `pharmapp_3`

Trong thư mục có file `pharmapp_3.yml`:
```bat
conda env create -f pharmapp_3.yml -n pharmapp_3
conda activate pharmapp_3
```

Nếu sau khi kích hoạt chưa có `psycopg`:
```bat
pip install psycopg
```

---

## 2) Khởi tạo cluster PostgreSQL (thư mục dữ liệu)

Mở **PowerShell** (quyền Admin nếu cần ghi vào ổ đích):

```bat
REM Tạo thư mục dữ liệu
mkdir E:\PharmAppDev\pgdata

REM Khởi tạo cluster (user Windows chạy lệnh sẽ trở thành superuser của DB)
initdb -D "E:\PharmAppDev\pgdata"
```

> Nếu `initdb` không tìm thấy, hãy đảm bảo PostgreSQL `bin` có trong PATH,
> hoặc gọi bằng đường dẫn đầy đủ (ví dụ: `"C:\Program Files\PostgreSQL\17\bin\initdb"`).

---

## 3) Khởi động PostgreSQL

```bat
pg_ctl -D "E:\PharmAppDev\pgdata" -l "E:\PharmAppDev\pgdata\logfile" start

REM Tuỳ chọn: kiểm tra đang lắng nghe cổng 5432
netstat -ano | findstr 5432
```

Nếu đang chạy, bạn sẽ thấy `LISTENING` tại `127.0.0.1:5432` và `[::1]:5432`.

---

## 4) Tạo cơ sở dữ liệu

Kết nối bằng user Windows (được tạo superuser ở bước `initdb`). Thay `NCT` bằng tài khoản của bạn nếu khác:

```bat
psql -h localhost -U NCT -d postgres -c "CREATE DATABASE chembl_35 OWNER \"NCT\";"
```

> Nếu bạn muốn tạo riêng role `postgres`, có thể tạo sau trong `psql`:
> ```sql
> CREATE ROLE postgres WITH LOGIN SUPERUSER PASSWORD 'YourStrong!Pass';
> ```

---

## 5) Khôi phục **ChEMBL 35** từ file dump

Đảm bảo file dump có sẵn tại:
```
E:\DrugDev\NCT-App\CheMBL-35\dump\chembl_35_rdkit_backup.dump
```

Khôi phục bằng `pg_restore`:
```bat
pg_restore -h localhost -U NCT -d chembl_35 --no-owner --no-privileges "E:\DrugDev\NCT-App\CheMBL-35\dump\chembl_35_rdkit_backup.dump"
```

> *Kiểm tra nhanh:* `pg_restore -l "E:\...\chembl_35_rdkit_backup.dump"` nên in ra danh sách đối tượng trong archive.  
> Nếu báo “not a valid archive”, file là **SQL thuần** → dùng `psql -f`:
> ```bat
> psql -h localhost -U NCT -d chembl_35 -f "E:\DrugDev\NCT-App\CheMBL-35\dump\chembl_35_rdkit_backup.dump"
> ```

---

## 6) Kiểm tra bằng **psql**

```bat
REM Đổi sang UTF-8 để tránh cảnh báo code page
chcp 65001

psql -h localhost -U NCT -d chembl_35 -c "SELECT current_user, current_database();"
psql -h localhost -U NCT -d chembl_35 -c "\dt"
psql -h localhost -U NCT -d chembl_35 -c "SELECT COUNT(*) AS molecules FROM molecule_dictionary;"
psql -h localhost -U NCT -d chembl_35 -c "SELECT COUNT(*) AS assays FROM assays;"
psql -h localhost -U NCT -d chembl_35 -c "SELECT COUNT(*) AS activities FROM activities;"
psql -h localhost -U NCT -d chembl_35 -c "VACUUM ANALYZE;"
```

Bạn sẽ thấy khoảng **79 bảng** và số lượng bản ghi khác 0 ở các bảng chính.

> Nếu gặp cảnh báo `GSSAPI`, hãy thêm `--no-gssenc` vào lệnh `psql`:
> ```bat
> psql -h localhost -U NCT -d chembl_35 --no-gssenc -c "SELECT 1;"
> ```

---

## 7) Kiểm tra bằng **Python**

Tạo file `test_connection.py` (ở bất kỳ thư mục nào):

```python
import psycopg

conn = psycopg.connect("host=localhost dbname=chembl_35 user=NCT")
with conn.cursor() as cur:
    cur.execute("SELECT chembl_id, pref_name FROM molecule_dictionary ORDER BY chembl_id LIMIT 5;")
    for row in cur.fetchall():
        print(row)
```

Chạy:
```bat
python test_connection.py
```

Kỳ vọng: in ra khoảng 5 dòng dạng `('CHEMBL4760153', None)` hoặc có tên nếu hiện diện.

---

## Khắc phục sự cố (Windows 11)

- **`FATAL: role "postgres" does not exist`**  
  Cluster được khởi tạo **không có** role `postgres` (bình thường trên Windows).
  Bạn có thể dùng luôn user Windows (ví dụ `NCT`) làm owner DB (khuyến nghị), hoặc tạo role `postgres`:
  ```sql
  CREATE ROLE postgres WITH LOGIN SUPERUSER PASSWORD 'YourStrong!Pass';
  ```

- **`FATAL: database "<user>" does not exist`**  
  `psql -U <user>` mặc định kết nối vào DB tên `<user>`. Hãy chỉ rõ `-d postgres` hoặc `-d chembl_35`.

- **GSSAPI / Code page warnings**  
  Dùng `--no-gssenc` cho `psql` và `chcp 65001` để chuyển console sang UTF-8.

- **`pg_restore: not a valid archive`**  
  File dump là SQL thuần. Hãy dùng `psql -f` thay vì `pg_restore`.

- **Lỗi quyền/owner khi restore**  
  Giữ tuỳ chọn `--no-owner --no-privileges` khi `pg_restore`, và đảm bảo bạn tạo DB với superuser hiện tại.

- **Xem log server**  
  Mở file `E:\PharmAppDev\pgdata\logfile` để xem chi tiết quá trình khởi động/khôi phục.

- **Dừng server**  
  ```bat
  pg_ctl -D "E:\PharmAppDev\pgdata" stop
  ```

---

## Tuỳ chọn: script BAT khôi phục một lần (chỉnh sửa đường dẫn/user)

Tạo file `restore_chembl35.bat`:

```bat
@echo off
setlocal

REM === CHỈNH CÁC DÒNG NÀY CHO PHÙ HỢP ===
set PGDATA=E:\PharmAppDev\pgdata
set DUMP=E:\DrugDev\NCT-App\CheMBL-35\dump\chembl_35_rdkit_backup.dump
set PGUSER=NCT
set PGPORT=5432
REM =====================================

chcp 65001 >nul

pg_ctl -D "%PGDATA%" -l "%PGDATA%\logfile" start
ping 127.0.0.1 -n 3 >nul

psql -h localhost -p %PGPORT% -U %PGUSER% -d postgres -c "DROP DATABASE IF EXISTS chembl_35;"
psql -h localhost -p %PGPORT% -U %PGUSER% -d postgres -c "CREATE DATABASE chembl_35 OWNER \"%PGUSER%\";"

pg_restore -h localhost -p %PGPORT% -U %PGUSER% -d chembl_35 --no-owner --no-privileges "%DUMP%"

psql -h localhost -p %PGPORT% -U %PGUSER% -d chembl_35 -c "SELECT COUNT(*) AS molecules FROM molecule_dictionary;"
psql -h localhost -p %PGPORT% -U %PGUSER% -d chembl_35 -c "VACUUM ANALYZE;"

echo Hoan tat.
endlocal
pause
```

Bạn đã có một quy trình tái lập: cài Conda env, khởi tạo PostgreSQL, khôi phục DB, và kiểm tra bằng psql/Python trên Windows 11.
