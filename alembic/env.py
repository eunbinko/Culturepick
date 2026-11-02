"""Migration credentials are read from the environment, never from Git."""
import os
from alembic import context
from sqlalchemy import create_engine
from sqlalchemy.engine import URL

url = URL.create(
    'mysql+pymysql', username=os.environ['MARIADB_MIGRATION_USER'],
    password=os.environ['MARIADB_MIGRATION_PASSWORD'],
    host=os.getenv('MARIADB_HOST', '127.0.0.1'),
    port=int(os.getenv('MARIADB_PORT', '3306')), database='culturepick',
    query={'charset': 'utf8mb4'},
)

if context.is_offline_mode():
    context.configure(url=url, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()
else:
    engine = create_engine(url, pool_pre_ping=True)
    with engine.connect() as connection:
        connection.exec_driver_sql("SET time_zone='+00:00'")
        connection.commit()
        context.configure(connection=connection, transactional_ddl=False)
        with context.begin_transaction():
            context.run_migrations()
