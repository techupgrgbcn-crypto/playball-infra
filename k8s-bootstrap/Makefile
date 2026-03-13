# 302-goormgb-k8s-bootstrap Makefile
# kubeadm 클러스터 초기 설정을 위한 명령어 모음

.PHONY: help install-all install-calico install-calico-legacy install-storage install-eso install-cert-manager install-istio install-argocd \
        deploy-root-app setup-github-ssh setup-etcd-secret wait-sync run-ddns run-ecr-creds clean-apps clean-all fix-port-conflict \
        rbac-create-users ddns-test ddns-update install-prometheus-crds

# 기본 타겟
help:
	@echo "=== kubeadm Bootstrap Commands ==="
	@echo ""
	@echo "초기 설치 (순서대로):"
	@echo "  make install-all       - 전체 설치 (Calico → Storage → ESO → cert-manager → Istio → ArgoCD → Root App)"
	@echo ""
	@echo "개별 설치:"
	@echo "  make install-calico    - Calico CNI 설치 (Helm, ArgoCD 관리 가능)"
	@echo "  make install-calico-legacy - Calico CNI 설치 (raw manifest, 레거시)"
	@echo "  make install-storage   - Local Path Provisioner 설치 (StorageClass)"
	@echo "  make install-eso       - External Secrets Operator 설치"
	@echo "  make bootstrap-aws     - AWS credentials 등록 (수동 입력)"
	@echo "  make install-cert-manager - cert-manager 설치"
	@echo "  make install-istio     - Istio 설치"
	@echo "  make install-prometheus-crds - Prometheus Operator CRD 설치"
	@echo "  make install-argocd    - ArgoCD 설치"
	@echo "  make setup-github-ssh  - GitHub SSH Key 설정 (ExternalSecret)"
	@echo "  make deploy-root-app   - ArgoCD Root Application 배포"
	@echo ""
	@echo "유틸리티:"
	@echo "  make fix-port-conflict - 80/443 포트 충돌 해결"
	@echo "  make rbac-create-users - 팀원 kubeconfig 생성"
	@echo "  make ddns-test         - Route53 API 테스트"
	@echo "  make ddns-update       - DDNS 수동 업데이트"
	@echo ""
	@echo "정리:"
	@echo "  make clean-apps        - 앱 정리 (ArgoCD, cert-manager 유지)"
	@echo "  make clean-all         - 완전 초기화 (ArgoCD 포함 전부 삭제, kubeadm 유지)"

# === 전체 설치 ===
install-all: install-calico install-storage install-eso bootstrap-aws install-cert-manager install-istio install-prometheus-crds install-argocd setup-github-ssh deploy-root-app setup-etcd-secret wait-sync run-ecr-creds run-ddns
	@echo ""
	@echo "=== All components installed ==="
	@echo ""
	@echo "ArgoCD UI:"
	@echo "  URL: https://argocd.goormgb.space"
	@echo ""
	@echo "Login 방법:"
	@echo "  1. Google OAuth (등록된 이메일만 접근 가능)"
	@echo "  2. admin 계정:"
	@echo "     kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"

wait-sync:
	@echo "=== Waiting for ArgoCD to sync apps (120s) ==="
	@sleep 10
	@echo "Waiting for root-dev app to sync..."
	@for i in 1 2 3 4 5 6 7 8 9 10 11 12; do \
		health=$$(kubectl get application root-dev -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null); \
		sync=$$(kubectl get application root-dev -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null); \
		if [ "$$health" = "Healthy" ] && [ "$$sync" = "Synced" ]; then \
			echo "  root-dev: Synced + Healthy"; \
			break; \
		fi; \
		echo "  Waiting... ($$i/12) [sync=$$sync, health=$$health]"; \
		sleep 10; \
	done
	@echo "Waiting for argocd-config to be created and synced..."
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		if kubectl get application argocd-config -n argocd &>/dev/null; then \
			sync=$$(kubectl get application argocd-config -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null); \
			if [ "$$sync" = "Synced" ]; then \
				echo "argocd-config synced!"; \
				break; \
			fi; \
		fi; \
		echo "  Waiting... ($$i/10)"; \
		sleep 5; \
	done
	@echo "Restarting ArgoCD server to load OIDC config..."
	@kubectl rollout restart deployment argocd-server -n argocd
	@kubectl rollout status deployment argocd-server -n argocd --timeout=60s
	@echo "Checking app health..."
	@kubectl get app -n argocd -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status' 2>/dev/null | head -20
	@echo "Syncing OutOfSync apps..."
	@kubectl annotate app istiod -n argocd argocd.argoproj.io/refresh=hard --overwrite 2>/dev/null || true
	@kubectl annotate app cert-manager-config -n argocd argocd.argoproj.io/refresh=hard --overwrite 2>/dev/null || true
	@kubectl annotate app istio-base -n argocd argocd.argoproj.io/refresh=hard --overwrite 2>/dev/null || true
	@sleep 5

