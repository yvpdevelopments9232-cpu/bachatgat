import sqlite3
import sys
sys.stdout.reconfigure(encoding='utf-8')

con = sqlite3.connect(r'C:\Users\vikra\AppData\Roaming\BachatDatabase\bachat_offline.db')
cur = con.cursor()

tables = [t[0] for t in cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall() if not t[0].startswith('sqlite_')]
no_updated = []
for t in tables:
    cols = [c[1] for c in cur.execute(f"PRAGMA table_info('{t}')").fetchall()]
    if 'updated_at' not in cols:
        no_updated.append(t)
print("TABLES WITHOUT updated_at:", no_updated)

