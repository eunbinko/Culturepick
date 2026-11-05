# CulturePick API 계약

기본 경로 `/api/v1`. JSON, 날짜 `YYYY-MM-DD`, 시각 UTC ISO 8601, 금액 원화 정수. 자동 생성 OpenAPI(`/openapi.json`, `/docs`)가 필드 계약의 기준이며 `docs/openapi.json`은 생성한 스냅샷이다. `backend` 폴더에서 `python -m app.tasks.export_contract`로 갱신한다.

인증은 `Authorization: Bearer <token>`. 가입·로그인에서 발급하며 서버에는 SHA-256 해시만 저장한다. 세션은 7일 만료, 로그아웃 즉시 폐기. 브라우저는 sessionStorage에 보관한다. 운영은 HTTPS 필수. 인증 실패 401, 권한/정책 제한 403, 없는 자원 404, 상태 충돌 409, 입력 검증 422, 외부 서비스 실패 502, 설정/DB 미준비 503. 오류는 `{ "detail": "설명" }` 형식(입력 검증은 FastAPI의 detail 배열).

| 메서드 | 경로 | 동작 |
|---|---|---|
| GET | /health, /ready | 프로세스 / MariaDB 연결 상태 |
| POST | /auth/register, /auth/login | 회원 생성 / 세션 발급 |
| POST | /auth/logout | 현재 세션 폐기 |
| GET, PATCH | /users/me | 프로필 조회 / 이름 변경 |
| PUT | /surveys/me | categories, tags 설문 교체 |
| GET | /contents | q, category, region, free_only, from_date, to_date, sort, page, size 검색 |
| GET | /contents/{id} | 상세, 조회 자체는 상태 변경 없음 |
| GET | /contents/{id}/reviews | 리뷰 목록 |
| PUT, DELETE | /contents/{id}/reviews/me | 본인 리뷰 작성·수정 / 삭제 |
| GET | /bookmarks | 본인 찜 목록 |
| PUT, DELETE | /bookmarks/{content_id} | 멱등 찜 / 취소 |
| POST | /history/events | 본인 행동 이벤트 수집(event_id UUID 중복 무시) |
| GET | /history | 본인 최근 조회 콘텐츠 |
| GET | /recommendations | 공개 인기순 / 인증 시 취향·활동 기반 및 추천 이유 |
| GET | /payments/config | 결제·환불 활성화 여부 |
| POST | /payments/orders | 서버 금액 산정, 고유 payment_id 발급, Idempotency-Key UUID 헤더 필수 |
| GET | /payments | 본인 주문·결제 이력 |
| POST | /payments/{payment_id}/verify | PortOne 재조회·검증 후 예약 확정 |
| POST | /payments/{payment_id}/cancel | 정책 활성화 시 전액 취소, 재조회·멱등 처리 |
| POST | /payments/webhook | Standard Webhooks 서명 검증·재조회, Bearer 불필요 |
| GET | /reservations | 본인 확정·취소 예약 |

목록 응답 `{items, total, page, size}`. 콘텐츠 검색 size 1–48, 페이지 1–1000. 추천 최대 24. 찜·조회 내역 최대 100. 결제/예약은 최대 100. 정렬 `latest`, `popular`, `ending`. 검색은 제목·장소 부분 일치이며 종료된 행사는 기본 제외(`include_ended=true`로 포함). 공급자 중복키 `(source, source_id)`.

주문 Idempotency-Key는 사용자별 유일하며 같은 키로 다른 상품/수량을 보내면 409. 결제는 샘플 콘텐츠에 대해 금지. 클라이언트 금액을 받지 않는다. 웹훅 수신 성공은 서버 검증/트랜잭션 완료 후 반환. 알 수 없는 이벤트 종류는 200으로 무시, 미등록 주문은 200으로 무시. 외부 장애 시 502로 재시도를 유도한다.

인증 관련 요청은 프로세스당 IP 기준 1분 20회로 제한한다. 다중 Uvicorn worker 운영 시 공유 rate limiter 도입 필요. CORS는 명시 출처만 허용하며 Vite/Nginx 프록시를 사용하지 않는다.
