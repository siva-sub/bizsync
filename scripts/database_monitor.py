#!/usr/bin/env python3

"""
BizSync Database Monitoring Script
Advanced monitoring with alerting, metrics collection, and automated recovery
"""

import os
import sys
import time
import json
import sqlite3
import logging
import argparse
import threading
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from enum import Enum

class AlertLevel(Enum):
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"

@dataclass
class DatabaseMetrics:
    timestamp: str
    database_size: int
    page_count: int
    page_size: int
    fragmentation_percent: float
    connection_count: int
    integrity_ok: bool
    wal_size: int
    response_time_ms: float
    
    def to_dict(self) -> Dict:
        return asdict(self)

@dataclass
class Alert:
    level: AlertLevel
    message: str
    timestamp: str
    metrics: Optional[DatabaseMetrics] = None
    
    def to_dict(self) -> Dict:
        return {
            "level": self.level.value,
            "message": self.message,
            "timestamp": self.timestamp,
            "metrics": self.metrics.to_dict() if self.metrics else None
        }

class DatabaseMonitor:
    def __init__(self, config_path: Optional[str] = None):
        self.config = self._load_config(config_path)
        self.setup_logging()
        self.alerts: List[Alert] = []
        self.metrics_history: List[DatabaseMetrics] = []
        self.running = False
        
    def _load_config(self, config_path: Optional[str]) -> Dict:
        """Load configuration from file or use defaults"""
        default_config = {
            "database_paths": [
                "~/Documents/bizsync.db",
                "~/.local/share/bizsync/bizsync.db",
                "/tmp/bizsync_test/bizsync.db"
            ],
            "monitoring": {
                "interval_seconds": 60,
                "enable_alerts": True,
                "max_response_time_ms": 1000,
                "max_fragmentation_percent": 20,
                "max_database_size_mb": 500
            },
            "retention": {
                "metrics_days": 7,
                "alerts_days": 30,
                "backup_days": 90
            },
            "alerts": {
                "log_file": "database_alerts.log",
                "webhook_url": None,
                "email_config": None
            }
        }
        
        if config_path and os.path.exists(config_path):
            try:
                with open(config_path, 'r') as f:
                    user_config = json.load(f)
                    default_config.update(user_config)
            except Exception as e:
                print(f"Warning: Failed to load config from {config_path}: {e}")
        
        return default_config
    
    def setup_logging(self):
        """Setup logging configuration"""
        log_level = logging.INFO
        log_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        
        logging.basicConfig(
            level=log_level,
            format=log_format,
            handlers=[
                logging.StreamHandler(sys.stdout),
                logging.FileHandler('database_monitor.log')
            ]
        )
        
        self.logger = logging.getLogger('DatabaseMonitor')
    
    def find_database(self) -> Optional[str]:
        """Find the first existing database file"""
        for path_str in self.config["database_paths"]:
            path = Path(path_str).expanduser()
            if path.exists():
                return str(path)
        return None
    
    def collect_metrics(self, db_path: str) -> Optional[DatabaseMetrics]:
        """Collect comprehensive database metrics"""
        try:
            start_time = time.time()
            
            with sqlite3.connect(db_path, timeout=10) as conn:
                # Basic connectivity test
                conn.execute("SELECT 1")
                response_time_ms = (time.time() - start_time) * 1000
                
                # Get database statistics
                cursor = conn.cursor()
                
                # File size
                db_size = os.path.getsize(db_path)
                
                # Page statistics
                cursor.execute("PRAGMA page_count")
                page_count = cursor.fetchone()[0]
                
                cursor.execute("PRAGMA page_size")
                page_size = cursor.fetchone()[0]
                
                # Fragmentation analysis
                cursor.execute("PRAGMA freelist_count")
                freelist_count = cursor.fetchone()[0]
                fragmentation_percent = (freelist_count / max(page_count, 1)) * 100
                
                # WAL file size
                wal_path = db_path + '-wal'
                wal_size = os.path.getsize(wal_path) if os.path.exists(wal_path) else 0
                
                # Integrity check (quick)
                cursor.execute("PRAGMA quick_check")
                integrity_result = cursor.fetchone()[0]
                integrity_ok = integrity_result == "ok"
                
                # Connection count (approximate)
                connection_count = 1  # This connection
                
                metrics = DatabaseMetrics(
                    timestamp=datetime.now().isoformat(),
                    database_size=db_size,
                    page_count=page_count,
                    page_size=page_size,
                    fragmentation_percent=fragmentation_percent,
                    connection_count=connection_count,
                    integrity_ok=integrity_ok,
                    wal_size=wal_size,
                    response_time_ms=response_time_ms
                )
                
                return metrics
                
        except Exception as e:
            self.logger.error(f"Failed to collect metrics: {e}")
            return None
    
    def analyze_metrics(self, metrics: DatabaseMetrics) -> List[Alert]:
        """Analyze metrics and generate alerts"""
        alerts = []
        timestamp = datetime.now().isoformat()
        
        # Response time check
        max_response_time = self.config["monitoring"]["max_response_time_ms"]
        if metrics.response_time_ms > max_response_time:
            alert = Alert(
                level=AlertLevel.WARNING,
                message=f"High response time: {metrics.response_time_ms:.2f}ms (threshold: {max_response_time}ms)",
                timestamp=timestamp,
                metrics=metrics
            )
            alerts.append(alert)
        
        # Fragmentation check
        max_fragmentation = self.config["monitoring"]["max_fragmentation_percent"]
        if metrics.fragmentation_percent > max_fragmentation:
            alert = Alert(
                level=AlertLevel.WARNING,
                message=f"High fragmentation: {metrics.fragmentation_percent:.2f}% (threshold: {max_fragmentation}%)",
                timestamp=timestamp,
                metrics=metrics
            )
            alerts.append(alert)
        
        # Database size check
        max_size_mb = self.config["monitoring"]["max_database_size_mb"]
        size_mb = metrics.database_size / (1024 * 1024)
        if size_mb > max_size_mb:
            alert = Alert(
                level=AlertLevel.WARNING,
                message=f"Large database size: {size_mb:.2f}MB (threshold: {max_size_mb}MB)",
                timestamp=timestamp,
                metrics=metrics
            )
            alerts.append(alert)
        
        # Integrity check
        if not metrics.integrity_ok:
            alert = Alert(
                level=AlertLevel.CRITICAL,
                message="Database integrity check failed",
                timestamp=timestamp,
                metrics=metrics
            )
            alerts.append(alert)
        
        # WAL size check (should be reasonable)
        wal_size_mb = metrics.wal_size / (1024 * 1024)
        if wal_size_mb > 50:  # 50MB WAL file is quite large
            alert = Alert(
                level=AlertLevel.INFO,
                message=f"Large WAL file: {wal_size_mb:.2f}MB (consider checkpoint)",
                timestamp=timestamp,
                metrics=metrics
            )
            alerts.append(alert)
        
        return alerts
    
    def handle_alerts(self, alerts: List[Alert]):
        """Handle generated alerts"""
        for alert in alerts:
            self.alerts.append(alert)
            
            # Log the alert
            log_method = getattr(self.logger, alert.level.value.lower(), self.logger.info)
            log_method(alert.message)
            
            # Write to alert log file
            alert_log_path = self.config["alerts"]["log_file"]
            try:
                with open(alert_log_path, 'a') as f:
                    f.write(json.dumps(alert.to_dict()) + '\n')
            except Exception as e:
                self.logger.error(f"Failed to write alert to log: {e}")
            
            # Send webhook notification (if configured)
            webhook_url = self.config["alerts"].get("webhook_url")
            if webhook_url and alert.level in [AlertLevel.WARNING, AlertLevel.CRITICAL]:
                self._send_webhook_alert(webhook_url, alert)
    
    def _send_webhook_alert(self, webhook_url: str, alert: Alert):
        """Send alert via webhook"""
        try:
            import requests
            payload = {
                "text": f"BizSync Database Alert: {alert.message}",
                "level": alert.level.value,
                "timestamp": alert.timestamp
            }
            response = requests.post(webhook_url, json=payload, timeout=10)
            response.raise_for_status()
            self.logger.info(f"Webhook alert sent successfully")
        except Exception as e:
            self.logger.error(f"Failed to send webhook alert: {e}")
    
    def cleanup_old_data(self):
        """Clean up old metrics and alerts based on retention policy"""
        now = datetime.now()
        
        # Clean up metrics
        metrics_cutoff = now - timedelta(days=self.config["retention"]["metrics_days"])
        self.metrics_history = [
            m for m in self.metrics_history 
            if datetime.fromisoformat(m.timestamp) > metrics_cutoff
        ]
        
        # Clean up alerts
        alerts_cutoff = now - timedelta(days=self.config["retention"]["alerts_days"])
        self.alerts = [
            a for a in self.alerts 
            if datetime.fromisoformat(a.timestamp) > alerts_cutoff
        ]
    
    def generate_report(self) -> Dict:
        """Generate comprehensive monitoring report"""
        if not self.metrics_history:
            return {"error": "No metrics data available"}
        
        recent_metrics = self.metrics_history[-1] if self.metrics_history else None
        recent_alerts = [a for a in self.alerts if datetime.fromisoformat(a.timestamp) > datetime.now() - timedelta(hours=24)]
        
        # Calculate trends
        if len(self.metrics_history) >= 2:
            current = self.metrics_history[-1]
            previous = self.metrics_history[-2]
            
            trends = {
                "response_time_trend": current.response_time_ms - previous.response_time_ms,
                "size_trend": current.database_size - previous.database_size,
                "fragmentation_trend": current.fragmentation_percent - previous.fragmentation_percent
            }
        else:
            trends = {}
        
        report = {
            "timestamp": datetime.now().isoformat(),
            "database_status": "healthy" if recent_metrics and recent_metrics.integrity_ok else "unhealthy",
            "current_metrics": recent_metrics.to_dict() if recent_metrics else None,
            "recent_alerts": [a.to_dict() for a in recent_alerts],
            "trends": trends,
            "statistics": {
                "total_metrics_collected": len(self.metrics_history),
                "total_alerts": len(self.alerts),
                "uptime_hours": len(self.metrics_history) * (self.config["monitoring"]["interval_seconds"] / 3600)
            }
        }
        
        return report
    
    def monitor_once(self) -> bool:
        """Perform one monitoring cycle"""
        db_path = self.find_database()
        if not db_path:
            self.logger.warning("Database file not found")
            return False
        
        self.logger.debug(f"Monitoring database: {db_path}")
        
        # Collect metrics
        metrics = self.collect_metrics(db_path)
        if not metrics:
            self.logger.error("Failed to collect metrics")
            return False
        
        # Store metrics
        self.metrics_history.append(metrics)
        
        # Analyze and handle alerts
        if self.config["monitoring"]["enable_alerts"]:
            alerts = self.analyze_metrics(metrics)
            if alerts:
                self.handle_alerts(alerts)
        
        # Cleanup old data periodically
        if len(self.metrics_history) % 100 == 0:  # Every 100 cycles
            self.cleanup_old_data()
        
        return True
    
    def start_monitoring(self):
        """Start continuous monitoring"""
        self.logger.info("Starting database monitoring...")
        self.running = True
        
        interval = self.config["monitoring"]["interval_seconds"]
        
        try:
            while self.running:
                success = self.monitor_once()
                if not success:
                    self.logger.warning("Monitoring cycle failed, retrying...")
                
                time.sleep(interval)
                
        except KeyboardInterrupt:
            self.logger.info("Monitoring stopped by user")
        except Exception as e:
            self.logger.error(f"Fatal error in monitoring loop: {e}")
        finally:
            self.running = False
    
    def stop_monitoring(self):
        """Stop monitoring"""
        self.running = False

def main():
    parser = argparse.ArgumentParser(description="BizSync Database Monitor")
    parser.add_argument("--config", help="Configuration file path")
    parser.add_argument("--once", action="store_true", help="Run monitoring once and exit")
    parser.add_argument("--report", action="store_true", help="Generate and display report")
    parser.add_argument("--daemon", action="store_true", help="Run as daemon")
    
    args = parser.parse_args()
    
    monitor = DatabaseMonitor(args.config)
    
    if args.report:
        report = monitor.generate_report()
        print(json.dumps(report, indent=2))
    elif args.once:
        success = monitor.monitor_once()
        sys.exit(0 if success else 1)
    else:
        if args.daemon:
            # TODO: Implement proper daemon mode
            print("Daemon mode not implemented yet. Running in foreground.")
        
        monitor.start_monitoring()

if __name__ == "__main__":
    main()