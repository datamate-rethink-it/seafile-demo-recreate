#!/bin/bash

# Check if curl is installed
if ! command -v curl &> /dev/null
then
    echo "curl not found, installing..."
    apt-get update && apt-get install -y curl || { echo "Failed to install curl"; exit 1; }
fi

status_code=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8084/)

if [ "$status_code" -eq 404 ]; then
  exit 0
else
  exit 1
fi