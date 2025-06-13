FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    docker.io \
    git \
    gcc \
    libffi-dev \
    libssl-dev \
    python3-dev \
    sshpass \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir \
    flask==2.3.3 \
    requests==2.31.0 \
    ansible==8.5.0 \
    docker==6.1.3

# Install Ansible Docker collection
RUN ansible-galaxy collection install community.docker

# Set working directory
WORKDIR /app

# Copy webhook_handler.py to /app
COPY webhook_handler.py /app/

# Copy ansible playbooks to /app/ansible
COPY ansible/ /app/ansible/

# Create logs directory
RUN mkdir -p /app/logs && chmod -R 755 /app && chown -R 1000:1000 /app

# Use non-root user
RUN useradd -m -u 1000 appuser
USER appuser

# Expose Flask port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# ✅ Run the correct file from /app
CMD ["python", "/app/webhook_handler.py"]
