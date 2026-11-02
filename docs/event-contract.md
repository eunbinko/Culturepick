# 이벤트 JSON 공통 규격

원본 계약은 [event_schema.json](../database/mongodb/event_schema.json), 17개 예제는 [event_examples.json](../database/mongodb/event_examples.json)입니다. 전송 JSON 시각은 `Z`가 붙은 ISO 8601 UTC 문자열이며, 저장 전에 `datetime`/`Date`로 변환해 BSON Date로 넣습니다. JSON 문자열을 그대로 저장하면 Mongo 검증이 거절합니다.

| 필드 | 타입·규칙 |
|---|---|
| event_id | 소문자 표준 UUID 문자열, 원본 UNIQUE, 재전송 때 유지 |
| schema_version | 정수 1, 알 수 없는 버전은 거절 |
| event_type / event_source | 아래 허용 목록 / browser 또는 server |
| occurred_at / received_at | 발생 UTC / 서버 최초 수신 UTC, 재전송으로 수신 시각 덮어쓰기 금지 |
| request_id | HTTP 시도 단위 검증된 ID, 인증 토큰 아님 |
| operation_id | 서버 변경 단위 ID, 브라우저는 null |
| user_id / anonymous_id | 사용자 BIGINT 문자열 또는 임의 익명 ID, 정확히 하나만 비NULL |
| session_id | 행동 세션 임의 ID, 인증 쿠키·공연 회차와 다름 |
| content_id | 콘텐츠 BIGINT 문자열 또는 콘텐츠 무관 이벤트의 null |
| aggregate_type / aggregate_id / aggregate_version | 서버 변경 대상 종류·ID·버전, 브라우저는 모두 null |
| is_test / test_run_id | bool / 합성 실행 이름, 실제 데이터는 false/null |
| properties | 허용 키만, 비밀번호·토큰·쿠키·이메일·개인 주소·리뷰 본문 값 금지 |

서버는 JSON 본문의 user_id/event_source/is_test/received_at를 신뢰하지 않습니다. 인증 세션·배포 환경으로 지정합니다. 로그아웃·익명 방문은 임의 anonymous_id를 사용하며 로그인 전 이력을 개인에게 자동 연결하지 않습니다. API에서 BIGINT 참조가 signed BIGINT 범위인지도 검사합니다.

## 발행 조건

| 발행자 | 유형 | 조건·필수 데이터 |
|---|---|---|
| 브라우저 허용 | content_viewed | 상세 데이터 표시 성공 시 1회, 콘텐츠 ID |
| 브라우저 허용 | search_performed, filter_changed | 검색/조작 확정 시, 길이 제한·마스킹된 search_term 또는 허용 filters |
| 브라우저 허용 | recommendation_impression, recommendation_clicked | 실제 노출/클릭, recommendation_id+content_id+position |
| 서버 outbox | user_registered | 가입/지급 SQL 확정, granted_credit |
| 서버 outbox | profile_updated, survey_submitted, survey_updated | 실제 변경 시, 수정은 changed_fields와 증가한 버전 |
| 서버 outbox | bookmark_added, bookmark_removed | 현재 상태 전환 성공 시만, 동일 요청에 새 이벤트 없음 |
| 서버 outbox | review_created, review_updated, review_deleted | 동일 리뷰 행·버전, 수정은 changed_fields만 |
| 서버 outbox | reservation_confirmed, reservation_cancelled | SQL 확정, reservation_id/content_session_id/quantity/unit_credit/total_credit |
| 서버 outbox | visit_marked | 사용자 직접 관람 표시 확정, 인증 관람으로 과장하지 않음 |

`/api/v1/events`는 브라우저 5종만 받도록 백엔드에서 제한합니다. DB 계정이나 형식 규칙만으로 발행자의 신뢰를 증명하지 않습니다. 이벤트 크기는 16KiB 상한 제안이며 엔드포인트가 전체 UTF-8 크기를 제한합니다. Mongo 자체 문서 상한과 별개입니다.

수정에는 값 전체가 아닌 변경 필드 이름과 version을 기록합니다. 예약 취소 이벤트는 취소 당시 구매 스냅샷을 포함하며, 현재 예약 상태로 과거 확정을 부정하지 않습니다. 추천 API 응답 자체는 노출이 아니며 recommendation_id는 **화면 노출 기회마다 새로 생성**합니다.

## 전달·중복 처리

1. 업무 변경과 outbox payload를 같은 SQL 트랜잭션에 기록합니다. payload에는 최초 received_at가 없고 배송기가 Mongo 수신 시각을 한 번 지정합니다.
2. 단일 배송기가 due PENDING을 읽어 INSERT합니다. Mongo 저장 확인 후에만 SENT/sent_at를 변경합니다.
3. event_id UNIQUE 충돌이면 기존 문서와 불변 필드를 비교합니다. `_id`, received_at만 비교에서 제외합니다. 같으면 성공, 다르면 EVENT_ID_CONFLICT를 기록하고 SENT로 성공 처리하지 않습니다.
4. 실패마다 attempts/last_error/next_retry_at를 갱신하고 지수 대기합니다. 5회 후 FAILED 보존, 수동 재전송도 event_id 유지입니다.
5. 브라우저 이벤트는 Mongo 확인 후 성공, 장애는 503으로 같은 event_id 재전송을 유도합니다. 브라우저 종료에 의한 유실은 보장 범위 밖입니다.

Mongo raw_events는 앱·배송기 계정에 find/insert만 허용합니다. 의미 중복은 operation_id의 비고유 Mongo 인덱스로 관찰하고 정제 측에서 1건으로 만듭니다. 다른 event_id의 정상 상세 조회는 제거하지 않습니다. 원본/오류 TTL은 팀 보관 정책 합의 전 적용하지 않습니다.

## 로그 연결

Loki 로그 본문: timestamp/service/env/level/request_id/operation_id/event_id/route_template/method/status_code/duration_ms/error_code/test_run_id. Nginx가 요청 ID를 생성·검증해 FastAPI와 응답에 전달합니다. 고유값이 많은 ID는 Loki 라벨로 쓰지 않습니다. query string/Authorization/Cookie/요청 본문을 access 로그에 복제하지 않습니다.
