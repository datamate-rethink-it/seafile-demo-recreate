#!/bin/bash

# Check if curl is installed
if ! command -v curl &> /dev/null
then
    echo "curl not found, installing..."
    apt-get update && apt-get install -y curl || { echo "Failed to install curl"; exit 1; }
fi

# Make curl request to health endpoint
curl -f http://127.0.0.1:8083/ping/ || exit 1

exit 0