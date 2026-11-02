"""Compare isolated restore with the source DBs, without changing either."""
import os
import pymysql
from pymongo import MongoClient


def sql_state(port):
    sql = pymysql.connect(host='127.0.0.1', port=int(port), user='root',
                          password=os.environ['MARIADB_ROOT_PASSWORD'], charset='utf8mb4')
    result = {}
    try:
        with sql.cursor() as c:
            c.execute("SELECT TABLE_SCHEMA,TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA IN ('culturepick','culturepick_analytics') ORDER BY TABLE_SCHEMA,TABLE_NAME")
            for schema, name in c.fetchall():
                c.execute(f'SELECT COUNT(*) FROM `{schema}`.`{name}`')
                result[f'{schema}.{name}'] = c.fetchone()[0]
            c.execute('SELECT user_id,balance FROM culturepick.credit_accounts ORDER BY user_id')
            result['balances'] = c.fetchall()
            c.execute('SELECT id,user_id,reservation_id,type,delta,balance_after,reversal_of,operation_id,dataset_key FROM culturepick.credit_transactions ORDER BY id')
            result['ledger'] = c.fetchall()
    finally:
        sql.close()
    return result


def mongo_state(uri):
    with MongoClient(uri, serverSelectionTimeoutMS=5000) as client:
        events = client.culturepick_events.raw_events
        ids = sorted(doc['event_id'] for doc in events.find({}, {'event_id': 1}))
        indexes = {key: {k: value for k, value in info.items() if k != 'v'} for key, info in events.index_information().items()}
        options = events.options()
        return ids, indexes, options.get('validator')


def main():
    source_port = os.environ.get('SOURCE_MARIADB_PORT') or os.environ['MARIADB_PORT']
    if sql_state(source_port) != sql_state(os.environ['RESTORE_MARIADB_PORT']):
        raise SystemExit('MariaDB restore differs from source counts/balances/ledger')
    if mongo_state(os.environ['TEST_MONGODB_URI']) != mongo_state(os.environ['RESTORE_MONGODB_URI']):
        raise SystemExit('Mongo restore differs from source event IDs/indexes/validator')
    print('Restore verified: all table counts, balances, ledger rows, event IDs, indexes, validator match')


if __name__ == '__main__':
    main()
