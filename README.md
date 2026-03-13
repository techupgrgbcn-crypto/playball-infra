# PlayBall Infrastructure

> AWS EKS 기반 프로덕션 레벨 Kubernetes 인프라

---

## 이 저장소에 대하여

> **포트폴리오 공개용 저장소입니다.**
>
> 이 저장소는 [goorm-gongbang](https://github.com/goorm-gongbang) 조직의 비공개 인프라 레포지토리들을 **sanitize(민감정보 제거)** 하여 하나의 공개 레포지토리로 통합한 것입니다.

### 원본 저장소 (Private)

| 저장소 | 설명 | 이 레포 경로 |
|--------|------|-------------|
| `301-goormgb-terraform` | AWS 인프라 코드 (Terraform) | `/terraform` |
| `302-goormgb-k8s-bootstrap` | Kubernetes 부트스트랩 스크립트 | `/k8s-bootstrap` |
| `303-goormgb-k8s-helm` | Helm 차트 & ArgoCD 설정 | `/k8s-helm` |
| `304-goormgb-k6` | 부하 테스트 스크립트 (k6) | `/k6` |

### Sanitization 처리 항목

GitHub Actions를 통해 자동으로 다음 민감정보가 치환됩니다:

| 카테고리 | 설명 | 치환값 |
|---------|------|--------|
| AWS 계정 ID | 실제 AWS 계정 번호 | `123456789012` |
| IP 주소 | Public/Private IP | `10.0.0.x` |
| 이메일 | 팀원 개인 이메일 | `admin@example.com` |
| 노드명 | 실제 서버 호스트명 | `worker-node-1` |

**공개 유지 항목:**
- 도메인: `playball.one` (서비스 도메인)
- 조직명: `goorm-gongbang` (GitHub 조직)

> **참고**: 아키텍처와 코드 패턴은 실제 프로덕션과 동일합니다.

---

## 프로젝트 개요

**PlayBall**은 야구 경기 티켓 예매 서비스입니다. 이 저장소는 해당 서비스의 인프라를 구성하는 코드를 포함합니다.

### 주요 특징

- **Multi-Account AWS 아키텍처**: 공유 리소스(Account A)와 컴퓨팅 리소스(Account B) 분리
- **EKS 1.34 + Istio 1.29.1**: 최신 Kubernetes와 서비스 메시
- **GitOps**: ArgoCD를 통한 선언적 배포
- **완전 자동화**: Terraform + Helm + ArgoCD로 인프라부터 애플리케이션까지

---

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              인프라 아키텍처                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   [사용자]                                                                   │
│      │                                                                      │
│      ▼                                                                      │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────────────────────┐  │
│   │  CloudFront │────▶│     NLB     │────▶│        EKS Cluster          │  │
│   │  (CDN+TLS)  │     │   (L4 LB)   │     │                             │  │
│   └─────────────┘     └─────────────┘     │  ┌───────────────────────┐  │  │
│         │                                 │  │   Istio Service Mesh  │  │  │
│         │                                 │  │   - Ingress Gateway   │  │  │
│   ┌─────────────┐                         │  │   - mTLS              │  │  │
│   │  Route 53   │                         │  │   - Traffic Control   │  │  │
│   │  (DNS)      │                         │  └───────────────────────┘  │  │
│   └─────────────┘                         │                             │  │
│                                           │  ┌───────────────────────┐  │  │
│   ┌─────────────┐                         │  │      Applications     │  │  │
│   │     ECR     │◀────────────────────────│  │   - Java Services     │  │  │
│   │ (Registry)  │                         │  │   - AI Services       │  │  │
│   └─────────────┘                         │  └───────────────────────┘  │  │
│                                           │                             │  │
│                                           └─────────────────────────────┘  │
│                                                        │                    
│                                           ┌────────────┴────────────┐      │
│                                           ▼                         ▼      │
│                                    ┌───────────┐             ┌───────────┐ │
│                                    │    RDS    │             │ElastiCache│ │
│                                    │ PostgreSQL│             │   Redis   │ │
│                                    └───────────┘             └───────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Multi-Account 구조

```
┌─────────────────────────────────┐     ┌─────────────────────────────────┐
│      Account A (공유 리소스)       │     │      Account B (컴퓨팅)          │
│                                 │     │                                 │
│  - Route53 (DNS)                │     │  - VPC & 네트워크               │
│  - CloudFront (CDN)             │     │  - EKS Cluster                  │
│  - ECR (컨테이너 레지스트리)         │◀───▶│  - RDS PostgreSQL               │
│  - ACM (TLS 인증서)               │     │  - ElastiCache Redis            │
│                                 │     │  - Bastion Host                 │
└─────────────────────────────────┘     └─────────────────────────────────┘
              │                                       │
              └───────────── Cross-Account ───────────┘
                      (ECR Pull, Route53 위임)
```

---

## 기술 스택

| 카테고리 | 기술 | 버전 |
|----------|------|------|
| **클라우드** | AWS (EKS, RDS, ElastiCache, CloudFront) | - |
| **IaC** | Terraform | >= 1.0 |
| **컨테이너 오케스트레이션** | Kubernetes (EKS) | 1.34 |
| **서비스 메시** | Istio | 1.29.1 |
| **GitOps** | ArgoCD | 2.x |
| **모니터링** | Prometheus + Grafana + Loki | - |
| **시크릿 관리** | External Secrets Operator + AWS Secrets Manager | - |
| **부하 테스트** | k6 | - |

---

## 디렉토리 구조

```
playball-infra/
│
├── terraform/                  # Infrastructure as Code
│   └── environments/
│       ├── staging/
│       │   ├── base/           # Account A: Route53, CloudFront, ECR
│       │   └── computeB/       # Account B: EKS, RDS, ElastiCache
│       └── prod/
│
├── k8s-bootstrap/              # Kubernetes 부트스트랩
│   ├── Makefile                # 설치 명령어
│   ├── scripts/
│   │   ├── istio/              # Istio 설치 스크립트
│   │   ├── monitoring/         # 모니터링 설정
│   │   └── calico/             # CNI 설정
│   └── manifests/              # K8s 매니페스트
│
├── k8s-helm/                   # Helm 차트 & ArgoCD
│   ├── common-charts/
│   │   ├── apps/               # 애플리케이션 차트
│   │   │   ├── java-service/   # Spring Boot 템플릿
│   │   │   └── ai-service/     # Python AI 서비스 템플릿
│   │   └── infra/              # 인프라 차트
│   │       ├── istio/
│   │       ├── monitoring/
│   │       └── argocd/
│   ├── dev/                    # 개발 환경 (On-Premise)
│   ├── staging/                # 스테이징 환경 (AWS)
│   └── prod/                   # 프로덕션 환경
│
├── k6/                         # 부하 테스트
│   ├── scripts/
│   │   ├── smoke.js            # 스모크 테스트
│   │   ├── load.js             # 부하 테스트
│   │   ├── stress.js           # 스트레스 테스트
│   │   ├── spike.js            # 스파이크 테스트
│   │   └── soak.js             # 내구성 테스트
│   ├── main.go                 # 대시보드 서버
│   └── Makefile
│
└── docs/                       # 문서
```

---

## 주요 기능

### 1. Infrastructure as Code
- **Terraform**으로 모든 AWS 리소스 관리
- 모듈화된 구조로 재사용성 확보
- S3 + DynamoDB를 활용한 원격 상태 관리

### 2. GitOps 배포
- **ArgoCD** App of Apps 패턴 적용
- Git 커밋 시 자동 동기화
- 환경별 브랜치 분리 (dev/staging/prod)

### 3. 서비스 메시
- **Istio**를 통한 트래픽 관리
- 서비스 간 mTLS 암호화
- Rate Limiting, Circuit Breaker 적용

### 4. 관측성 (Observability)
- **Prometheus**: 메트릭 수집
- **Grafana**: 시각화 대시보드
- **Loki**: 로그 집계
- 커스텀 애플리케이션 대시보드

### 5. 보안
- AWS Secrets Manager + External Secrets Operator
- IRSA (IAM Roles for Service Accounts)
- Network Policy 및 Security Group
- 최소 권한 원칙의 Cross-Account 접근

### 6. 부하 테스트 (k6)
- **Smoke Test**: 기본 기능 검증
- **Load Test**: 예상 트래픽 부하 테스트
- **Stress Test**: 한계점 파악
- **Spike Test**: 급격한 트래픽 증가 대응
- **Soak Test**: 장시간 안정성 테스트
- Go 기반 실시간 대시보드 제공

---

## 배포 흐름

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   GitHub    │────▶│   ArgoCD    │────▶│  Kubernetes │────▶│   Running   │
│   (코드)    │     │   (GitOps)  │     │   (EKS)     │     │   Pods      │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
      │                    │                   │
      │              ┌─────┴─────┐             │
      │              │   Helm    │             │
      │              │   Charts  │             │
      │              └───────────┘             │
      │                                        │
      ▼                                        ▼
┌─────────────┐                         ┌─────────────┐
│  Terraform  │────────────────────────▶│     AWS     │
│   (IaC)     │                         │  Resources  │
└─────────────┘                         └─────────────┘
```

---

## 시작하기

### 사전 요구사항

- AWS CLI (프로필 설정 완료)
- Terraform >= 1.0
- kubectl
- Helm 3.x

### 빠른 시작

```bash
# 1. 인프라 프로비저닝
cd terraform/environments/staging/computeB
terraform init
terraform apply

# 2. EKS 연결
aws eks update-kubeconfig --name <cluster-name> --region ap-northeast-2

# 3. ArgoCD 애플리케이션 확인 (자동 동기화)
kubectl get applications -n argocd
```

---

## 팀

**구름공방 (Goorm Gongbang)** - Infrastructure & DevOps Team

- 원본 조직: [github.com/goorm-gongbang](https://github.com/goorm-gongbang)

---

## 라이선스

MIT License - [LICENSE](./LICENSE) 참조

---

<p align="center">
  <i>이 저장소는 포트폴리오 목적으로 민감정보를 제거한 공개 버전입니다.</i><br>
  <i>실제 인프라는 프로덕션 환경에서 운영 중입니다.</i>
</p>
