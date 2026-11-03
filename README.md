## What is PAM?

`Privileged Access Management`

A security tool to control, monitor, and log who accesses servers. It gives the right access to the right machine at the right time.

---
## Why use PAM in HomeLab ?

- **Ditch Passwords/SSH Keys:** Swaps them for secure, short-lived certificates.
- **Browser-Based Access:** Log in from any device via web browser. No SSH clients needed.
- **Session Recording:** Tracks and records exactly what commands are run for troubleshooting.
- **Easy MFA:** Adds 2FA to old servers that don't support it natively.

---
## What is Teleport

*Teleport* is an  security gateway that manages access to all your servers, databases, and applications. 

Instead of using passwords or long-lasting SSH keys, it puts a single "secure gate" in front of your entire home network or cloud infrastructure.

---
## Deploying Teleport

### Prerequisites
* A system with [[Live-Hugo/Self-Hosted_Projects/Docker_Installation|Docker]] installed.
* [[/HomeLab-Self_Hosted_Services/DNS_Stack/DNS_With_Pihole_&_Unbound|Pi-Hole]]
* A registered domain from a provider (e.g., Cloudflare)
---
### Create `cname` record for *Teleport* and *Docker Host*

* Login to Pi-Hole.
* Create CNAME record as below and click "+" to add.

| Domain                      | Target                         |
| --------------------------- | ------------------------------ |
| teleport.</your-domain.com> | docker_host.</your-domain.com> 

---
### Download docker-compose.yml

```URL
git clone https://github.com/TejaNune1998/Teleport.git
```

----------------
### Directory Structure 

```
├── data
│   └── teleport
│   ├── certs
│   ├── config
│   │   ├── certs
│   │   └── teleport.yaml
│   └── data
├── docker-compose.yml
├── env-access-role.yaml
├── logs
└── renew.sh
```
---
### Update Paths in `docker-compose.yml` file

```
    volumes:
      - /path/to/teleport/data/teleport/config:/etc/teleport
      - /path/to/teleport/data/teleport/data:/var/lib/teleport
      - /path/to/teleport/data/teleport/certs:/etc/teleport/certs:ro
```

---
### Update `data/certbot/cloudflare.ini` file

