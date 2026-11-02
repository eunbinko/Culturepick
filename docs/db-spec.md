# DB 요구사항·담당 범위

기준: 사용자 제공 「CulturePick 1차 프로젝트 요구사항명세서」(2026-11-02)의 B부와 요청한 폴더 구조. 이 저장소는 DB 팀원에게 전달할 독립 DB 패키지입니다.

## 저장소별 책임

| 저장소 | 기준 데이터 | 금지할 해석 |
|---|---|---|
| culturepick (MariaDB) | 현재 업무 상태, 예약, 잔액, 추가 전용 원장, 배송 outbox | 이벤트나 HTTP 200만 보고 잔액 변경 |
| culturepick_events (MongoDB) | 변경 당시의 사실·조회·클릭 원본 | 취소 후 과거 확정 이벤트를 오류로 처리 |
| Loki (별도 관측 호스트) | 요청 처리·오류·배송·지연 로그 | 로그 부재를 SQL 실패로 단정 |
| culturepick_analytics (MariaDB) | 검증된 이벤트, 품질 이슈, 재계산 집계 | 오류 이벤트·테스트 데이터를 실사용 통계에 혼합 |

InnoDB/utf8mb4, `DATETIME(6)` UTC, BSON Date UTC, 일별 날짜는 UTC+09:00입니다. 한국은 해당 업무일에 DST를 사용하지 않으므로 SQL은 9시간을 더합니다. 가격과 크레딧은 BIGINT이며 외부 ID는 JSON 문자열입니다. source/external_id 및 UUID·멱등성 키는 이진 비교를 사용합니다. 이메일은 애플리케이션에서 trim/lower 정규화하고 UNIQUE를 적용합니다. 이메일 검증/비밀번호 해시는 백엔드 책임입니다.

## 업무 테이블 계약

17개 업무 표와 7개 분석 표의 정확한 컬럼·타입·키는 [데이터 사전](data-dictionary.md), 관계는 [ERD](erd.md)에 있습니다. 예약·원장·참조 이력은 FK로 연쇄 삭제하지 않습니다. 리뷰는 삭제 시각을 기록하고 재작성 시 같은 행을 복구합니다. 방문 기록의 예약 소유자는 복합 FK로 검사하며, 회차의 콘텐츠와 방문 콘텐츠 일치는 서비스와 품질 SQL이 검사합니다.

DB CHECK는 행 내부의 상태만 보장합니다. 환불 시 원 거래의 type/금액, 예약 단가와 잠근 회차 가격, 시한, 사용 권한, 버전 증가, 잔액과 전체 원장 합계는 서비스 트랜잭션에서 검사합니다. `quality_checks.sql`이 일부 교차 행 위반을 탐지합니다. SQL 직접 쓰기로 서비스를 우회해도 모든 업무 규칙이 자동 보장되는 구조는 아닙니다.

## 예매·취소 서비스 인수인계

가상 회차 생성·단가 관리는 백엔드의 내부 작업이 `app_user`로 수행합니다. 해당 역할에 content_sessions SELECT/INSERT/UPDATE를 주며, 모든 회차는 is_simulated=1이어야 합니다. 공개 공급자 수집 계정은 원천 콘텐츠를 관리하고 회차 가격을 정하지 않습니다. 회차 가격 변경은 기존 예약 스냅샷과 분리합니다.

서비스만 트랜잭션을 시작/commit/rollback하고 repository는 임의 commit하지 않습니다. 기본 잠금 순서는 **멱등성 행 → credit_accounts → content_sessions → 기존 reservation**입니다. 취소는 예약을 먼저 잠그지 않은 조회로 소유자/회차를 알아낸 후 같은 순서로 잠그고, 잠금 뒤 예약 상태·소유자·회차를 다시 검증합니다. 예매와 취소가 서로 다른 잠금 순서로 교착하지 않도록 이 순서를 통일합니다.

