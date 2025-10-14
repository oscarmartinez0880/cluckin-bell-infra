"""
EKS Nodegroup Scaler Lambda Function

This Lambda function scales EKS managed nodegroups up or down based on the
provided action. It's designed to reduce costs by scaling down dev/qa environments
during off-hours.

Event format:
{
    "action": "scale_up" | "scale_down",
    "cluster_name": "cluckn-bell-nonprod",  # optional, uses env var if not provided
    "nodegroups": ["ng-1", "ng-2"],         # optional, uses env var or auto-discovers all if empty
    "wait_for_active": false                # optional, defaults to false
}

Auto-discovery:
- If nodegroups is empty or not provided, the function will list all managed nodegroups
  in the cluster and scale them all.
- This eliminates the need to hardcode nodegroup names.
"""

import os
import json
import time
import boto3
from botocore.exceptions import ClientError

# Initialize EKS client
eks = boto3.client('eks')

def handler(event, context):
    """
    Main Lambda handler function.
    
    Args:
        event: Lambda event containing action and optional parameters
        context: Lambda context object
    
    Returns:
        dict: Response with status and details
    """
    print(f"Received event: {json.dumps(event)}")
    
    # Extract parameters from event or environment variables
    action = event.get('action')
    if not action:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing required parameter: action'})
        }
    
    if action not in ['scale_up', 'scale_down']:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': f'Invalid action: {action}. Must be scale_up or scale_down'})
        }
    
    cluster_name = event.get('cluster_name', os.environ.get('CLUSTER_NAME'))
    nodegroups_env = os.environ.get('NODEGROUPS', '[]')
    nodegroups = event.get('nodegroups', json.loads(nodegroups_env.strip()) if nodegroups_env and nodegroups_env.strip() else [])
    wait_for_active = event.get('wait_for_active', os.environ.get('WAIT_FOR_ACTIVE', 'false').lower() == 'true')
    
    if not cluster_name:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing required parameter: cluster_name'})
        }
    
    # Auto-discover nodegroups if not specified
    if not nodegroups:
        try:
            print(f"No nodegroups specified, auto-discovering all managed nodegroups in cluster {cluster_name}...")
            response = eks.list_nodegroups(clusterName=cluster_name)
            nodegroups = response.get('nodegroups', [])
            print(f"Discovered {len(nodegroups)} nodegroups: {nodegroups}")
            
            if not nodegroups:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': f'No managed nodegroups found in cluster {cluster_name}'})
                }
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_msg = e.response['Error']['Message']
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': f'Failed to list nodegroups: {error_code} - {error_msg}',
                    'cluster': cluster_name
                })
            }
    
    # Get scaling configuration from environment variables
    if action == 'scale_up':
        min_size = int(os.environ.get('SCALE_UP_MIN_SIZE', '2'))
        desired_size = int(os.environ.get('SCALE_UP_DESIRED_SIZE', '2'))
        max_size = int(os.environ.get('SCALE_UP_MAX_SIZE', '5'))
    else:  # scale_down
        min_size = int(os.environ.get('SCALE_DOWN_MIN_SIZE', '0'))
        desired_size = int(os.environ.get('SCALE_DOWN_DESIRED_SIZE', '0'))
        max_size = int(os.environ.get('SCALE_DOWN_MAX_SIZE', '1'))
    
    print(f"Action: {action}")
    print(f"Cluster: {cluster_name}")
    print(f"Nodegroups: {nodegroups}")
    print(f"Target scaling config: min={min_size}, desired={desired_size}, max={max_size}")
    
    results = []
    errors = []
    
    # Scale each nodegroup
    for nodegroup_name in nodegroups:
        try:
            print(f"Scaling nodegroup {nodegroup_name}...")
            
            # Update nodegroup configuration
            response = eks.update_nodegroup_config(
                clusterName=cluster_name,
                nodegroupName=nodegroup_name,
                scalingConfig={
                    'minSize': min_size,
                    'desiredSize': desired_size,
                    'maxSize': max_size
                }
            )
            
            update_id = response['update']['id']
            print(f"Update initiated for {nodegroup_name}: {update_id}")
            
            result = {
                'nodegroup': nodegroup_name,
                'status': 'initiated',
                'updateId': update_id,
                'scalingConfig': {
                    'minSize': min_size,
                    'desiredSize': desired_size,
                    'maxSize': max_size
                }
            }
            
            # Optionally wait for the update to complete
            if wait_for_active:
                print(f"Waiting for {nodegroup_name} to reach ACTIVE status...")
                max_wait_time = 600  # 10 minutes
                start_time = time.time()
                
                while time.time() - start_time < max_wait_time:
                    ng_response = eks.describe_nodegroup(
                        clusterName=cluster_name,
                        nodegroupName=nodegroup_name
                    )
                    
                    status = ng_response['nodegroup']['status']
                    print(f"Current status: {status}")
                    
                    if status == 'ACTIVE':
                        result['status'] = 'completed'
                        print(f"{nodegroup_name} is now ACTIVE")
                        break
                    elif status in ['CREATE_FAILED', 'DELETE_FAILED', 'DEGRADED']:
                        result['status'] = 'failed'
                        result['error'] = f"Nodegroup in {status} state"
                        errors.append(result)
                        break
                    
                    time.sleep(10)
                else:
                    result['status'] = 'timeout'
                    result['warning'] = 'Update initiated but timed out waiting for ACTIVE status'
            
            results.append(result)
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_msg = e.response['Error']['Message']
            print(f"Error scaling {nodegroup_name}: {error_code} - {error_msg}")
            
            errors.append({
                'nodegroup': nodegroup_name,
                'status': 'error',
                'error': f"{error_code}: {error_msg}"
            })
        except Exception as e:
            print(f"Unexpected error scaling {nodegroup_name}: {str(e)}")
            errors.append({
                'nodegroup': nodegroup_name,
                'status': 'error',
                'error': str(e)
            })
    
    # Prepare response
    response_body = {
        'action': action,
        'cluster': cluster_name,
        'nodegroups': nodegroups,
        'results': results,
        'errors': errors,
        'summary': {
            'total': len(nodegroups),
            'successful': len(results),
            'failed': len(errors)
        }
    }
    
    # Always return 200 with detailed status in body (207-like semantics)
    return {
        'statusCode': 200,
        'body': json.dumps(response_body, indent=2)
    }
