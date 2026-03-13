# 302-myproject-k8s-bootstrap

kubeadm 클러스터(dev 환경)에 ArgoCD 환경을 구성하는 부트스트랩 스크립트.

## 환경별 클러스터 구성

| 환경    | 클러스터 | 구성 방법                                  |
| ------- | -------- | ------------------------------------------ |
| dev     | kubeadm  | 이 레포 (302-myproject-k8s-bootstrap)        |
| staging | EKS      | 301-myproject-terraform (EKS Blueprint)      |
| prod    | EKS      | 301-myproject-terraform (EKS Blueprint)      |

- **dev**: kubeadm 기반 온프레미스 클러스터로, 이 레포의 스크립트로 부트스트랩
- **staging/prod**: AWS EKS로, Terraform EKS Blueprint에서 Add-on으로 구성

## 레포 역할

```
┌────────────────────────────────────────────────────────────────────────────┐
│  301-myproject-terraform        │  302 (이 레포)      │  303-myproject-k8s-helm  │
│  ─────────────────────        │  ──────────────   │  ───────────────────── │
│  EKS 클러스터 프로비저닝           │  kubeadm 클러스터   │  GitOps 배포            │
│  (staging/prod)               │  부트스트랩(dev)     │  (ArgoCD가 watch)      │
│  - EKS Blueprint              │  - 1회 실행         │  - 모든 환경             │
│  - Add-on: ArgoCD, Istio, etc.│  - CNI, ESO, etc  │  - Helm 차트            │
└────────────────────────────────────────────────────────────────────────────┘
```

부트스트랩 실행 후, 모든 애플리케이션 변경은 303 레포에서 Git push로 진행합니다.

## 설치 항목 (kubeadm/dev 전용)

- Calico CNI (kubeadm 필수)
- Local Path Provisioner (StorageClass)
- External Secrets Operator (ESO)
- cert-manager
- Istio
- Prometheus Operator CRDs
- ArgoCD + Root Application

## 사용법

### 전체 설치

```bash
git clone git@github.com:my-organization/302-myproject-k8s-bootstrap.git
cd 302-myproject-k8s-bootstrap

make install-all
```

### 개별 설치

```bash
make help                 # 명령어 목록

make install-calico       # Calico CNI (kubeadm 필수)
make install-storage      # Local Path Provisioner
make install-eso          # External Secrets Operator
make bootstrap-aws        # AWS credentials 등록 (대화형)
make install-cert-manager
make install-istio
make install-prometheus-crds
make install-argocd
make deploy-root-app      # ArgoCD Root Application
```

### 유틸리티

```bash
make ddns-update          # DDNS 수동 업데이트
make ddns-test            # Route53 API 테스트
make rbac-create-users    # 팀원 kubeconfig 생성
make fix-port-conflict    # 80/443 포트 충돌 해결
```

### 정리

```bash
make clean-apps           # 앱 정리 (ArgoCD, cert-manager 유지)
make clean-all            # 완전 초기화 (전체 삭제, kubeadm 유지)
```

## 디렉토리 구조

```
.
├── Makefile                    # 설치 명령어 모음
├── scripts/
│   ├── calico/install.sh       # Calico CNI
│   ├── storage/install.sh      # Local Path Provisioner
│   ├── argocd/install.sh       # ArgoCD Helm 설치
│   ├── cert-manager/install.sh
│   ├── eso/
│   │   ├── install.sh
│   │   └── bootstrap-aws.sh
│   ├── istio/
│   │   ├── install.sh
│   │   └── fix-port-conflict.sh
│   ├── monitoring/
│   │   ├── install-crds.sh     # Prometheus CRDs
│   │   └── enable-etcd-metrics.sh
│   ├── rbac/
│   │   └── create-all-users.sh
│   ├── ddns/
│   │   ├── test-api.sh
│   │   └── update-now.sh
│   ├── clean-apps.sh
│   └── clean-all.sh
├── argo-init/
│   ├── root-application.yaml   # App of Apps (303 레포의 dev/root 참조)
│   └── external-secret-*.yaml
└── manifests/
    └── kubeadm 관련 매니페스트
```

## 설치 후 확인

```bash
# ArgoCD UI
https://argocd.example.dev

# Application 상태
kubectl get applications -n argocd

# Pod 상태
kubectl get pods -A
```

## 관련 레포

| 레포 | 용도 |
| ---- | ---- |
| [301-myproject-terraform](https://github.com/my-organization/301-myproject-terraform) | EKS 클러스터 (staging/prod) - EKS Blueprint |
| **302-myproject-k8s-bootstrap** | kubeadm 부트스트랩 (dev) |
| [303-myproject-k8s-helm](https://github.com/my-organization/303-myproject-k8s-helm) | GitOps Helm 차트 (모든 환경) |
