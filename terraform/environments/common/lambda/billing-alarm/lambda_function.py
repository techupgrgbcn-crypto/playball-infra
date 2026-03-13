import json
import os
import urllib.request
from datetime import datetime, timedelta

import boto3


def lambda_handler(event, context):
    """AWS 비용을 Discord로 알림"""

    # 환경변수
    webhook_url = os.environ.get('DISCORD_WEBHOOK_URL')
    credit_start_date = os.environ.get('CREDIT_START_DATE', '2026-01-16')
    initial_credit = float(os.environ.get('INITIAL_CREDIT', '200.00'))
    aws_account_id = os.environ.get('AWS_ACCOUNT_ID', 'Unknown')

    # Cost Explorer 클라이언트
    ce = boto3.client('ce', region_name='us-east-1')

    # 오늘 날짜와 이번 달 시작일
    today = datetime.utcnow()
    start_of_month = today.replace(day=1).strftime('%Y-%m-%d')
    end_date = (today + timedelta(days=1)).strftime('%Y-%m-%d')

    # 이번 달 비용 조회
    response = ce.get_cost_and_usage(
        TimePeriod={
            'Start': start_of_month,
            'End': end_date
        },
        Granularity='MONTHLY',
        Metrics=['UnblendedCost']
    )

    # 비용 계산
    cost = 0.0
    for result in response['ResultsByTime']:
        cost += float(result['Total']['UnblendedCost']['Amount'])

    # 크레딧 시작일부터 경과일 계산
    credit_start = datetime.strptime(credit_start_date, '%Y-%m-%d')
    days_elapsed = (today - credit_start).days

    # 남은 크레딧 계산 (대략적)
    remaining_credit = max(0, initial_credit - cost)

    # Discord 메시지
    message = {
        "embeds": [{
            "title": "💰 AWS 일일 비용 리포트",
            "color": 0x00ff00 if cost < 10 else 0xffff00 if cost < 50 else 0xff0000,
            "fields": [
                {"name": "계정", "value": aws_account_id, "inline": True},
                {"name": "이번 달 비용", "value": f"${cost:.2f}", "inline": True},
                {"name": "남은 크레딧", "value": f"${remaining_credit:.2f}", "inline": True},
                {"name": "기준일", "value": today.strftime('%Y-%m-%d %H:%M UTC'), "inline": False}
            ],
            "footer": {"text": "goormgb AWS Billing Alert"}
        }]
    }

    # Discord 전송
    req = urllib.request.Request(
        webhook_url,
        data=json.dumps(message).encode('utf-8'),
        headers={'Content-Type': 'application/json'}
    )

    with urllib.request.urlopen(req) as res:
        pass

    return {
        'statusCode': 200,
        'body': json.dumps({'cost': cost, 'remaining_credit': remaining_credit})
    }
