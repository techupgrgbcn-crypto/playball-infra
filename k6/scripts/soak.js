import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');
const memoryLeakIndicator = new Counter('potential_memory_leak');

const TARGET_URL = __ENV.TARGET_URL || 'https://dev.goormgb.com';
const SERVICE = __ENV.SERVICE || 'all';
const ENVIRONMENT = __ENV.ENVIRONMENT || 'dev';
const THRESHOLD_P95 = parseInt(__ENV.THRESHOLD_P95) || 500;
const THRESHOLD_ERROR = parseFloat(__ENV.THRESHOLD_ERROR) || 1;
const VUS = parseInt(__ENV.VUS) || 50;
const DURATION = __ENV.DURATION || '30m';

// Soak Test Configuration
// 목적: 장시간 일정 부하로 메모리 누수, 커넥션 풀 고갈, GC 이슈 탐지
export const options = {
  stages: [
    { duration: '2m', target: VUS },      // Ramp up
    { duration: DURATION, target: VUS },  // Sustained load
    { duration: '2m', target: 0 },        // Ramp down
  ],

  thresholds: {
    http_req_duration: [`p(95)<${THRESHOLD_P95}`],
    http_req_failed: [`rate<${THRESHOLD_ERROR / 100}`],
  },

  tags: {
    test_type: 'soak',
    environment: ENVIRONMENT,
    service: SERVICE,
  },
};

let baselineLatency = null;
let latencyDegradationCount = 0;

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
  });

  errorRate.add(!success);
  responseTime.add(res.timings.duration);

  // 메모리 누수 감지: 시간이 지남에 따라 응답시간이 점점 증가하면 의심
  if (baselineLatency === null && res.timings.duration < 1000) {
    baselineLatency = res.timings.duration;
  } else if (baselineLatency && res.timings.duration > baselineLatency * 3) {
    latencyDegradationCount++;
    if (latencyDegradationCount > 100) {
      memoryLeakIndicator.add(1);
    }
  }

  sleep(Math.random() * 2 + 1); // 1~3초 대기 (장시간 테스트이므로 여유있게)
}

export function handleSummary(data) {
  const iterations = data.metrics.iterations.values.count;
  const avgLatency = data.metrics.http_req_duration.values['avg'];
  const p95Latency = data.metrics.http_req_duration.values['p(95)'];
  const errorPct = (data.metrics.http_req_failed.values.rate * 100).toFixed(2);

  console.log('');
  console.log('═══════════════════════════════════════════════════════════');
  console.log('  SOAK TEST (STABILITY / MEMORY LEAK DETECTION) SUMMARY');
  console.log('═══════════════════════════════════════════════════════════');
  console.log(`  Environment: ${ENVIRONMENT} | Duration: ${DURATION}`);
  console.log(`  Sustained VUs: ${VUS}`);
  console.log('───────────────────────────────────────────────────────────');
  console.log(`  Total Iterations: ${iterations}`);
  console.log(`  Total Requests:   ${data.metrics.http_reqs.values.count}`);
  console.log(`  Avg RPS:          ${data.metrics.http_reqs.values.rate.toFixed(2)}`);
  console.log(`  Error Rate:       ${errorPct}%`);
  console.log('───────────────────────────────────────────────────────────');
  console.log(`  Avg Latency:      ${avgLatency.toFixed(2)}ms`);
  console.log(`  P95 Latency:      ${p95Latency.toFixed(2)}ms`);
  console.log(`  Max Latency:      ${data.metrics.http_req_duration.values['max'].toFixed(2)}ms`);
  console.log('───────────────────────────────────────────────────────────');
  console.log('');
  console.log('  📊 Grafana에서 확인할 항목:');
  console.log('     • 메모리 사용량 추이 (점진적 증가 = 누수 의심)');
  console.log('     • GC 빈도 및 pause time');
  console.log('     • DB 커넥션 풀 사용량');
  console.log('     • 응답시간 추세 (점진적 증가 = 성능 저하)');
  console.log('     • Pod restart 횟수');
  console.log('═══════════════════════════════════════════════════════════');
  return {};
}
