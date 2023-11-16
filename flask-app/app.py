from flask import Flask
import requests
import os
import sys
import logging

logging.basicConfig(stream=sys.stdout, level=logging.INFO)

app = Flask(__name__)

@app.route('/')
def hello():
    metadata_url = os.environ.get("ECS_CONTAINER_METADATA_URI_V4", "")
    logging.info(f"AWS Metadata url: {metadata_url}")
    aws_metadata = {}
    if metadata_url:
        resp = requests.get(f"{metadata_url}/task")
        aws_metadata = resp.json()
    logging.info(f"AWS Metadata: {aws_metadata}")
    az = aws_metadata.get("AvailabilityZone", "N/A")
    # Get the nested IP
    containers = aws_metadata.get("Containers", [{}])
    network = containers[0].get("Networks", [{}])
    public_ip = network[0].get("IPv4Addresses", [])
    # Display some metadata
    return f'<div style="display:flex;flex-direction:column;"><h1>Hello world!</h1><h2>Availability Zone: {az}</h2><h2>IPs: {public_ip}</h2></div>'


if __name__ == "__main__":
    app.run(debug=True)