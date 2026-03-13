# k6 Load Testing Dashboard

GoormGB 프로젝트를 위한 부하 테스트 대시보드입니다.

## 기능

- 웹 UI에서 테스트 설정 및 실행
- 실시간 터미널 출력 (WebSocket)
- 환경별 테스트 (dev/staging/prod)
- 서비스별 타겟팅
- 5가지 테스트 시나리오
- Grafana 연동 가이드

## 테스트 시나리오

| 테스트 | 목적 | 기본 설정 |
|--------|------|----------|
| **Smoke** | 배포 후 기본 동작 확인 | 5 VUs, 1분 |
| **Load** | 일반 부하 상황 테스트 | 50 VUs, 5분 |
| **Stress** | 한계점 탐색 | 10→200 VUs, 10분 |
| **Spike** | Auto Scaling 검증 | 10→300 VUs 급증 |
| **Soak** | 장시간 안정성, 메모리 누수 탐지 | 50 VUs, 30분 |

## 실행 방법

### 로컬 실행 (Go 직접)

```bash
# 의존성 설치
make deps

# 실행
make run

# 또는 개발 모드 (hot reload)
make dev
```

브라우저에서 http://localhost:8080 접속

### Docker 실행

```bash
# 빌드 & 실행
make docker-build
make docker-run

# 로그 확인
make docker-logs

# 중지
make docker-stop
```

## CLI 직접 테스트

```bash
# Smoke Test
make test-smoke

# Load Test
make test-load

# Stress Test
make test-stress

# Spike Test (Auto Scaling 검증)
make test-spike

# Soak Test (30분)
make test-soak
```

## 환경 변수

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `PORT` | 서버 포트 | 8080 |
| `K6_PROMETHEUS_RW_SERVER_URL` | Prometheus Remote Write URL | - |

## Prometheus 연동

클러스터의 Prometheus로 메트릭을 전송하려면:

```bash
# 로컬에서 k6 실행 시
k6 run --out experimental-prometheus-rw \
  -e K6_PROMETHEUS_RW_SERVER_URL=http://<prometheus>:9090/api/v1/write \
  scripts/load.js
```

## 프로젝트 구조

```
304-goormgb-k6/
├── main.go              # Go 서버 (HTMX + WebSocket)
├── templates/
│   └── index.html       # 웹 UI
├── scripts/             # k6 테스트 스크립트
│   ├── smoke.js
│   ├── load.js
│   ├── stress.js
│   ├── spike.js
│   └── soak.js
├── Dockerfile
├── docker-compose.yml
└── Makefile
```

## Grafana 대시보드

테스트 실행 시 확인할 Grafana 대시보드:

- **k6 Load Testing Results**: VUs, RPS, 응답시간, 에러율
- **K8s Pods**: CPU/Memory 사용량, Pod 개수 변화
- **Istio Workload**: 서비스별 트래픽, 레이턴시
- **HTTP Status Analysis**: 상태 코드 분포
