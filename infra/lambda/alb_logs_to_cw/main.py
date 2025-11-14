import boto3
import gzip
import os
import time
from botocore.exceptions import ClientError

logs = boto3.client('logs')
s3 = boto3.client('s3')
LOG_GROUP = os.environ['LOG_GROUP']


def chunk_lines(lines, size=200):
    for i in range(0, len(lines), size):
        yield lines[i:i + size]


def ensure_stream(name):
    try:
        logs.create_log_stream(logGroupName=LOG_GROUP, logStreamName=name)
        return None
    except ClientError as exc:
        if exc.response['Error']['Code'] == 'ResourceAlreadyExistsException':
            resp = logs.describe_log_streams(
                logGroupName=LOG_GROUP,
                logStreamNamePrefix=name,
                limit=1,
            )
            streams = resp.get('logStreams', [])
            if streams:
                return streams[0].get('uploadSequenceToken')
        else:
            raise
    return None


def lambda_handler(event, context):
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        obj = s3.get_object(Bucket=bucket, Key=key)
        body = obj['Body'].read()
        if key.endswith('.gz'):
            body = gzip.decompress(body)
        text = body.decode('utf-8')
        lines = [line for line in text.splitlines() if line and not line.startswith('#')]
        if not lines:
            continue
        stream_name = key.replace('/', '-').replace('.', '-')
        sequence = ensure_stream(stream_name)
        timestamp = int(time.time() * 1000)
        for batch in chunk_lines(lines):
            events = [{'timestamp': timestamp + idx, 'message': line} for idx, line in enumerate(batch)]
            kwargs = {
                'logGroupName': LOG_GROUP,
                'logStreamName': stream_name,
                'logEvents': events,
            }
            if sequence:
                kwargs['sequenceToken'] = sequence
            resp = logs.put_log_events(**kwargs)
            sequence = resp.get('nextSequenceToken')
