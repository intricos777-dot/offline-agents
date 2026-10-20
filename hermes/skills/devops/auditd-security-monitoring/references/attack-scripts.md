<!-- Watermark: Living_Sin (intricos777-dot) + AI agents (Hermes, Lia, opencode) - collaborative work -->
# Attack Monitoring Scripts

## attack-monitor.py
Location: `/home/sin/bin/attack-monitor.py`

A Python script that checks audit logs and system state for security events.

### Features
- Scans audit logs for suspicious file access (passwd, shadow, sudoers, SSH keys)
- Monitors SSH brute force attempts via journalctl
- Checks for running suspicious processes (miner, botnet, cryptominer)
- Detects privilege escalation attempts
- Logs findings to JSON file

### Running Manually
```bash
python3 /home/sin/bin/attack-monitor.py
```

### Scheduled via systemd
```bash
# Service
sudo tee /etc/systemd/system/attack-monitor.service << 'EOF'
[Unit]
Description=Attack Detection Monitor
After=auditd.service

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 /home/sin/bin/attack-monitor.py
User=root
EOF

# Timer
sudo tee /etc/systemd/system/attack-monitor.timer << 'EOF'
[Unit]
Description=Run attack detection every 5 minutes

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now attack-monitor.timer
```

## run-attack-monitor.sh
A bash wrapper that provides colored output and log rotation.

## setup-attack-monitoring.sh
One-click setup script that:
- Creates security log directories
- Enables and starts auditd
- Loads audit rules
- Runs initial detection scan