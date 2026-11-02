"""Render exact column types, keys and constraints from a migrated MariaDB."""
import os
from pathlib import Path
import pymysql

ROOT = Path(__file__).resolve().parents[1]


def escape(value):
    return str(value).replace('|', '\\|').replace('\n', ' ')


def main():
    sql = pymysql.connect(host=os.getenv('MARIADB_HOST', '127.0.0.1'), port=int(os.getenv('MARIADB_PORT', '3306')),
                          user=os.environ['MARIADB_MIGRATION_USER'], password=os.environ['MARIADB_MIGRATION_PASSWORD'],
                          charset='utf8mb4', cursorclass=pymysql.cursors.DictCursor)
    lines = ['# 데이터 사전', '', 'Alembic `0001_initial`을 적용한 실제 INFORMATION_SCHEMA에서 생성했습니다.',
             '`python scripts/data_dictionary.py`로 재생성합니다. 비밀번호와 실제 사용자 데이터는 조회하지 않습니다.', '',
             '공통: ID는 BIGINT, 크레딧은 정수, DATETIME(6)은 UTC입니다. API 이벤트의 참조 ID는 문자열입니다.',
             'NULL은 미제공/미확정을 뜻하며 무료(0)와 구별합니다. FK는 기본 RESTRICT로 이력 연쇄 삭제를 막습니다.', '']
    try:
        with sql.cursor() as c:
            for schema in ('culturepick', 'culturepick_analytics'):
                c.execute('SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA=%s AND TABLE_NAME<>%s ORDER BY TABLE_NAME', (schema, 'alembic_version'))
                for table in c.fetchall():
                    name = table['TABLE_NAME']
                    lines += [f'## {schema}.{name}', '', '| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |', '|---|---|---|---|---|']
                    c.execute('SELECT COLUMN_NAME,COLUMN_TYPE,IS_NULLABLE,COLUMN_DEFAULT,COLUMN_KEY,EXTRA FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=%s AND TABLE_NAME=%s ORDER BY ORDINAL_POSITION', (schema, name))
                    for col in c.fetchall():
                        lines.append('| ' + ' | '.join(escape(col[k]) for k in ('COLUMN_NAME', 'COLUMN_TYPE', 'IS_NULLABLE', 'COLUMN_DEFAULT')) + ' | ' + escape(col['COLUMN_KEY'] + ' ' + col['EXTRA']) + ' |')
                    c.execute(f'SHOW CREATE TABLE `{schema}`.`{name}`')
                    ddl = c.fetchone()['Create Table']
                    constraints = [line.strip().rstrip(',') for line in ddl.splitlines() if any(word in line for word in ('CONSTRAINT ', 'PRIMARY KEY ', 'UNIQUE KEY ', 'KEY `'))]
                    lines += ['', '제약·인덱스:', '', '```sql', *constraints, '```', '']
    finally:
        sql.close()
    (ROOT / 'docs/data-dictionary.md').write_text('\n'.join(lines), encoding='utf-8', newline='\n')


if __name__ == '__main__':
    main()