* Create [[Live-Hugo/Self-Hosted_Projects/Traefik_Reverse_Proxy_&_Manage_SSL#Update `cf_api_token.txt` file|Cloudflare API]]
* Update API in `data/certbot/cloudflare.ini`

```
dns_cloudflare_api_token = </API>
```

* Change permissions on `cloudflare.ini` file

```
chmod 600 data/certbot/cloudflare.ini
``` 
---
### Generate SSL Certificates 

```
docker run -it --rm --name certbot \
  -v /opt/docker_files/teleport/data/teleport/certs:/etc/letsencrypt \
  -v /opt/docker_files/teleport/data/certbot/secrets/cloudflare.ini:/cloudflare.ini:ro \
  certbot/dns-cloudflare:latest certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /cloudflare.ini \
  --dns-cloudflare-propagation-seconds 30 \
  --agree-tos \
  --no-eff-email \
  -m </cloudflare-register-mail-id> \
  -d </your-domain.com> \
  -d "*.</your-domain.com>"
```

#### Auto-renewal

* Update *paths* in `renew.sh` file

```
vim renew.sh
```

```
#!/bin/bash
set -e
⋮
⋮
docker run --rm --name certbot \
  ⋮
  -v /path/to/teleport/data/teleport/certs:/etc/letsencrypt \
  -v /path/to/teleport/data/certbot/secrets/cloudflare.ini:/cloudflare.ini:ro \
  ⋮
# Check if the renew hook created the flag
if [ -f /path/to/teleport/data/teleport/certs/renewed.flag ]; then
  ⋮
  rm -f /path/to/teleport/data/teleport/certs/renewed.flag
  ⋮
  ⋮
find /path/to/teleport/logs -type f -mtime +30 -exec rm -f {} +
```

* Create a *CronJob*

```
crontab -e
```

```
0 3 * * * /path/to/teleport/renew.sh >> /path/to//teleport/logs/renew_$(date +\%d\%b\%y\%H\%M).log 2>&1
```

---
### Update `data/teleport/config/teleport.yaml` file
	
*Update only entries*

```vim
version: v3
teleport:
  nodename: </DOCKER_HOSTNAME>.</your-domain.com>
  ⋮
  
auth_service:
  ⋮
  cluster_name: teleport.</your-domain.com>

ssh_service:
  enabled: no 

proxy_service:
	⋮
  public_addr: teleport.</your-domain.com>:443
⋮
```

---
### Start our compose stack as a daemon.

```
docker compose up -d
```

---
### Create `Admin` user

* Use below command to create *admin* user

```
docker exec -it teleport tctl users add admin --roles=editor,access --logins=</os-user1>,<os-user2>
```

* Use give outputted link to setup admin user.

---
### Create Custom Roles via YAML

* Update only below entries in `env-access-role.yaml` file.

```
kind: role
version: v5
metadata:
  name: </role_name>
spec:
  allow:
    logins: ['root','ubuntu','</user1>','</user2>']
    node_labels:
      '</label-name>': '</label-value>'
⋮
```

* Create a *Role*

```
docker exec -i teleport tctl create -f < new-role.yaml
```

---
### Add Targeted Nodes

* Login to `https://teleport.miniverse.com.co` as *Admin* user
* Navigate as below :

```Web
Resources --> Enroll new resource --> Select resource type
```

``` Configure
Adding Label [label name | label value] --> Use Provide link to install agent on targeted node --> Test connection
```

---
### Add Docker-Host Node

*Note: Because Teleport runs inside Docker, the host agent requires local service configuration to connect properly.*

* Login to `https://teleport.miniverse.com.co` as *Admin* user
* Navigate as below :

```Web
Resources --> Enroll new resource --> Select resource type
```

```Configure
Adding Label [label name | label value] --> Use Provide link to install agent on targeted node
```

*Note: Teleport will unable to detect the node*

* Update only below entries in `etc-teleport.yaml` file

```
version: v3
teleport:
  nodename: </DOCKER_HOSTNAME>.</your_domaim.co>
  ⋮
  auth_token: "</TOKEN>"
  proxy_server: teleport.</your_domaim.co>:443
⋮

ssh_service:
  enabled: yes
  labels:
    </label_name>: </value>
⋮
```

* Take backup and replace `/etc/teleport.yaml` file

```
cp -ap /etc/teleport.yaml /etc/teleport.yaml_</DDMMYYYY_vN>
mv etc-teleport.yaml /etc/teleport.yaml
```

* Restart `Teleport` services

```
sudo systemctl restart teleport
```

* Now the *docker host* will be talking to *teleport* and it will appear on the `Resource dashboard`.
* Verify the connection.

---
### Create Teleport User

* Navigate as below :

```Web
Zero Trust Access --> Users --> Create User
```

```Creation

Username : </User1>
User Role : </Role_created-1>
User Traits:
	Key : Login
	Value : </OS-User1>,</OS-User2>,.....

Click Save
```

* Use given link to setup user.
* Verify login in to any resource assigned.
---
### Client Tool (tsh)

* Install `tsh` client tool.

```
curl -O https://cdn.teleport.dev/teleport-v18.11.8-linux-amd64-bin.tar.gz
tar -xzf teleport-v18.11.8-linux-amd64-bin.tar.gz
cd teleport
sudo ./install
```

* Authenticate to Teleport.

```
tsh login --proxy=teleport.</yourdomaim.co> --user=</USER>
```

* Connect to Node

```
tsh ssh <SYS_USER>@<HOSTNAME/IP>
```

---

### Disable SSH on Targeted Nodes *[Optional]*

``` debian
sudo systemctl disable ssh
sudo systemctl stop ssh
```

```fedora
sudo systemctl disable sshd
sudo systemctl stop ssh
```

---
