# 🛠️ Self‑Healing Infrastructure Demo

A hands-on project demonstrating **automated incident detection** and **self-healing** using modern DevOps tools. When NGINX goes down, it is automatically restarted using a webhook, Prometheus alert, and Ansible automation.

---

## 📦 Project Components

| Component         | Role                                                       |
|------------------|------------------------------------------------------------|
| **NGINX**         | Simulated web server to monitor                             |
| **Prometheus**    | Metrics collection and alert triggering                    |
| **Alertmanager**  | Sends critical alerts to webhook                           |
| **Node Exporter** | System-level metrics exporter                              |
| **NGINX Exporter**| NGINX-specific metrics for Prometheus                      |
| **Grafana**       | Beautiful visualization of metrics                         |
| **cAdvisor**      | Container resource monitoring                              |
| **Webhook Handler**| Custom Python service that triggers Ansible               |
| **Ansible**       | Automates container recovery                               |

---

## 🚀 How to Deploy

> Run the full project in one command using the deploy script:

```bash
bash scripts/deploy.sh
```

This script sets up all services using Docker Compose.

---

## ⚙️ Prerequisites

- ✅ Docker installed
- ✅ Docker Compose v2.27+
- ✅ Git installed
- ✅ Internet access to pull images

---

## 🧱 Project Structure

```
self-healing-infra/
├── ansible/
│   ├── restart_nginx.yml
│   └── inventory.ini
├── configs/
│   ├── alertmanager.yml
│   └── prometheus.yml
├── dashboards/
│   └── nginx-dashboard.json
├── exporters/
│   └── nginx-exporter/
├── scripts/
│   └── deploy.sh
├── webhook/
│   └── webhook_handler.py
├── docker-compose.yml
└── README.md
```

---

## 🧪 What Happens During Failure?

1. NGINX goes down
2. Prometheus sees missing metrics (e.g. `nginx_connections_active`)
3. Alertmanager fires `NginxMetricsMissing` alert
4. Webhook handler receives the alert and runs:

```bash
ansible-playbook /ansible/restart_nginx.yml -i /ansible/inventory.ini
```

5. NGINX container is restarted and logged

---

## 🌐 Monitoring Endpoints

| Tool         | URL                            |
|--------------|----------------------------------|
| Prometheus   | [http://localhost:9090](http://localhost:9090) |
| Alertmanager | [http://localhost:9093](http://localhost:9093) |
| Node Exporter| [http://localhost:9100/metrics](http://localhost:9100/metrics) |
| Grafana      | [http://localhost:3000](http://localhost:3000) |

> 🧠 Grafana Dashboard ID: `12708` (NGINX overview)

---

## 🐍 Webhook Handler (Python)

Custom Flask app listens to Alertmanager and triggers Ansible:

```python
@app.route("/critical-alert", methods=["POST"])
def critical_alert():
    data = request.json
    if "NginxMetricsMissing" in str(data):
        subprocess.run(["ansible-playbook", ...])
```

---

## 📜 Logs & Status

- All restart attempts are logged to:
  ```
  /app/logs/actions.log
  ```
- The Ansible playbook checks container status and health before confirming recovery.

---

## ✅ Sample Command Summary

```bash
git clone https://github.com/PHANTOM0905/self-healing-infra.git
cd self-healing-infra
bash scripts/deploy.sh
```

---

## 📸 Screenshots (Optional)

> You can add screenshots of Grafana dashboards or terminal logs here for documentation.

---

## 🙌 Author

**Mohd Saif**  
[GitHub](https://github.com/PHANTOM0905) • [LinkedIn](https://www.linkedin.com/in/mohd-saif-5903992b0/)

---

> This project is part of a **DevOps internship** project for learning production-grade monitoring & recovery.
