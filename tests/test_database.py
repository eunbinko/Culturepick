"""Run only against disposable DBs. Every test rolls back its writes."""
from pathlib import Path
import pytest
from pymysql import IntegrityError, OperationalError

ROOT = Path(__file__).resolve().parents[1]


def test_required_tables(sql):
    with sql.cursor() as c:
        c.execute('SHOW TABLES')
        assert len(c.fetchall()) == 18  # 17 business + alembic_version
        c.execute('SHOW TABLES FROM culturepick_analytics')
        assert len(c.fetchall()) == 7


@pytest.mark.parametrize('statement', [
    "INSERT INTO users(email,password_hash,nickname) VALUES('demo1@example.invalid','disabled','duplicate')",
    "INSERT INTO bookmarks(user_id,content_id) VALUES(1,101)",
    "UPDATE credit_accounts SET balance=-1 WHERE user_id=1",
    "UPDATE reviews SET rating=6 WHERE id=401",
    "UPDATE reservations SET quantity=5,total_credit=50000 WHERE id=501",
    "UPDATE reservations SET total_credit=1 WHERE id=501",
    "INSERT INTO bookmarks(user_id,content_id) VALUES(999999,101)",
    "UPDATE contents SET is_free=1 WHERE id=101",
    "UPDATE credit_transactions SET operation_id='signup:wrong' WHERE id=1",
    "INSERT INTO credit_transactions(user_id,reservation_id,type,delta,balance_after,operation_id,dataset_key) VALUES(1,501,'REFUND',20000,100000,'reservation:501:cancelled','demo-20261102-01')",
])
def test_constraints_reject_invalid_state(sql, statement):
    with sql.cursor() as c, pytest.raises((IntegrityError, OperationalError)):
        c.execute(statement)


def test_seed_is_repeatable(sql):
    from scripts.render_schema import statements
    with sql.cursor() as c:
        c.execute('SELECT COUNT(*),SUM(delta) FROM credit_transactions')
        before = c.fetchone()
        for stmt in statements((ROOT / 'database/mariadb/seed.sql').read_text(encoding='utf-8')):
            c.execute(stmt)
        c.execute('SELECT COUNT(*),SUM(delta) FROM credit_transactions')
        assert c.fetchone() == before


def test_balances_equal_ledger(sql):
    with sql.cursor() as c:
        c.execute('SELECT a.user_id FROM credit_accounts a LEFT JOIN credit_transactions t '
                  'ON t.user_id=a.user_id GROUP BY a.user_id,a.balance HAVING a.balance<>COALESCE(SUM(t.delta),0)')
        assert c.fetchall() == ()


def test_outbox_seed_matches_wire_contract(sql):
    import json
    from database.event_validation import validate_event
    with sql.cursor() as c:
        c.execute("SELECT payload_json FROM event_outbox WHERE request_id LIKE 'seed-request-%'")
        rows = c.fetchall()
        assert len(rows) == 5
        for (payload,) in rows:
            event = json.loads(payload)
            event['received_at'] = event['occurred_at']
            assert validate_event(event) == [], event


def test_queries_and_analytics_execute_repeatably(sql):
    from scripts.render_schema import statements
    with sql.cursor() as c:
        c.execute("SET @from_date='2026-11-02',@to_date='2026-11-02',@as_of_date='2026-11-02'")
        files = ['database/mariadb/queries.sql', 'database/mariadb/indexes.sql',
                 'database/analytics/daily_activity.sql', 'database/analytics/content_metrics.sql',
                 'database/analytics/recommendation_data.sql', 'database/analytics/quality_checks.sql']
        for path in files:
            for stmt in statements((ROOT / path).read_text(encoding='utf-8')):
                c.execute(stmt)
        c.execute('SELECT * FROM culturepick_analytics.daily_content_metrics ORDER BY business_date,dataset_key,content_id')
        before = c.fetchall()
        for path in files[2:5]:
            for stmt in statements((ROOT / path).read_text(encoding='utf-8')):
                c.execute(stmt)
        c.execute('SELECT * FROM culturepick_analytics.daily_content_metrics ORDER BY business_date,dataset_key,content_id')
        assert c.fetchall() == before
        assert before  # Seeded purchase and refund must produce metrics
        c.execute("SELECT reservation_count,cancelled_count,gross_credit,refund_credit,net_credit "
                  "FROM culturepick_analytics.daily_content_metrics WHERE content_id=101 AND dataset_key='demo-20261102-01'")
        assert c.fetchone() == (1, 1, 20000, 20000, 0)


