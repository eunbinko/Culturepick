# 불일치 판정·정제 기준

이 문서는 별도 Python ETL 담당자의 구현 계약입니다. 현재 저장소의 fixture 분류기는 제공된 스냅샷으로 판정을 재현할 뿐 SQL/Mongo/Loki에 접속하는 ETL이 아닙니다.

## 추출과 체크포인트

MariaDB 업무·잔액·원장은 한 REPEATABLE READ 일관 스냅샷에서 읽습니다. Mongo는 received_at+event_id 인덱스로 마지막 성공 이후 전 구간을 읽고 15분을 겹쳐 재추출합니다. 장애 기간을 현재 시각으로 건너뛰지 않습니다. Loki는 서비스·시간 구간으로 HTTP Query API를 조회하며 상한 도달 시 구간을 분할합니다. timestamp+내용 해시로 결과를 중복 제거합니다. 조회 불완전/접속 불가/정상 0건을 구별해 etl_runs.complete_sources에 기록합니다.

세 저장소에 동시 스냅샷은 없습니다. 이벤트 발생 후 10분 유예, aggregate_version, 당시 outbox 스냅샷, 다음날 09:00 KST 전일 재대조를 사용합니다. 전체 필수 입력 추출이 성공한 실행만 checkpoint를 전진시킵니다. 늦은 이벤트의 business_date를 수집해 과거 날짜도 다시 집계합니다.

## 판정

| 코드 | 조건 | 후속 처리 |
|---|---|---|
| EVENT_DELIVERY_DELAY | SQL outbox 존재, 확인한 Mongo 범위에 없음, 10분 미만 | PENDING, 재배송 대기 |
| MISSING_EVENT | 같은 조건, 10분 경과 | OPEN, 같은 event_id 재배송 |
| DUPLICATE_OPERATION | 같은 서버 operation_id, 다른 event_id | 원본 모두 유지, SQL outbox의 기준 ID 1건만 정제 |
| INVALID_SCHEMA | 필수/타입/버전/발행원 위반 | 민감값 제거 후 rejected_events, 집계 제외 |
| ORPHAN_REFERENCE | 사용자·콘텐츠·예약 참조 없음 | 지연/삭제 이력 확인, 미해결 격리 |
| PAYLOAD_MISMATCH | 당시 SQL 스냅샷과 버전·단가·수량·합계 불일치 | 원본 보존, 검증 근거/보정 정책 기록 |
| MISSING_LOG | 전체 범위 추출 완료+유예 경과, 연관 로그 없음 | 관측 문제 기록, SQL 상태 취소 금지 |
| LEDGER_MISMATCH | 잔액과 원장 합계 또는 balance_after 연쇄 불일치 | CRITICAL 보고, 자동 잔액 수정 금지 |
| EXTRA_SERVER_EVENT | 성공 서버 이벤트에 SQL/outbox 근거 없음 | 격리, 이벤트로 예약/원장 생성 금지 |

EVENT_ID_CONFLICT/PAYLOAD_TOO_LARGE는 수신 거절 이유입니다. 품질 표에 기록할 때 INVALID_SCHEMA와 상세 근거로 대응합니다. SQL outbox PENDING만 보고 MISSING_EVENT라고 단정하지 않습니다. 저장 직후 배송기 중단으로 Mongo에 이미 존재할 수 있습니다.

issue_key 예: `MISSING_EVENT:{event_id}`, `LEDGER_MISMATCH:{user_id}:{business_date}`. UNIQUE 키로 UPSERT하여 first_seen 유지, last_seen/run_id 갱신, 해결하면 RESOLVED/resolved_at 기록합니다. 재발 시 OPEN으로 다시 열고 resolved_at를 비웁니다.

## 정제 순서·멱등성

1. 규격·버전·허용 종류·크기·UTC·문자열 참조 ID를 검사합니다.
2. 동일 event_id 재전송과 다른 ID의 의미 중복을 구별합니다. 기준 선택은 SQL outbox의 event_id를 우선하고 그 외에는 결정적인 정렬을 사용합니다.
3. 서버 이벤트는 event_id/operation_id 및 당시 aggregate_version/outbox 스냅샷을 대조합니다. 브라우저 전달 금액은 업무 원본이 아닙니다.
4. 참조·합계·원장과 추출 완전성을 검사한 뒤 clean_events를 event_id로 멱등 적재합니다. 이미 적재된 이벤트가 재검증 실패하면 clean에서 제외하고 해당 날짜 집계도 재계산합니다.
5. 익명 이벤트의 anonymous_id는 분석 properties_json에 복사해 추천 CTR 행위자를 유지합니다. 로그인 user_id와 임의 연결하지 않습니다.
6. business_date=DATE(occurred_at+9h), dataset_key는 실제 `real` 또는 test_run_id입니다. operation_id는 서버 업무만 사용해 별개 조회가 충돌하지 않게 합니다.
7. 단일 집계 writer가 영향받은 날짜 범위의 기존 집계를 DELETE+INSERT 한 트랜잭션으로 **대체**합니다. 이전 합계에 더하지 않습니다.

## 분석 SQL

추천 CTR은 노출된 업무일에 귀속하며 다음날 이후의 대응 클릭도 반영합니다. 노출보다 이른 클릭은 제외하고 기회당 최대 1회만 셉니다. 늦은 클릭을 적재할 때 클릭 발생일뿐 아니라 대응 노출의 업무일도 재계산 대상으로 등록합니다. 해당 일자의 노출이 없으면 SQL은 행을 반환하지 않으며 소비자는 CTR을 0 대신 NULL로 표시합니다.

| 파일 | 기준 |
|---|---|
| daily_activity.sql | clean_events, 로그인 user_id distinct만 user_count |
| content_metrics.sql | 조회/찜은 clean, 예매/취소 수와 금액은 SQL 원장. 0원도 건수 포함 |
| recommendation_data.sql | 30일 장르 관심 점수, 실제 노출 기회와 대응하는 클릭 1회 CTR |
| quality_checks.sql | 원장 합계/거래별 balance_after/예약 구매/환불 참조·금액/관람 연결 |

집계 실행 전 `@from_date`, `@to_date`, `@as_of_date`를 설정합니다. UTC 발생 시각으로 날짜를 정하며 받은 날에 귀속하지 않습니다. 환불은 환불 발생일에 반영하여 당일 net_credit이 음수일 수 있습니다. 이벤트 금액과 SQL 원장 금액을 함께 더하지 않습니다. 추천 가중치는 제안이며 실제 추천 서비스에서는 정책 버전과 설명을 함께 저장해야 합니다.

## 재현 사례

```bash
python -m pytest tests/test_artifacts.py tests/test_events.py -q
```

fixtures는 기대 코드가 포함된 사례 배열입니다. 일반 API의 입력 형식이 아닙니다. invalid fixture를 raw_events에 우회 삽입하지 않습니다. 동일 ID 중복은 Mongo UNIQUE, 다른 ID 의미 중복은 정제 판정으로 시험합니다. 23:59:59 KST는 UTC 14:59:59, 다음날 00:00:01 KST는 전날 UTC 15:00:01임을 DB 테스트로 확인합니다.
