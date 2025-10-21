"""
Lambda function to receive Alertmanager webhook and publish to SNS.
Formats Alertmanager payload into readable messages with severity, labels, and annotations.
"""

import json
import os
import boto3
from datetime import datetime

sns = boto3.client('sns')
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']


def format_alert_message(alert):
    """Format a single alert into a readable message."""
    labels = alert.get('labels', {})
    annotations = alert.get('annotations', {})
    
    # Extract key fields
    alertname = labels.get('alertname', 'Unknown')
    severity = labels.get('severity', 'unknown')
    env = labels.get('env', labels.get('environment', 'unknown'))
    instance = labels.get('instance', 'N/A')
    summary = annotations.get('summary', annotations.get('description', 'No summary available'))
    
    # Status and timestamps
    status = alert.get('status', 'unknown')
    starts_at = alert.get('startsAt', '')
    
    # Format message
    message = f"""
Alert: {alertname}
Status: {status.upper()}
Severity: {severity.upper()}
Environment: {env}
Instance: {instance}

Summary:
{summary}

Started At: {starts_at}

Labels: {json.dumps(labels, indent=2)}
"""
    return message.strip()


def lambda_handler(event, context):
    """
    Process Alertmanager webhook payload and publish to SNS.
    
    Expected payload format from Alertmanager:
    {
        "version": "4",
        "groupKey": "...",
        "status": "firing",
        "receiver": "...",
        "alerts": [
            {
                "status": "firing",
                "labels": {...},
                "annotations": {...},
                "startsAt": "...",
                "endsAt": "..."
            }
        ]
    }
    """
    try:
        # Parse incoming request
        body = event.get('body', '{}')
        if isinstance(body, str):
            payload = json.loads(body)
        else:
            payload = body
        
        print(f"Received payload: {json.dumps(payload)}")
        
        # Extract alerts
        alerts = payload.get('alerts', [])
        if not alerts:
            return {
                'statusCode': 200,
                'body': json.dumps({'message': 'No alerts in payload'})
            }
        
        # Process each alert
        for alert in alerts:
            message = format_alert_message(alert)
            
            # Determine subject based on severity
            labels = alert.get('labels', {})
            severity = labels.get('severity', 'unknown').upper()
            alertname = labels.get('alertname', 'Unknown')
            env = labels.get('env', labels.get('environment', 'unknown'))
            status = alert.get('status', 'unknown').upper()
            
            subject = f"[{severity}] {alertname} - {status} ({env})"
            
            # Publish to SNS
            response = sns.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=subject[:100],  # SNS subject limit
                Message=message
            )
            
            print(f"Published to SNS: MessageId={response['MessageId']}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'message': f'Successfully processed {len(alerts)} alert(s)',
                'alerts_processed': len(alerts)
            })
        }
        
    except Exception as e:
        print(f"Error processing webhook: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': str(e)
            })
        }