def test_kst_day_boundary(sql):
    with sql.cursor() as c:
        c.execute("SELECT DATE('2026-11-01 14:59:59' + INTERVAL 9 HOUR),DATE('2026-11-01 15:00:01' + INTERVAL 9 HOUR)")
        assert tuple(str(x) for x in c.fetchone()) == ('2026-11-01', '2026-11-02')


def test_free_purchase_and_refund_have_ledger_rows(sql):
    with sql.cursor() as c:
        c.execute("INSERT INTO credit_transactions(user_id,reservation_id,type,delta,balance_after,reversal_of,operation_id,dataset_key) "
                  "VALUES(2,502,'REFUND',0,100000,5,'reservation:502:cancelled','demo-20261102-01')")
        c.execute("SELECT COUNT(*),SUM(delta) FROM credit_transactions WHERE reservation_id=502")
        assert c.fetchone() == (2, 0)


@pytest.mark.parametrize('statement', [
    'UPDATE credit_transactions SET delta=0 WHERE id=1',
    'DELETE FROM credit_transactions WHERE id=1',
    "UPDATE event_outbox SET status='FAILED' WHERE event_id='00000000-0000-4000-8000-000000000001'",
    'CREATE TABLE forbidden(id INT)',
])
def test_app_role_cannot_mutate_ledger_or_dispatch(sql, statement):
    import os
    import pymysql
    password = os.getenv('TEST_APP_PASSWORD')
    if not password:
        pytest.skip('TEST_APP_PASSWORD not configured')
    app = pymysql.connect(host=os.getenv('TEST_MARIADB_HOST', '127.0.0.1'),
                          port=int(os.environ['TEST_MARIADB_PORT']), user='app_user',
                          password=password, database='culturepick')
    try:
        with app.cursor() as c, pytest.raises(OperationalError):
            c.execute(statement)
    finally:
        app.rollback()
        app.close()


def test_app_can_provision_simulated_session(sql):
    import os
    import pymysql
    if not os.getenv('TEST_APP_PASSWORD'):
        pytest.skip('TEST_APP_PASSWORD not configured')
    app = pymysql.connect(host=os.getenv('TEST_MARIADB_HOST', '127.0.0.1'),
                          port=int(os.environ['TEST_MARIADB_PORT']), user='app_user',
                          password=os.environ['TEST_APP_PASSWORD'], database='culturepick')
    try:
        with app.cursor() as c:
            c.execute("INSERT INTO content_sessions(content_id,starts_at,credit_price) VALUES(101,'2099-12-02',10000)")
            assert c.rowcount == 1
    finally:
        app.rollback()
        app.close()


def test_ctr_matches_click_after_kst_midnight_once(sql):
    from scripts.render_schema import statements
    event_ids = ['30000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000003']
    try:
        with sql.cursor() as c:
            for event_id, kind, occurred, day in [
                (event_ids[0], 'recommendation_impression', '2026-11-02 14:59:00', '2026-11-02'),
                (event_ids[1], 'recommendation_clicked', '2026-11-02 15:01:00', '2026-11-03'),
                (event_ids[2], 'recommendation_clicked', '2026-11-02 15:02:00', '2026-11-03')]:
                c.execute("INSERT INTO culturepick_analytics.clean_events(event_id,event_type,occurred_at,business_date,user_id,content_id,source,is_test,test_run_id,dataset_key,properties_json,normalization_version,run_id) "
                          "VALUES(%s,%s,%s,%s,1,101,'browser',1,'ctr-boundary','ctr-boundary',JSON_OBJECT('recommendation_id','midnight-test','position',0),1,'10000000-0000-4000-8000-000000000001')", (event_id,kind,occurred,day))
            c.execute("SET @as_of_date='2026-11-02'")
            for stmt in statements((ROOT / 'database/analytics/recommendation_data.sql').read_text(encoding='utf-8')):
                c.execute(stmt)
            rows = c.fetchall()
            assert ('ctr-boundary', 1, 1, 1) in rows
    finally:
        with sql.cursor() as c:
            c.execute("DELETE FROM culturepick_analytics.clean_events WHERE dataset_key='ctr-boundary'")
            c.execute("DELETE FROM culturepick_analytics.user_genre_features WHERE dataset_key='ctr-boundary'")
        sql.commit()
