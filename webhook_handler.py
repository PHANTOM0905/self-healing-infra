from flask import Flask, request, jsonify
import json
import subprocess
import logging
import os
from datetime import datetime

app = Flask(__name__)

# Ensure log directory exists
log_dir = '/app/logs'
os.makedirs(log_dir, exist_ok=True)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(log_dir, 'webhook.log')),
        logging.StreamHandler()
    ]
)

def run_ansible_playbook(playbook_name, extra_vars=None):
    """Run Ansible playbook with inventory"""
    try:
        cmd = [
            'ansible-playbook',
            f'/ansible/{playbook_name}',
            '-i', '/ansible/inventory.ini'
        ]
        if extra_vars:
            cmd.extend(['-e', json.dumps(extra_vars)])

        logging.info(f"Running command: {' '.join(cmd)}")

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)

        if result.returncode == 0:
            logging.info(f"✅ Successfully executed {playbook_name}")
            return True, result.stdout
        else:
            logging.error(f"❌ Failed to execute {playbook_name}:\nSTDERR:\n{result.stderr}\nSTDOUT:\n{result.stdout}")
            return False, result.stderr
    except subprocess.TimeoutExpired:
        logging.error(f"⏳ Timeout executing {playbook_name}")
        return False, "Timeout expired"
    except Exception as e:
        logging.error(f"⚠️ Error executing {playbook_name}: {str(e)}")
        return False, str(e)

@app.route('/alert', methods=['POST'])
def handle_alert():
    """Handle regular alerts"""
    try:
        alert_data = request.json
        logging.info(f"📨 Received alert:\n{json.dumps(alert_data, indent=2)}")

        for alert in alert_data.get('alerts', []):
            alert_name = alert.get('labels', {}).get('alertname', 'Unknown')
            service = alert.get('labels', {}).get('service', 'unknown')
            status = alert.get('status', 'unknown')

            logging.info(f"🔍 Processing alert: {alert_name}, Service: {service}, Status: {status}")

            if status == 'firing':
                if alert_name == 'HighSystemLoad':
                    logging.info("⚠️ High system load detected - running cleanup playbook")
                    success, output = run_ansible_playbook('system_cleanup.yml')
                    if success:
                        logging.info("✅ System cleanup completed")
                    else:
                        logging.error(f"❌ System cleanup failed: {output}")

        return jsonify({"status": "success", "message": "Alert processed"}), 200

    except Exception as e:
        logging.error(f"❗ Error processing alert: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/critical-alert', methods=['POST'])
def handle_critical_alert():
    """Handle critical alerts with immediate action"""
    try:
        alert_data = request.json
        logging.critical(f"🚨 Received CRITICAL alert:\n{json.dumps(alert_data, indent=2)}")

        for alert in alert_data.get('alerts', []):
            if alert.get('status') == 'firing':
                alert_name = alert.get('labels', {}).get('alertname', 'Unknown')
                logging.critical(f"🔥 Processing critical alert: {alert_name}")

                if alert_name == 'NginxMetricsMissing':
                    logging.critical("💥 NGINX is down - triggering targeted restart")
                    success, output = run_ansible_playbook('restart_nginx.yml')
                    if success:
                        logging.info("✅ NGINX restart from critical alert succeeded")
                    else:
                        logging.error(f"❌ Critical NGINX restart failed: {output}")
                else:
                    logging.critical("🚨 Triggering emergency response playbook")
                    success, output = run_ansible_playbook('emergency_response.yml')
                    if success:
                        logging.info("✅ Emergency response completed successfully")
                    else:
                        logging.error(f"❌ Emergency response failed: {output}")

        return jsonify({"status": "success", "message": "Critical alert processed"}), 200

    except Exception as e:
        logging.critical(f"❗ Error processing critical alert: {str(e)}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "webhook-handler"
    }), 200

@app.route('/', methods=['GET'])
def home():
    """Home endpoint"""
    return jsonify({
        "message": "Self-Healing Infrastructure Webhook Handler",
        "endpoints": ["/alert", "/critical-alert", "/health"],
        "status": "running"
    }), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
