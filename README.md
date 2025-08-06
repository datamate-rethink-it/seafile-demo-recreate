# Seafile Demo / Private Cloud Server

This repository contains the necessary Docker Compose YAML files and scripts that can be used to recreate a Seafile private cloud server.  
The server runs on a Docker host with Docker Engine and Docker Compose installed, and uses the `/opt` directory as the standard installation directory.  
The server is reset every night with a recreate.sh script.

typically this system is reachable at `https://seafile-demo.de/`

## Prerequisites

To use this repository, you need to have the following installed on your Docker host:

- Docker Engine
- Docker Compose
- jq and curl must be installed

## Install

- Clone this repository in `/opt`. A new folder `/opt/seafile-demo-recreate` will be created
- Save your seafile-license to /opt/seafile-demo-recreate/seafile-license.txt
- Copy /opt/seafile-demo-recreate/env-example to /opt/seafile-demo-recreate/.env and add all required information

## Daily refresh

Create a cronjob that simply executes `/opt/seafile-demo-recreate/reset.sh` like

```
59 1 * * * /opt/seafile-demo-recreate/reset.sh > /opt/reset.log
```

## Missing:

- single-sign-on
- SITE_TITLE