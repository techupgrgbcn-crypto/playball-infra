import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');

// Environment variables
const TARGET_URL = __ENV.TARGET_URL || 'https://dev.goormgb.com';
const SERVICE = __ENV.SERVICE || 'all';
const ENVIRONMENT = __ENV.ENVIRONMENT || 'dev';
const THRESHOLD_P95 = parseInt(__ENV.THRESHOLD_P95) || 500;
const THRESHOLD_ERROR = parseFloat(__ENV.THRESHOLD_ERROR) || 1;

// Smoke Test Configuration
// 목적: 기본 동작 확인, 빠른 검증
export const options = {
  vus: parseInt(__ENV.VUS) || 5,
  duration: __ENV.DURATION || '1m',

  thresholds: {
    http_req_duration: [`p(95)<${THRESHOLD_P95}`],
    http_req_failed: [`rate<${THRESHOLD_ERROR / 100}`],
    errors: [`rate<${THRESHOLD_ERROR / 100}`],
  },

  tags: {
    test_type: 'smoke',
    environment: ENVIRONMENT,
    service: SERVICE,
  },
};

// Service endpoints - 실제 백엔드 API 기반
const ENDPOINTS = {
  all: [
    { name: 'clubs-list', path: '/order/clubs', method: 'GET' },
    { name: 'matches-today', path: '/order/matches?date=2026-03-28', method: 'GET' },
  ],
  'api-gateway': [
    { name: 'clubs-list', path: '/order/clubs', method: 'GET' },
    { name: 'club-detail', path: '/order/clubs/1', method: 'GET' },
  ],
  'auth-guard': [
    { name: 'kakao-login-url', path: '/auth/kakao/login-url?redirectUri=https://dev.goormgb.com/callback', method: 'GET' },
  ],
  'order-core': [
    { name: 'clubs-list', path: '/order/clubs', method: 'GET' },
    { name: 'club-detail', path: '/order/clubs/1', method: 'GET' },
    { name: 'club-matches', path: '/order/clubs/1/matches?year=2026&month=3', method: 'GET' },
    { name: 'matches-today', path: '/order/matches?date=2026-03-28', method: 'GET' },
  ],
  'queue': [
    { name: 'clubs-list', path: '/order/clubs', method: 'GET' },
  ],
  'seat': [
    { name: 'clubs-list', path: '/order/clubs', method: 'GET' },
  ],
  'recommendation': [
    { name: 'clubs-list', path: '/order/clubs', method: 'GET' },
  ],
  'ai-defense': [
    { name: 'clubs-list', path: '/order/clubs', method: 'GET' },
  ],
};

export default function () {
  const endpoints = ENDPOINTS[SERVICE] || ENDPOINTS['all'];

  for (const endpoint of endpoints) {
    const url = `${TARGET_URL}${endpoint.path}`;
    const start = Date.now();

    let res;
    if (endpoint.method === 'GET') {
      res = http.get(url, {
        tags: { name: endpoint.name },
      });
    } else if (endpoint.method === 'POST') {
      res = http.post(url, JSON.stringify(endpoint.body || {}), {
        headers: { 'Content-Type': 'application/json' },
        tags: { name: endpoint.name },
      });
    }

    const duration = Date.now() - start;
    responseTime.add(duration);

    const success = check(res, {
      [`${endpoint.name} status is 2xx`]: (r) => r.status >= 200 && r.status < 300,
      [`${endpoint.name} response time < ${THRESHOLD_P95}ms`]: (r) => r.timings.duration < THRESHOLD_P95,
    });

    errorRate.add(!success);
  }

  sleep(1);
}

export function handleSummary(data) {
  const passed = data.metrics.http_req_failed.values.rate < (THRESHOLD_ERROR / 100);
  const p95 = data.metrics.http_req_duration.values['p(95)'];

  console.log('');
  console.log('═══════════════════════════════════════════════════════════');
  console.log('  SMOKE TEST SUMMARY');
  console.log('═══════════════════════════════════════════════════════════');
  console.log(`  Environment: ${ENVIRONMENT}`);
  console.log(`  Service:     ${SERVICE}`);
  console.log(`  Target:      ${TARGET_URL}`);
  console.log('───────────────────────────────────────────────────────────');
  console.log(`  Total Requests:  ${data.metrics.http_reqs.values.count}`);
  console.log(`  Failed Requests: ${Math.round(data.metrics.http_req_failed.values.rate * 100)}%`);
  console.log(`  P95 Latency:     ${p95.toFixed(2)}ms`);
  console.log('───────────────────────────────────────────────────────────');
  console.log(`  Result: ${passed ? '✓ PASSED' : '✗ FAILED'}`);
  console.log('═══════════════════════════════════════════════════════════');

  return {};
}
