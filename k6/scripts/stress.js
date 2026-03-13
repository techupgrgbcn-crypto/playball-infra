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
const MAX_VUS = parseInt(__ENV.VUS) || 200;

// Stress Test Configuration
// 목적: 점진적으로 부하를 증가시켜 시스템의 한계점 탐색
export const options = {
  stages: [
    { duration: '2m', target: Math.round(MAX_VUS * 0.1) },   // 10% - Warm up
    { duration: '3m', target: Math.round(MAX_VUS * 0.5) },   // 50% - Normal load
    { duration: '3m', target: MAX_VUS },                      // 100% - Stress
    { duration: '2m', target: Math.round(MAX_VUS * 1.5) },   // 150% - Beyond capacity
    { duration: '2m', target: 0 },                            // Recovery
  ],

  thresholds: {
    http_req_duration: [`p(95)<${THRESHOLD_P95}`],
    http_req_failed: [`rate<${THRESHOLD_ERROR / 100}`],
  },

  tags: {
    test_type: 'stress',
    environment: ENVIRONMENT,
    service: SERVICE,
  },
};

export default function () {
  const endpoints = [
    '/order/clubs',
    '/order/clubs/1',
    '/order/matches?date=2026-03-28',
    '/order/clubs/1/matches?year=2026&month=3',
  ];

  const path = endpoints[Math.floor(Math.random() * endpoints.length)];
  const url = `${TARGET_URL}${path}`;

  const res = http.get(url);

  const success = check(res, {
    'status is 2xx': (r) => r.status >= 200 && r.status < 300,
    'no timeout': (r) => r.timings.duration < 30000,
  });

  errorRate.add(!success);
  responseTime.add(res.timings.duration);

  sleep(Math.random() * 1 + 0.1);
}

export function handleSummary(data) {
  console.log('');
  console.log('═══════════════════════════════════════════════════════════');
  console.log('  STRESS TEST SUMMARY');
  console.log('═══════════════════════════════════════════════════════════');
  console.log(`  Environment: ${ENVIRONMENT} | Max VUs: ${MAX_VUS}`);
  console.log('───────────────────────────────────────────────────────────');
  console.log(`  Total Requests:    ${data.metrics.http_reqs.values.count}`);
  console.log(`  Peak RPS:          ${data.metrics.http_reqs.values.rate.toFixed(2)}`);
  console.log(`  Error Rate:        ${(data.metrics.http_req_failed.values.rate * 100).toFixed(2)}%`);
  console.log(`  P95 Latency:       ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms`);
  console.log(`  Max Latency:       ${data.metrics.http_req_duration.values['max'].toFixed(2)}ms`);
  console.log('───────────────────────────────────────────────────────────');
  console.log('  💡 Check Grafana for breaking point visualization');
  console.log('═══════════════════════════════════════════════════════════');
  return {};
}
