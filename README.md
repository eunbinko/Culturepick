# CulturePick

전시·공연을 탐색하고 취향 설문과 조회·찜 활동으로 문화를 추천하는 React + FastAPI 서비스입니다. MariaDB가 서비스 상태와 행동 이벤트의 기준 저장소입니다.

구현 범위: 회원가입·로그인·로그아웃, 프로필, 취향 설문, 검색·분야·지역·기간·무료 필터와 페이지 이동, 상세, 찜, 리뷰·평점, 최근 조회, 추천 이유, 주문·예약·결제 내역, PortOne V2 브라우저 결제·서버 검증·서명 웹훅·전액 취소, 문화포털 수집기와 반복 실행.

잔여 좌석·매수와 무료 크레딧은 구현하지 않습니다. MongoDB는 도입하지 않았습니다. 취소·환불 정책 미확정에 따라 결제와 환불은 기본 비활성화이며 [결제 명세](docs/payment-spec.md)를 확정한 후 켭니다.

## 시작하기

자세한 DB 이름·계정 권한·주소·키·배포 경로와 수정 위치는 **[환경 설정 안내](docs/setup.md)** 에 정리했습니다. 실제 비밀번호는 `.env`에만 입력하고 공유하지 마세요.

아래 명령은 프로젝트 루트의 PowerShell에서 시작하고, 백엔드 실행 전에 `backend` 폴더로 이동합니다. Python 3.14 / Node 24 / MariaDB 11.4로 검증했습니다.

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item backend/.env.example backend/.env
Copy-Item frontend/.env.example frontend/.env
# 위 .env의 플레이스홀더를 docs/setup.md에 따라 교체하고 DB/계정을 먼저 생성합니다.

cd backend
python -m alembic upgrade head
python -m app.tasks.seed   # 선택: 가상 샘플 12개, 계정 생성 없음
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

다른 터미널에서는 프로젝트 루트에서 실행합니다:

```powershell
npm --prefix frontend ci
npm run dev
```

프론트엔드 `http://localhost:5173`, Swagger `http://localhost:8000/docs`. 브라우저가 백엔드에 직접 요청하며 Vite/Nginx API 프록시는 없습니다. 회원가입 후 바로 체험할 수 있습니다.

백엔드 코드는 `backend/app/`에서 관리하며, 백엔드 서버와 `python -m app.tasks.*` 명령은 `backend` 폴더에서 실행합니다. `.env`는 `backend/.env`에서 읽습니다. 프로젝트 루트에서 백엔드를 실행하려면 `uvicorn --app-dir backend app.main:app --host 0.0.0.0 --port 8000`을 사용하세요. 프론트엔드 루트 npm 명령은 `frontend/`의 스크립트를 실행합니다.

## 이 작업 환경에서 준비한 실행 상태

- 프론트엔드: `http://localhost:5173` (빌드 결과를 Vite preview로 제공)
- 백엔드: `http://localhost:8000`, MariaDB 개발 DB: `127.0.0.1:13306/culturepick`
- 자동 생성된 개발 계정 정보는 `backend/.env`, 별도 테스트 DB 정보는 `.runtime/test.env`에 있습니다. 두 파일은 Git 제외입니다.
- `100.100.100.130:3306`은 TCP 연결 확인만 했습니다. 원격 DB 계정이 없어 원격 인증·스키마 변경은 수행하지 않았습니다.
- MariaDB 포터블 바이너리 `.tools/`, 데이터 `.runtime/`는 Git 제외입니다. 종료/재부팅 후 `scripts/start-local-db.ps1`로 같은 DB를 시작할 수 있습니다. 이 보조 스크립트는 이번 환경에 이미 내려받은 바이너리를 사용합니다.
- 이 에이전트의 파일 샌드박스에서는 Vite 개발 최적화기의 상위 디렉터리 접근이 제한됩니다. 루트에서 `npm run build` 후 `npm run preview`는 정상 동작합니다. 일반 로컬 환경은 `npm run dev`를 사용하세요.

## 검증

별도 MariaDB 스키마 이름은 반드시 `_test`로 끝나야 합니다. 테스트는 해당 DB의 테이블 데이터를 비우므로 개발·운영 DB를 지정하지 마세요. `TEST_DATABASE_URL` 환경변수 또는 이번 환경의 `.runtime/test.env`를 사용합니다.

```powershell
# 터미널 1, 저장소 루트. Postman CLI 1.73.0으로 검증.
postman simulation run postman/simulations/upstreams.sim.yaml --port 4010 --no-history --output ndjson

# 터미널 2
$env:RUN_UPSTREAM_TESTS = '1'
python -m pytest -c backend/pytest.ini -q
python -m alembic -c backend/alembic.ini check

npm run build
```

외부 HTTP 시뮬레이션 없이 내부 동작만 검증하려면 `RUN_UPSTREAM_TESTS`를 해제하고 pytest를 실행합니다. 실제 PortOne PG 승인·취소와 문화포털 키 인증은 검증하지 않았습니다. 구체적인 범위는 [검증 기록](docs/testing.md)을 확인하세요.

## 문서

- [요구사항](docs/requirements.md), [API 명세](docs/api-spec.md), [OpenAPI 스냅샷](docs/openapi.json)
- [ERD](docs/erd.md), [데이터 사전](docs/data-dictionary.md), [이벤트 계약](docs/event-contract.md)
- [결제 명세와 미확정 정책](docs/payment-spec.md), [데이터 품질·수집](docs/data-quality.md)
- [환경·배포 설정](docs/setup.md), [검증 기록](docs/testing.md)

`backend` 폴더에서 `python -m app.tasks.export_contract`는 OpenAPI를, `python -m app.tasks.export_schema`는 참고 DDL을 재생성합니다.
