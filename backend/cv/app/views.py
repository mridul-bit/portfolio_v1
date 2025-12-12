import boto3
from botocore.exceptions import ClientError
from rest_framework.decorators import api_view
from rest_framework.response import Response
from django.db import connection
import logging
from .models import DownloadLog

# Use the configured JSON Logger
logger = logging.getLogger('core')

# Retrieve critical config from AWS Systems Manager Parameter Store via environment
import os

# Get values directly from the environment variables supplied by ECS
RESUME_S3_KEY = os.environ.get('RESUME_S3_KEY') 
RESUME_BUCKET_NAME = os.environ.get('RESUME_BUCKET_NAME')
EXPIRATION_SECONDS = 60

print(f"Resume S3 Key: {RESUME_S3_KEY}, Bucket: {RESUME_BUCKET_NAME}")
@api_view(['GET'])
def liveness_probe(request):
    
    return Response({'status': 'OK', 'system': 'Alive'}, status=200)

@api_view(['GET'])
def readiness_probe(request):
    """EKS Readiness Probe: Checks if DB is ready before routing traffic."""
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
    except Exception as e:
        logger.error("Readiness check failed: DB Unreachable", extra={'error': str(e)})
        return Response({'status': 'FAIL', 'reason': 'DB Unreachable'}, status=503)

    return Response({'status': 'OK', 'system': 'Ready to Serve'}, status=200)

##radom comment to check cicd
# --- Secure API Endpoint ---

@api_view(['GET'])
# Note: Rate Limiting is applied by the Kubernetes Ingress/ALB layer, but Django-ratelimit is installed.
def secure_resume_download(request):
    ip_addr = request.META.get('REMOTE_ADDR')

    # 1. Create Audit Log Entry (Status: PENDING)
    log_entry = DownloadLog.objects.create(
        file_key=RESUME_S3_KEY,
        requester_ip=ip_addr,
        user_agent=request.META.get('HTTP_USER_AGENT', 'unknown'),
        status="PENDING" 
    )

    # Log the attempt using structured logging
    logger.info("Secure Download Attempt Initiated", extra={'ip': ip_addr, 'log_id': str(log_entry.log_id)})

    # 2. Generate Presigned URL
    s3_client = boto3.client('s3')
    try:
        url = s3_client.generate_presigned_url(
            ClientMethod='get_object',
            Params={'Bucket': RESUME_BUCKET_NAME, 'Key': RESUME_S3_KEY},
            ExpiresIn=EXPIRATION_SECONDS
        )
        
        # 3. Update Audit Log Entry (Status: SUCCESS)
        log_entry.status = "SUCCESS"
        log_entry.save()
        logger.info("Presigned URL Generated Successfully", extra={'ip': ip_addr, 'log_id': str(log_entry.log_id)})

        return Response({'presigned_url': url, 'expires_in': EXPIRATION_SECONDS}, status=200)

    except ClientError as e:
        # 3. Update Audit Log Entry (Status: FAILURE)
        error_code = e.response['Error']['Code']
        log_entry.status = f"FAILED: {error_code}"
        log_entry.save()
        logger.error("Presigned URL Generation Failed", extra={'ip': ip_addr, 'log_id': str(log_entry.log_id), 's3_error': error_code})
        
        return Response({'error': 'Could not generate secure download link.'}, status=500)