| 단계 | 예매 | 취소 |
|---|---|---|
| 멱등성 | 사용자+operation+key UNIQUE, 정규화 본문 SHA-256 비교 | 같은 키 재시도는 기존 응답, 다른 키의 반복 취소도 추가 환불 없음 |
| 검증 | 인증 사용자, 회차 시작 전, 수량 1~4, 잔액, 서버 가격 | 소유자, 확정 상태, 시작 전, 원 구매 PURCHASE |
| 한 트랜잭션 | reservation → balance 차감 → PURCHASE → outbox → 멱등 응답 | CANCELLED/버전 증가 → 원 구매 금액 반환 → REFUND → outbox → 멱등 응답 |
| 식별자 | `reservation:{id}:confirmed` | `reservation:{id}:cancelled` |
| 실패 | 전체 rollback, 잔액 부족/본문 충돌 409 | 전체 rollback, 시작 후 취소 거절 |

가입 계정은 0에서 시작해 제안 100,000 크레딧 지급을 원장과 같은 트랜잭션에 반영합니다. `signup:{user_id}` 고정 operation_id로 1회만 지급합니다. 한 사용자의 여러 구매를 허용하며 `UNIQUE(user_id,type)`를 사용하지 않습니다. PURCHASE/REFUND의 고정 operation_id와 `(reservation_id,type)` UNIQUE, `reversal_of` UNIQUE로 중복 원장을 제한합니다. 0크레딧 구매·환불도 반드시 원장에 남깁니다.

예매 수량/단가/합계를 스냅샷으로 저장하고 환불은 현재 콘텐츠 가격이 아닌 **원 PURCHASE**를 기준으로 합니다. 부분 환불·회차 직접 변경·실결제·실좌석·재고는 구현 범위가 아닙니다. deadlock/lock timeout은 제한된 횟수로 전체 트랜잭션을 재시도합니다.

멱등성 요청이 동시에 들어오면 UNIQUE 충돌 후 해당 트랜잭션을 rollback하고 새 트랜잭션에서 완료 응답을 읽습니다. 처리 중이면 제한된 대기/재시도를 적용합니다. 완료되지 않은 멱등 레코드를 단독 commit하지 않습니다. token_hash만 저장하고 원 토큰/비밀번호를 outbox·이벤트·로그에 기록하지 않습니다.

## 제안 설정과 팀 확정 사항

| 항목 | 현재 제안 | 변경 위치/책임 |
|---|---|---|
| DB 버전 | MariaDB 11.8 / MongoDB 8.0 계열 | .env 이미지 변수, 팀 최종 확정 |
| 메모리/CPU | DB별 768MiB / 1 CPU | Compose, 실제 사양 측정 후 조정 |
| 가입 지급/취소 | 100,000 / 시작 전 전액 | 백엔드 설정, 실제 합의 아님 |
| 생활유형 | ANY/RELAXED/ACTIVE/SOCIAL | 설문 코드 최종 합의 시 새 migration |
| 배송 | 5초, 최대 5회, 단일 worker | 백엔드 작업 설정 |
| ETL | 5분, received_at 기준 15분 겹침 | ETL 작업 설정 |
| 유예/재대조 | 10분 / 다음날 09:00 KST | ETL 작업 설정 |
| 이벤트/로그 보관 | 90일 / 30일 제안 | 합의 전 TTL 비활성 |
| 외부 수집 | 공급자 미정 | URL/필드/키를 가정하지 않음 |

## 완료 범위

이 저장소는 DDL·마이그레이션·권한·개발 데이터·Mongo 규칙·분석 SQL·백업 도구·DB 테스트를 제공합니다. 명세서 B12의 외부 공급자 UPSERT 구현, dispatcher 실행 프로세스, SQL/Mongo/Loki 추출 ETL, API 시나리오 전체 T01~T16 및 100명/200개/10,000건 목표 데이터는 별도 백엔드 통합 단계입니다. [검증 기록](verification.md)에 실행과 미실행을 구분합니다.

기술 근거: [MariaDB 행 잠금](https://mariadb.com/docs/server/reference/sql-statements/data-manipulation/selecting-data/for-update), [MongoDB 스키마 검증](https://www.mongodb.com/docs/manual/core/schema-validation/), [Alembic 마이그레이션](https://alembic.sqlalchemy.org/en/latest/tutorial.html).
