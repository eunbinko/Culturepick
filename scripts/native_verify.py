"""Windows-only disposable live verification when Docker is unavailable.

Usage: python scripts/native_verify.py --mariadb-bin <bin> --mongodb-bin <bin>
Official binaries must already exist. Services bind loopback and are stopped in finally.
"""
import argparse
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from scripts.render_schema import statements


def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]


def wait_until_ready(connect, process):
    for _ in range(120):
        if process.poll() is not None:
            raise RuntimeError('Test database exited. Inspect its log in .artifacts.')
        try:
            connection = connect()
            connection.close()
            return
        except Exception:
            time.sleep(0.5)
    raise RuntimeError('Test database readiness timeout')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mariadb-bin', required=True, type=Path)
    parser.add_argument('--mongodb-bin', required=True, type=Path)
    args = parser.parse_args()
    import pymysql
    from pymongo import MongoClient
    work = ROOT / '.artifacts'
    work.mkdir(exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix='live-db-', dir=work))
    maria_data, mongo_data = run / 'maria', run / 'mongo'
    mongo_data.mkdir()
    maria_port, mongo_port = free_port(), free_port()
    processes, logs = [], []
    env = os.environ.copy()
    env.update(MARIADB_HOST='127.0.0.1', MARIADB_PORT=str(maria_port), MARIADB_MIGRATION_USER='root',
               MARIADB_MIGRATION_PASSWORD='', TEST_MARIADB_PORT=str(maria_port),
               TEST_MONGODB_URI=f'mongodb://127.0.0.1:{mongo_port}/')
    try:
        subprocess.run([str(args.mariadb_bin / 'mariadb-install-db.exe'), f'--datadir={maria_data}'],
                       check=True, capture_output=True, timeout=120)
        commands = [
            [str(args.mariadb_bin / 'mariadbd.exe'), '--no-defaults', f'--datadir={maria_data}',
             f'--basedir={args.mariadb_bin.parent}', f'--port={maria_port}', '--bind-address=127.0.0.1', '--console'],
            [str(args.mongodb_bin / 'mongod.exe'), f'--dbpath={mongo_data}', f'--port={mongo_port}',
             '--bind_ip=127.0.0.1', '--wiredTigerCacheSizeGB=0.25'],
        ]
        for number, command in enumerate(commands):
            log = (run / f'server-{number}.log').open('wb')
            logs.append(log)
            processes.append(subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT,
                                             creationflags=subprocess.CREATE_NO_WINDOW))
        sql_connect = lambda: pymysql.connect(host='127.0.0.1', port=maria_port, user='root', autocommit=True, charset='utf8mb4')
        wait_until_ready(sql_connect, processes[0])
        def mongo_connect():
            client = MongoClient(env['TEST_MONGODB_URI'], serverSelectionTimeoutMS=500)
            client.admin.command('ping')
            return client
        wait_until_ready(mongo_connect, processes[1])
        with sql_connect() as sql, sql.cursor() as c:
            c.execute('CREATE DATABASE culturepick CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci')
        # Prove live tests detect absence of the schema before migration.
        red = subprocess.run([sys.executable, '-m', 'pytest', 'tests/test_database.py::test_required_tables', '-q'],
                             cwd=ROOT, env=env, capture_output=True, text=True)
        if red.returncode == 0:
            raise RuntimeError('Pre-migration test unexpectedly passed')
        (run / 'before-migration.txt').write_text(red.stdout + red.stderr, encoding='utf-8')
        subprocess.run([sys.executable, '-m', 'alembic', 'upgrade', 'head'], cwd=ROOT, env=env, check=True)
        with sql_connect() as sql, sql.cursor() as c:
            for statement in statements((ROOT / 'database/mariadb/seed.sql').read_text(encoding='utf-8')):
                c.execute(statement)
            for user in ('app', 'collector', 'dispatcher', 'analytics', 'backup'):
                password = secrets.token_urlsafe(24)
                c.execute(f"CREATE USER '{user}_user'@'%%' IDENTIFIED BY %s", (password,))
                env[f'TEST_{user.upper()}_PASSWORD'] = password
            for statement in statements((ROOT / 'database/mariadb/permissions.sql').read_text(encoding='utf-8')):
                c.execute(statement)
        client = mongo_connect()
        event_db = client.culturepick_events
        validator = json.loads((ROOT / 'database/mongodb/event_schema.json').read_text(encoding='utf-8'))
        event_db.create_collection('raw_events', validator=validator, validationLevel='strict', validationAction='error')
        event_db.raw_events.create_index('event_id', unique=True, name='uq_event_id')
        client.close()
        subprocess.run([sys.executable, 'scripts/data_dictionary.py'], cwd=ROOT, env=env, check=True)
        result = subprocess.run([sys.executable, '-m', 'pytest', '-q'], cwd=ROOT, env=env,
                                capture_output=True, text=True)
        print(result.stdout)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
        (run / 'pytest.txt').write_text(result.stdout + result.stderr, encoding='utf-8')
        print(f'Live verification evidence: {run.relative_to(ROOT)}')
        raise SystemExit(result.returncode)
    finally:
        for process in reversed(processes):
            process.terminate()
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=10)
        for log in logs:
            log.close()


if __name__ == '__main__':
    main()
