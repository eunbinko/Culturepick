"""Initial DB contract. Do not edit after deployment; add a new revision."""
from pathlib import Path
from alembic import op
from sqlalchemy import DDL
from scripts.render_schema import statements

revision = '0001_initial'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    ddl = Path(__file__).with_suffix('.sql').read_text(encoding='utf-8')
    for statement in statements(ddl):
        op.execute(DDL(statement))


def downgrade():
    raise RuntimeError('Initial schema downgrade would erase ledger data. Restore into an isolated DB instead.')
