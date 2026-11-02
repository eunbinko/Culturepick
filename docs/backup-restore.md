# 백업·복원 절차

백업은 DB 호스트 바깥의 암호화 저장소에도 복사합니다. `.env`와 DB 계정은 별도 비밀 관리로 복구하고 Git에 올리지 않습니다. Bash, Docker Compose, gzip, sha256sum이 필요합니다. 모든 명령은 저장소 루트 기준입니다.

## 백업

```bash
bash database/backup/backup_mariadb.sh
# 앱·dispatcher·ETL 등 Mongo writer를 실제로 정지한 후 실행
WRITES_PAUSED=yes bash database/backup/backup_mongodb.sh
```

`backups/`에 UTC 시각과 PID가 붙은 `.sql.gz` / `.archive.gz` 및 `.sha256`이 생성됩니다. `BACKUP_DIR=/별도/볼륨`으로 바꿀 수 있습니다. 비밀 파일 권한은 umask 077이며, 실패한 dump는 `.partial`만 제거하고 성공 파일로 승격하지 않습니다. stdout에 비밀번호를 출력하지 않습니다.

MariaDB는 두 스키마를 **한 번의 `--single-transaction`**으로 덤프합니다. 백업 중 DDL 변경을 중지합니다. SELECT/SHOW VIEW/TRIGGER만 있는 backup_user를 사용하며 시스템 mysql 계정·권한 DB는 포함하지 않습니다. 현재 스키마에는 routine/event가 없어 덤프에서 제외했습니다. 추후 추가하면 권한과 백업 옵션을 함께 변경합니다. `mariadb-dump`를 사용하며 `mysqldump` 별칭에 의존하지 않습니다.

MongoDB standalone은 replica oplog 기반 snapshot이 아닙니다. 컬렉션 간 일관성을 위해 **실제로 writer를 멈춘 상태**에서 `mongodump`합니다. WRITES_PAUSED는 운영자의 확인값일 뿐 프로세스를 자동 정지하지 않습니다. 이 값만 설정해 일관성이 생기는 것은 아닙니다. 두 DB 백업은 같은 시각의 분산 스냅샷이 아니므로 복원 후 outbox 대조가 필요합니다.

크론 제안은 매일 02:00 KST MariaDB, writer 중지가 가능한 작업 시간 MongoDB입니다. 프로젝트 일정/중지 가능 시간에 따라 팀에서 정합니다. 보관 기간 합의 전 자동 백업 삭제는 실행하지 않습니다. `sha256sum`은 파일 손상 검출이며 서명·암호화 수단은 아닙니다.

## 별도 환경 복원

스크립트는 `culturepick-restore-`로 시작하는 **별도 Compose 프로젝트**만 받습니다. 운영 프로젝트로의 직접 복원은 지원하지 않습니다. 대상은 비어 있는 실습 환경으로 준비하고, 기존 복원 환경에 실행하면 그 환경의 테이블/컬렉션이 대체됨을 확인합니다.

이전에 `.env`를 source/export했다면 쉘의 포트·프로젝트 값이 Compose `--env-file`보다 우선합니다. 아래 unset은 원본 포트가 복원 환경에 덮이는 것을 막습니다. 원본과 비교하는 도구에는 SOURCE_MARIADB_PORT를 별도로 전달합니다.

```bash
# .env의 private 값을 복사하고 프로젝트 이름 및 공개 포트만 변경
cp infra/db/.env infra/db/.env.restore
# .env.restore 편집:
# COMPOSE_PROJECT_NAME=culturepick-restore-drill
# MARIADB_PORT=13307
# MONGODB_PORT=27018

export ENV_FILE="$PWD/infra/db/.env.restore"
unset MARIADB_PORT MONGODB_PORT COMPOSE_PROJECT_NAME
export RESTORE_PROJECT=culturepick-restore-drill
export RESTORE_CONFIRM="$RESTORE_PROJECT"
bash scripts/db.sh --project-name "$RESTORE_PROJECT" up -d --wait mariadb mongodb
bash database/backup/restore_mariadb.sh backups/<mariadb-file>.sql.gz
bash database/backup/restore_mongodb.sh backups/<mongodb-file>.archive.gz
bash scripts/db.sh --project-name "$RESTORE_PROJECT" exec -T mariadb sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -uroot' < database/mariadb/permissions.sql
```

복원 전 저장소의 init.js·서버 버전과 백업 버전을 맞춥니다. SQL 덤프 안에 스키마와 Alembic 버전이 포함되므로 덤프 복원 전 migrate를 실행할 필요는 없습니다. Mongo 초기화는 새 볼륨에서 역할/사용자를 만들고, 덤프는 이벤트 컬렉션·검증·인덱스를 복원합니다. 사용자/역할은 덤프에 의존하지 않습니다. 복원 스크립트는 파일의 체크섬을 검증하고 명령 실패를 즉시 반환합니다.

## 복원 후 확인

1. 업무/분석 테이블별 건수, 회원·예약 상태, 계정 잔액, 원장 합계·balance_after를 원 백업 환경과 비교합니다.
2. Mongo event_id 집합·문서 수·검증 규칙·고유 인덱스를 확인합니다.
3. SQL outbox와 Mongo를 대조하고 누락은 **동일 event_id**로 재배송합니다. Mongo에 이미 있는 이벤트는 불변 필드 일치를 확인합니다.
4. ETL을 재실행해 영향받은 KST 날짜 집계를 대체하고 두 번 실행 결과가 같은지 확인합니다.
5. Loki 영속 볼륨·설정 복구는 관측 담당의 별도 절차를 적용하고 조회 범위 완전성을 기록합니다.

GitHub Actions는 별도 프로젝트에 실제 dump/restore하고 `scripts/verify_restore.py`로 표별 건수·잔액·거래·이벤트 ID를 비교합니다. 서비스 dispatcher/ETL/Loki 복구는 이 DB 패키지에서 구현하지 않았으므로 3~5번의 통합 시연은 후속 작업입니다.

공식 근거: [MariaDB dump의 일관성 옵션](https://mariadb.com/docs/server/clients-and-utilities/backup-restore-and-import-clients/mariadb-dump), [MongoDB mongodump](https://www.mongodb.com/docs/database-tools/mongodump/).
