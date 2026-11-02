# CulturePick · 데이터베이스

문화 콘텐츠 탐색·찜·리뷰·가상 크레딧 예매를 위한 **DB 담당 산출물**입니다. MariaDB는 업무 상태와 정제 결과, MongoDB는 원본 행동·업무 이벤트를 저장합니다. Loki 로그는 외부 관측 저장소로 연결하는 계약을 제공합니다.

## 시작

Docker Engine와 Compose v2, Python 3.12 이상이 필요합니다. 저장소 루트에서 실행합니다.

```bash
python -m pip install -r requirements-dev.txt
python scripts/create_env.py
bash scripts/db.sh up -d --wait
bash scripts/db.sh --profile tools run --rm --build migrate
bash scripts/db.sh exec -T mariadb sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -uroot' < database/mariadb/permissions.sql
# 선택: 새 개발 DB에만 합성 데이터 적재
bash scripts/db.sh exec -T mariadb sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -uroot' < database/mariadb/seed.sql
python -m pytest -q
```

마지막 명령은 접속 환경변수가 없으면 실제 DB 테스트를 **SKIP**합니다. 실제 접속 검증 방법은 [DB 가이드](database/README.md)를 따릅니다. Windows에서는 위 Bash 명령을 Git Bash/WSL에서 실행하거나 DB 가이드의 PowerShell 방법을 사용합니다.

## 구성

| 경로 | 내용 |
|---|---|
| [database/mariadb](database/mariadb) | schema 참고본, 합성 seed, 조회·인덱스·권한 SQL |
| [database/mongodb](database/mongodb) | BSON 검증 규칙, 최소 권한, 인덱스, JSON 예제 |
| [database/analytics](database/analytics) | KST 일별 재계산, 추천 관심 점수, 원장 대조 |
| [database/fixtures](database/fixtures) | 정상·중복·형식 오류·업무 불일치 사례와 기대 판정 |
| [database/backup](database/backup) | 체크섬·실패 감지·별도 프로젝트 복원 |
| [infra/db](infra/db) | DB 전용 Compose, 개별 볼륨·인증·메모리 제한 |
| [alembic](alembic) | 단일 스키마 변경 이력 |
| [docs/erd.md](docs/erd.md) | 관계도 |
| [docs/db-spec.md](docs/db-spec.md) | 담당 범위·트랜잭션 인수인계 |
| [docs/data-dictionary.md](docs/data-dictionary.md) | 전체 컬럼·타입·제약·인덱스 |
| [docs/event-contract.md](docs/event-contract.md) | 공통 이벤트·발행 및 재전송 규칙 |
| [docs/data-quality.md](docs/data-quality.md) | 불일치 판정·정제·집계 계약 |
| [docs/backup-restore.md](docs/backup-restore.md) | 백업·복원 실습 |
| [docs/verification.md](docs/verification.md) | 검증 결과와 범위 |

## 범위와 기본 제안

요청된 DB 파일 및 실행·검증 도구를 제공합니다. React 화면, FastAPI API, 외부 API 수집기, outbox 배송 프로세스, 세 저장소를 실제 추출하는 ETL, Loki/Alloy 배포는 다른 담당자가 구현할 부분입니다. SQL 예제와 fixture 분류기는 이 서비스들의 구현 완료를 뜻하지 않습니다.

MariaDB `11.8`, MongoDB `8.0`, 가입 100,000 크레딧, 시작 전 전액 취소, 단일 배송 프로세스, 배송 5회 재시도는 **제안 기본값**입니다. 이미지 태그는 해당 버전 계열의 패치를 받습니다. 실제 서버 배포 전 팀이 버전·이미지 digest·사양·보관 기간을 확정합니다. TTL 삭제는 켜지 않습니다. 실제 결제·좌석·재고 기능은 없습니다.

기본 포트는 `127.0.0.1`에만 공개합니다. 별도 api-01에서 접속하려면 db-01의 사설 주소, 호스트 방화벽, 승인된 원격 접속 구성을 적용합니다. 비밀번호는 `infra/db/.env`에만 생성하며 Git에 포함하지 않습니다.
