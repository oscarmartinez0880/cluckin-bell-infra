import json
import boto3
import os
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

autoscaling = boto3.client('autoscaling')

def handler(event, context):
    """
    GitHub Actions webhook handler for autoscaling CI runners.
    Scales up runners when workflow jobs are queued.
    """
    try:
        # Parse webhook payload
        if 'body' in event:
            body = json.loads(event['body'])
        else:
            body = event
        
        action = body.get('action')
        workflow_job = body.get('workflow_job', {})
        
        logger.info(f"Received webhook: action={action}")
        
        # Get ASG name from environment
        asg_name = os.environ.get('ASG_NAME')
        if not asg_name:
            logger.error("ASG_NAME environment variable not set")
            return {
                'statusCode': 500,
                'body': json.dumps({'error': 'ASG_NAME not configured'})
            }
        
        # Handle workflow job events
        if action in ['queued']:
            # Check if job requires our runners
            labels = workflow_job.get('labels', [])
            if 'self-hosted' in labels and 'windows' in labels:
                logger.info("Scaling up for Windows self-hosted job")
                scale_up(asg_name)
        
        elif action in ['completed', 'cancelled']:
            # Job finished, potentially scale down (implement cooldown logic)
            logger.info("Job completed, checking for scale down")
            # Add logic to scale down if no jobs are pending
            
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Webhook processed successfully'})
        }
        
    except Exception as e:
        logger.error(f"Error processing webhook: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }

def scale_up(asg_name):
    """Scale up the autoscaling group by 1 instance."""
    try:
        # Get current ASG state
        response = autoscaling.describe_auto_scaling_groups(
            AutoScalingGroupNames=[asg_name]
        )
        
        if not response['AutoScalingGroups']:
            logger.error(f"ASG {asg_name} not found")
            return
            
        asg = response['AutoScalingGroups'][0]
        current_capacity = asg['DesiredCapacity']
        max_capacity = asg['MaxSize']
        
        # Scale up if we haven't reached max capacity
        if current_capacity < max_capacity:
            new_capacity = current_capacity + 1
            logger.info(f"Scaling up {asg_name} from {current_capacity} to {new_capacity}")
            
            autoscaling.set_desired_capacity(
                AutoScalingGroupName=asg_name,
                DesiredCapacity=new_capacity,
                HonorCooldown=False
            )
        else:
            logger.info(f"ASG {asg_name} already at max capacity ({max_capacity})")
            
    except Exception as e:
        logger.error(f"Error scaling up ASG: {str(e)}")