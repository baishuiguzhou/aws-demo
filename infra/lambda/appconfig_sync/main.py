import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ecs = boto3.client("ecs")
sns = boto3.client("sns")

CLUSTER = os.environ["ECS_CLUSTER"]
SERVICE = os.environ["ECS_SERVICE"]
SNS_TOPIC = os.environ["SNS_TOPIC_ARN"]

SUCCESS_STATES = {"DEPLOYMENT_COMPLETED"}
ERROR_STATES = {"DEPLOYMENT_FAILED", "DEPLOYMENT_ROLLED_BACK", "ROLLED_BACK"}


def lambda_handler(event, _context):
    logger.info("Received event: %s", json.dumps(event))
    detail = event.get("detail", {})
    state = detail.get("state", "UNKNOWN")
    deployment_id = detail.get("deploymentId", "unknown")
    application = detail.get("applicationName", detail.get("applicationId", ""))
    environment = detail.get("environmentName", detail.get("environmentId", ""))

    subject = f"AppConfig deployment state: {state}"
    message_lines = [
        f"Application: {application}",
        f"Environment: {environment}",
        f"Deployment ID: {deployment_id}",
        f"State: {state}",
    ]

    if state in SUCCESS_STATES:
        ecs.update_service(cluster=CLUSTER, service=SERVICE, forceNewDeployment=True)
        message_lines.append("Triggered ECS service rolling update to pick up new configuration.")
        subject = "AppConfig deployment succeeded"
    elif state in ERROR_STATES:
        subject = "AppConfig deployment failed"
        message_lines.append("Deployment reported failure. Please investigate and re-deploy if needed.")
    else:
        message_lines.append("State is informational; no action taken automatically.")

    sns.publish(TopicArn=SNS_TOPIC, Subject=subject, Message="\n".join(message_lines))
    return {"status": "ok", "state": state}
