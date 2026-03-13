import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');
const spikeErrors = new Counter('spike_errors');

const TARGET_URL = __ENV.TARGET_URL || 'https://dev.goormgb.com';
const SERVICE = __ENV.SERVICE || 'all';
const ENVIRONMENT = __ENV.ENVIRONMENT || 'dev';
const THRESHOLD_P95 = parseInt(__ENV.THRESHOLD_P95) || 500;
const THRESHOLD_ERROR = parseFloat(__ENV.THRESHOLD_ERROR) || 1;
const SPIKE_VUS = parseInt(__ENV.VUS) || 300;

// Spike Test Configuration
// 목적: 급격한 트래픽 증가 시 Auto Scaling (HPA/KEDA) 동작 검증
export const options = {
  stages: [
    { duration: '30s', target: 10 },      // Baseline
    { duration: '10s', target: SPIKE_VUS }, // SPIKE! 급격한 증가
    { duration: '2m', target: SPIKE_VUS },  // Hold spike
    { duration: '10s', target: 10 },       // Scale down
    { duration: '1m', target: 10 },        // Recovery observation
    { duration: '30s', target: 0 },        // Cleanup
  ],

  thresholds: {
    http_req_duration: [`p(95)<${THRESHOLD_P95 * 2}`], // Spike 시 허용치 2배
    http_req_failed: [`rate<${THRESHOLD_ERROR * 2 / 100}`], // 에러 허용치 2배
  },

  tags: {
    test_type: 'spike',
    environment: ENVIRONMENT,
    service: SERVICE,
  },
};

export default function () {
  const endpoints = [
    '/order/clubs',
    '/order/clubs/1',
    '/order/matches?date=2026-03-28',
  ];

  const path = endpoints[Math.floor(Math.random() * endpoints.length)];
  const url = `${TARGET_URL}${path}`;

  const res = http.get(url, {
    timeout: '30s',
  });

  const success = check(res, {
    'status is 2xx': (r) => r.status >= 200 && r.status < 300,
    'not rate limited (429)': (r) => r.status !== 429,
    'not server error (5xx)': (r) => r.status < 500,
  });

  if (!success) {
    spikeErrors.add(1);
  }

  errorRate.add(!success);
  responseTime.add(res.timings.duration);

  sleep(Math.random() * 0.5 + 0.1);
}

export function handleSummary(data) {
  const spikeHandled = data.metrics.http_req_failed.values.rate < 0.1; // 10% 미만이면 성공

  console.log('');
  console.log('═══════════════════════════════════════════════════════════');
  console.log('  SPIKE TEST (AUTO SCALING VERIFICATION) SUMMARY');
  console.log('═══════════════════════════════════════════════════════════');
  console.log(`  Environment: ${ENVIRONMENT} | Spike VUs: ${SPIKE_VUS}`);
  console.log('───────────────────────────────────────────────────────────');
  console.log(`  Total Requests:    ${data.metrics.http_reqs.values.count}`);
  console.log(`  Error Rate:        ${(data.metrics.http_req_failed.values.rate * 100).toFixed(2)}%`);
  console.log(`  P95 Latency:       ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms`);
  console.log(`  Max Latency:       ${data.metrics.http_req_duration.values['max'].toFixed(2)}ms`);
  console.log('───────────────────────────────────────────────────────────');
  console.log(`  Auto Scaling: ${spikeHandled ? '✓ HPA/KEDA responded well' : '✗ Check scaling config'}`);
  console.log('');
  console.log('  📊 Grafana에서 확인할 항목:');
  console.log('     • Pod 개수 변화 (k8s-pods 대시보드)');
  console.log('     • CPU/Memory 사용량 추이');
  console.log('     • HPA events (kubectl get events)');
  console.log('═══════════════════════════════════════════════════════════');
  return {};
}
