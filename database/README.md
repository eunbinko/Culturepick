# DB 접속·초기화·검증

모든 명령은 저장소 루트 기준입니다. [루트 README](../README.md)의 시작 순서를 먼저 실행합니다.

## 실행 순서와 스키마 기준

1. `scripts/create_env.py`로 무작위 비밀번호를 생성합니다. 기존 `.env`는 덮어쓰지 않습니다.
2. Compose를 올리면 빈 볼륨에서만 DB·접속 계정과 Mongo 검증/인덱스가 초기화됩니다.
3. `migrate` 서비스가 Alembic `upgrade head`를 실행합니다.
4. 로컬 root로 `permissions.sql`을 적용해 테이블별 역할을 부여합니다. 앱에는 DDL 권한을 주지 않습니다.
5. 선택적으로 **새 개발 DB**에 `seed.sql`을 적용합니다. 2명/3개 콘텐츠/2개 회차/2개 예약/5개 원장이 생성됩니다. 합성 계정은 로그인할 수 없는 비밀번호 해시를 사용합니다.

`schema.sql`은 Alembic `0001_initial`의 생성 참고본입니다. 초기 설치에 직접 실행하거나 `create_all()`과 병행하지 않습니다. 변경은 새 revision으로 추가하고 현재 버전의 참고본을 재생성하는 절차를 마련합니다. 현재 생성기는 첫 revision 전용이며 이후 revision이 추가되면 갱신해야 합니다. 배포된 첫 revision을 고치지 않습니다. MariaDB DDL은 전체 롤백되지 않으므로 실패 시 새 DB에서 재현하고 수동 복구 또는 전진 마이그레이션합니다.

```bash
python scripts/render_schema.py --check
python scripts/build_fixtures.py
```

Seed 재실행은 동일 PK/operation_id를 다시 생성하지 않습니다. 기존 운영 데이터와 ID 충돌을 해결하는 도구가 아니며 운영 DB에 실행하지 않습니다. 모든 합성 사용자의 `dataset_key`는 `demo-20261102-01`입니다. 테스트 계정을 실제 계정으로 바꾸지 않습니다.

## PowerShell에서 초기화

```powershell
python scripts/create_env.py
docker compose --project-directory . --env-file infra/db/.env -f infra/db/compose.yaml up -d --wait
docker compose --project-directory . --env-file infra/db/.env -f infra/db/compose.yaml --profile tools run --rm --build migrate
Get-Content -Raw -Encoding UTF8 database/mariadb/permissions.sql | docker compose --project-directory . --env-file infra/db/.env -f infra/db/compose.yaml exec -T mariadb sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -uroot'
```

PowerShell 5의 네이티브 파이프는 문자 인코딩에 영향을 줄 수 있습니다. 한국어 seed 파일은 Git Bash의 `<` 리다이렉션을 권장합니다. 바이너리 백업을 PowerShell 텍스트 파이프로 전달하지 않습니다.

## 접속 주소와 풀

| 실행 위치 | MariaDB | MongoDB |
|---|---|---|
| 같은 Compose 네트워크 | `mariadb:3306` | `mongodb:27017` |
| 로컬 호스트 | `127.0.0.1:3306` | `127.0.0.1:27017` |
| 실제 api-01 | db-01 사설 IP/DNS | db-01 사설 IP/DNS |

`mariadb`와 `mongodb`라는 컨테이너 서비스 이름은 별도 호스트 사이의 DNS가 아닙니다. 실제 접속 문자열은 배포 담당이 설정합니다.

```python
# 환경변수에서 비밀값을 읽고 연결 URL 문자열을 출력하지 않습니다.
import os
from sqlalchemy import create_engine
from sqlalchemy.engine import URL
from pymongo import MongoClient

engine = create_engine(URL.create(
    'mysql+pymysql', username='app_user', password=os.environ['MARIADB_APP_PASSWORD'],
    host=os.environ['MARIADB_HOST'], port=3306, database='culturepick',
    query={'charset': 'utf8mb4'},
), pool_size=5, max_overflow=5, pool_pre_ping=True,
   connect_args={'init_command': "SET time_zone='+00:00'"})
mongo = MongoClient(host=os.environ['MONGODB_HOST'], port=27017,
                    username='event_app', password=os.environ['MONGO_APP_PASSWORD'],
                    authSource='culturepick_events', maxPoolSize=20,
                    serverSelectionTimeoutMS=5000, tz_aware=True)
# SQL Session은 요청 단위 begin/commit 또는 rollback/close.
# MongoClient는 프로세스당 재사용하며 종료 시 close.
```

## 실제 DB 테스트

테스트는 **폐기 가능한 개발 DB**에서만 실행합니다. 예제 조회/집계 SQL의 COMMIT 때문에 분석 결과를 남길 수 있습니다. Bash에서 로컬 생성 환경을 읽고 실행합니다. GitHub Actions도 같은 절차를 수행합니다.

```bash
set -a
source infra/db/.env
set +a
export TEST_MARIADB_PORT="$MARIADB_PORT"
export TEST_MARIADB_USER=migration_user
export TEST_MARIADB_PASSWORD="$MARIADB_MIGRATION_PASSWORD"
export TEST_APP_PASSWORD="$MARIADB_APP_PASSWORD"
export TEST_MONGODB_URI="mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@127.0.0.1:${MONGODB_PORT}/?authSource=admin"
export TEST_MONGO_APP_PASSWORD="$MONGO_APP_PASSWORD"
python -m pytest -q
```

테스트 root 또는 migration 접속은 앱의 접속 권한을 뜻하지 않습니다. 비밀값이 들어 있는 환경을 출력하거나 `set -x`를 사용하지 않습니다. 새 환경값은 기존 볼륨의 비밀번호를 바꾸지 않으므로 비밀번호 교체는 DB 계정 변경과 함께 수행합니다.

`indexes.sql`은 동일 쿼리에 IGNORE/FORCE INDEX를 사용해 EXPLAIN을 비교합니다. tiny seed의 실행계획은 대용량 성능의 증거가 아닙니다. 실제 환경·행 수·시간을 측정하기 전 속도 개선 비율을 보고하지 않습니다.
