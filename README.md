# Seafile Demo / Private Cloud Server

This repository contains a Docker Compose yml and Scripts that can be used to recreate a Seafile private cloud server.  
The server runs on a Docker host with Docker Engine and Docker Compose installed, and uses the `/opt` directory as the standard installation directory.  
The server is reset with a recreate.sh script.

typically this system is reachable at `https://seafile-demo.de/`

## Prerequisites

To use this repository, you need to have the following installed on your Docker host:

- Docker Engine
- Docker Compose
- jq and curl must be installed

## Daily refresh

Create a cronjob that simply executes `/opt/seafile-demo-recreate/reset.sh` like

```
59 1 * * * /opt/seafile-demo-recreate/reset.sh > /opt/reset.log
```

## Missing:

- rework README.md
- single-sign-on
- chmod +x reset.sh
- SITE_TITLE