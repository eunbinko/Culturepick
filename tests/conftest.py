import os
import pytest


@pytest.fixture
def sql():
    if not os.getenv('TEST_MARIADB_PORT'):
        pytest.skip('Set TEST_MARIADB_PORT to an isolated migrated test instance')
    import pymysql
    connection = pymysql.connect(
        host=os.getenv('TEST_MARIADB_HOST', '127.0.0.1'),
        port=int(os.environ['TEST_MARIADB_PORT']), user=os.getenv('TEST_MARIADB_USER', 'root'),
        password=os.getenv('TEST_MARIADB_PASSWORD', ''), database='culturepick',
        charset='utf8mb4', autocommit=False,
    )
    try:
        with connection.cursor() as cursor:
            cursor.execute("SET time_zone='+00:00'")
        yield connection
    finally:
        connection.rollback()
        connection.close()


@pytest.fixture
def mongo():
    if not os.getenv('TEST_MONGODB_URI'):
        pytest.skip('Set TEST_MONGODB_URI to an isolated initialized test instance')
    from pymongo import MongoClient
    client = MongoClient(os.environ['TEST_MONGODB_URI'], serverSelectionTimeoutMS=5000)
    yield client.culturepick_events
    client.close()
