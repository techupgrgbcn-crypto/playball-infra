import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');

const TARGET_URL = __ENV.TARGET_URL || 'https://dev.goormgb.com';
const SERVICE = __ENV.SERVICE || 'all';
const ENVIRONMENT = __ENV.ENVIRONMENT || 'dev';
const THRESHOLD_P95 = parseInt(__ENV.THRESHOLD_P95) || 500;
const THRESHOLD_ERROR = parseFloat(__ENV.THRESHOLD_ERROR) || 1;

// Load Test Configuration
// 목적: 일반적인 부하 상황에서 시스템 성능 측정
export const options = {
  stages: [
    { duration: '1m', target: parseInt(__ENV.VUS) || 50 },   // Ramp-up
    { duration: __ENV.DURATION || '5m', target: parseInt(__ENV.VUS) || 50 }, // Steady state
    { duration: '30s', target: 0 },  // Ramp-down
  ],

  thresholds: {
    http_req_duration: [`p(95)<${THRESHOLD_P95}`],
    http_req_failed: [`rate<${THRESHOLD_ERROR / 100}`],
  },

  tags: {
    test_type: 'load',
    environment: ENVIRONMENT,
    service: SERVICE,
  },
};

const ENDPOINTS = {
  all: [
    { name: 'clubs-list', path: '/order/clubs', method: 'GET', weight: 30 },
    { name: 'club-detail', path: '/order/clubs/1', method: 'GET', weight: 20 },
    { name: 'matches-today', path: '/order/matches?date=2026-03-28', method: 'GET', weight: 30 },
    { name: 'club-matches', path: '/order/clubs/1/matches?year=2026&month=3', method: 'GET', weight: 20 },
  ],
  'order-core': [
    { name: 'clubs-list', path: '/order/clubs', method: 'GET', weight: 25 },
    { name: 'club-detail', path: '/order/clubs/1', method: 'GET', weight: 25 },
    { name: 'matches-today', path: '/order/matches?date=2026-03-28', method: 'GET', weight: 25 },
    { name: 'club-matches', path: '/order/clubs/1/matches?year=2026&month=3', method: 'GET', weight: 25 },
  ],
  'auth-guard': [
    { name: 'kakao-login-url', path: '/auth/kakao/login-url?redirectUri=https://dev.goormgb.com/callback', method: 'GET', weight: 100 },
  ],
};

function weightedRandom(endpoints) {
  const totalWeight = endpoints.reduce((sum, e) => sum + (e.weight || 1), 0);
  let random = Math.random() * totalWeight;

  for (const endpoint of endpoints) {
    random -= endpoint.weight || 1;
    if (random <= 0) return endpoint;
  }
  return endpoints[0];
}

export default function () {
  const endpoints = ENDPOINTS[SERVICE] || ENDPOINTS['all'];
  const endpoint = weightedRandom(endpoints);

  const url = `${TARGET_URL}${endpoint.path}`;
  const start = Date.now();

  const res = http.get(url, {
    tags: { name: endpoint.name },
  });

  const duration = Date.now() - start;
  responseTime.add(duration);

  const success = check(res, {
    'status is 2xx': (r) => r.status >= 200 && r.status < 300,
    [`latency < ${THRESHOLD_P95}ms`]: (r) => r.timings.duration < THRESHOLD_P95,
  });

  errorRate.add(!success);
  sleep(Math.random() * 2 + 0.5); // 0.5~2.5초 랜덤 대기
}

export function handleSummary(data) {
  console.log('');
  console.log('═══════════════════════════════════════════════════════════');
  console.log('  LOAD TEST SUMMARY');
  console.log('═══════════════════════════════════════════════════════════');
  console.log(`  Environment: ${ENVIRONMENT} | Service: ${SERVICE}`);
  console.log('───────────────────────────────────────────────────────────');
  console.log(`  Total Requests:    ${data.metrics.http_reqs.values.count}`);
  console.log(`  RPS (avg):         ${data.metrics.http_reqs.values.rate.toFixed(2)}`);
  console.log(`  Error Rate:        ${(data.metrics.http_req_failed.values.rate * 100).toFixed(2)}%`);
  console.log(`  P50 Latency:       ${data.metrics.http_req_duration.values['p(50)'].toFixed(2)}ms`);
  console.log(`  P95 Latency:       ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms`);
  console.log(`  P99 Latency:       ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms`);
  console.log('═══════════════════════════════════════════════════════════');
  return {};
}
