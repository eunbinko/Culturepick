# 행동 이벤트 계약 v2

분석 이벤트는 MongoDB `culturepick_events.events`에 저장한다. MariaDB `behavior_events`는 추천과 최근 본 콘텐츠 호환용으로 유지한다. 로그인된 사용자만 수집한다. `anonymous_id`는 브라우저 인스턴스 식별값으로 이벤트 봉투에 포함하지만 인증 없는 수집은 허용하지 않는다.

## 수집 API와 큐

`POST /api/v1/history/events/batch`는 Bearer 인증이 필요하며 `{ "events": [...] }` 형태로 1~10건을 받는다. 성공 응답은 `202 {"accepted": n}`이다. 브라우저는 localStorage 큐를 10건까지 유지하고, 10건이 쌓이거나 3초가 지나면 전송한다. 실패한 이벤트는 다음 시도까지 큐에 둔다. `event_id` 고유 인덱스로 재전송 중복을 멱등 처리한다.

## 이벤트 형식

필수 필드: `event_id` UUID, `type`, `occurred_at` UTC ISO 8601, `session_id` UUID, `anonymous_id` UUID, `page.path`, `page.referrer`, `props`, `schema_version`(현재 4). `user_id`는 서버가 인증 정보에서 추가한다.

| type | 행동 |
|---|---|
| `page_view` | 페이지 이동 |
| `search` | 검색 실행 |
| `filter_use` | 탐색 필터 변경 |
| `content_view` | 콘텐츠 상세 조회 |
| `recommendation_impression` | 추천 카드 노출 |
| `recommendation_click` | 추천 카드 선택 |
| `bookmark_add`, `bookmark_remove` | 찜 등록/해제 |
| `review_submit`, `review_delete` | 리뷰 작성/삭제 |
| `survey_submit` | 취향 설문 저장 |
| `reservation_checkout_started` | 예약 결제 시작 |
| `payment_verified`, `payment_cancelled` | 결제 확인/취소 |

`props`에는 해당 행동에 필요한 콘텐츠 ID, 검색어, 필터, 취향, 결제 금액만 넣고 카드 정보·비밀번호·비밀키 등 민감 정보는 넣지 않는다.

## Mongo 설정

`MONGO_URI`, `MONGO_DATABASE`, `MONGO_COLLECTION`로 설정한다. 기본 데이터베이스는 `culturepick_events`, 컬렉션은 `events`다. 인증 데이터베이스는 MongoDB `admin`을 사용한다. 비밀번호에 예약 문자가 있으면 URI 인코딩한다.