run-ecr-creds:
	@echo "=== Running ECR Creds Refresh ==="
	@kubectl wait --for=condition=Healthy application/ecr-creds -n argocd --timeout=120s 2>/dev/null || true
	@kubectl create job --from=cronjob/ecr-creds-12h-refresher ecr-init-$$(date +%s) -n infra 2>/dev/null || true
	@echo "Waiting for ECR creds job..."
	@sleep 10
	@kubectl get secret -n dev-webs 2>/dev/null | grep -q ecr && echo "ECR secret created in dev-webs" || echo "ECR secret not yet created. Run 'make run-ecr-creds' later."

run-ddns:
	@echo "=== Running DDNS Update ==="
	@./scripts/ddns/update-now.sh || echo "DDNS update skipped (CronJob may not be ready yet). Run 'make ddns-update' later."

# === 개별 설치 ===
install-calico:
	@echo "=== Installing Calico CNI (Helm) ==="
	./scripts/calico/install-helm.sh

install-calico-legacy:
	@echo "=== Installing Calico CNI (Legacy) ==="
	./scripts/calico/install.sh

install-storage:
	@echo "=== Installing Local Path Provisioner ==="
	./scripts/storage/install.sh

install-eso:
	@echo "=== Installing ESO ==="
	./scripts/eso/install.sh

bootstrap-aws:
	@echo "=== Bootstrapping AWS credentials ==="
	./scripts/eso/bootstrap-aws.sh

install-cert-manager:
	@echo "=== Installing cert-manager ==="
	./scripts/cert-manager/install.sh

install-istio:
	@echo "=== Installing Istio ==="
	./scripts/istio/install.sh

install-prometheus-crds:
	@echo "=== Installing Prometheus Operator CRDs ==="
	./scripts/monitoring/install-crds.sh

install-argocd:
	@echo "=== Installing ArgoCD ==="
	./scripts/argocd/install.sh

setup-github-ssh:
	@echo "=== Setting up GitHub SSH Key (ExternalSecret) ==="
	kubectl apply -f argo-init/external-secret-github.yaml
	@echo "Waiting for ExternalSecret to sync..."
	@sleep 5
	@kubectl get externalsecret repo-goormgb-helm -n argocd || echo "ExternalSecret not ready yet. Check: kubectl get externalsecret -n argocd"

deploy-root-app:
	@echo "=== Deploying Root Application ==="
	kubectl apply -f argo-init/root-application.yaml
	@echo "Waiting for root app to be created..."
	@sleep 5
	@echo "Triggering root app refresh..."
	@kubectl annotate application root-dev -n argocd argocd.argoproj.io/refresh=normal --overwrite 2>/dev/null || true
	@echo "Waiting for apps to be created (90s)..."
	@for i in 1 2 3 4 5 6 7 8 9; do \
		echo "  Checking... ($$i/9)"; \
		kubectl get app -n argocd 2>/dev/null | head -15; \
		sleep 10; \
	done
	@echo ""
	@echo "Root Application deployed and synced."

setup-etcd-secret:
	@echo "=== Setting up etcd monitoring ==="
	@chmod +x ./scripts/monitoring/enable-etcd-metrics.sh
	@./scripts/monitoring/enable-etcd-metrics.sh
	@chmod +x ./scripts/monitoring/create-etcd-secret.sh
	@./scripts/monitoring/create-etcd-secret.sh

# === 유틸리티 ===
fix-port-conflict:
	./scripts/istio/fix-port-conflict.sh

rbac-create-users:
	./scripts/rbac/create-all-users.sh

ddns-test:
	./scripts/ddns/test-api.sh

ddns-update:
	./scripts/ddns/update-now.sh

# === 정리 ===
clean-apps:
	./scripts/clean-apps.sh

clean-all:
	./scripts/clean-all.sh
