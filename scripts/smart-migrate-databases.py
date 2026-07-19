#!/usr/bin/env python3

"""
Smart Database Migration Script for Aegis Security Suite
Checks for existing columns before adding them to avoid errors
"""

import os
import sqlite3
import sys
from datetime import datetime

def get_table_columns(conn, table_name):
    """Get list of columns for a table"""
    cursor = conn.cursor()
    cursor.execute(f"PRAGMA table_info({table_name})")
    columns = [row[1] for row in cursor.fetchall()]
    return columns

def add_column_if_not_exists(conn, table_name, column_name, column_type):
    """Add column only if it doesn't exist"""
    columns = get_table_columns(conn, table_name)
    if column_name not in columns:
        cursor = conn.cursor()
        cursor.execute(f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_type}")
        print(f"Added {column_name} to {table_name}")
        return True
    else:
        print(f"{column_name} already exists in {table_name}")
        return False

def migrate_behavioral_db(db_path):
    """Migrate behavioral analysis database"""
    print(f"Migrating behavioral database: {db_path}")
    
    if not os.path.exists(db_path):
        print(f"Database not found: {db_path}")
        return False
    
    # Create backup
    backup_path = f"{db_path}.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    print(f"Creating backup: {backup_path}")
    
    import shutil
    shutil.copy2(db_path, backup_path)
    
    conn = sqlite3.connect(db_path)
    
    try:
        # Add computed columns to system_metrics
        add_column_if_not_exists(conn, 'system_metrics', 'disk_io', 'INTEGER')
        add_column_if_not_exists(conn, 'system_metrics', 'network_io', 'INTEGER')
        add_column_if_not_exists(conn, 'system_metrics', 'process_count', 'INTEGER')
        add_column_if_not_exists(conn, 'system_metrics', 'anomaly_score', 'REAL')
        add_column_if_not_exists(conn, 'system_metrics', 'threat_level', 'TEXT')
        
        # Update existing records
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE system_metrics SET 
                disk_io = COALESCE(disk_io, disk_io_reads + disk_io_writes),
                network_io = COALESCE(network_io, network_connections),
                process_count = COALESCE(process_count, active_processes),
                anomaly_score = COALESCE(anomaly_score, 0),
                threat_level = COALESCE(threat_level, 'low')
            WHERE disk_io IS NULL OR network_io IS NULL OR process_count IS NULL 
               OR anomaly_score IS NULL OR threat_level IS NULL
        """)
        
        # Add performance indexes
        indexes = [
            "CREATE INDEX IF NOT EXISTS idx_system_metrics_timestamp_cpu ON system_metrics(timestamp, cpu_usage)",
            "CREATE INDEX IF NOT EXISTS idx_system_metrics_timestamp_memory ON system_metrics(timestamp, memory_usage)",
            "CREATE INDEX IF NOT EXISTS idx_anomaly_events_timestamp_severity ON anomaly_events(timestamp, severity)",
            "CREATE INDEX IF NOT EXISTS idx_anomaly_events_threat_score ON anomaly_events(threat_score)",
            "CREATE INDEX IF NOT EXISTS idx_threat_scores_overall ON threat_scores(overall_score)"
        ]
        
        for index_sql in indexes:
            cursor.execute(index_sql)
        
        # Create views for API compatibility
        cursor.execute("""
            CREATE VIEW IF NOT EXISTS v_behavioral_metrics AS
            SELECT 
                id,
                timestamp,
                cpu_usage,
                memory_usage,
                COALESCE(disk_io, disk_io_reads + disk_io_writes) as disk_io,
                COALESCE(network_io, network_connections) as network_io,
                COALESCE(process_count, active_processes) as process_count,
                COALESCE(anomaly_score, 0) as anomaly_score,
                COALESCE(threat_level, 'low') as threat_level,
                memory_total,
                load_average
            FROM system_metrics
        """)
        
        cursor.execute("""
            CREATE VIEW IF NOT EXISTS v_anomaly_events AS
            SELECT 
                id,
                timestamp,
                anomaly_type,
                metric_name as affected_process,
                current_value,
                baseline_value,
                deviation_score,
                severity,
                threat_score as anomaly_score,
                details as resolution_notes,
                resolved
            FROM anomaly_events
        """)
        
        conn.commit()
        conn.close()
        
        # Optimize database
        conn = sqlite3.connect(db_path)
        conn.execute("VACUUM")
        conn.execute("ANALYZE")
        conn.close()
        
        print("Behavioral database migration completed successfully!")
        return True
        
    except Exception as e:
        print(f"Error migrating behavioral database: {e}")
        conn.close()
        return False

def migrate_threat_intel_db(db_path):
    """Migrate threat intelligence database"""
    print(f"Migrating threat intelligence database: {db_path}")
    
    if not os.path.exists(db_path):
        print(f"Database not found: {db_path}")
        return False
    
    # Create backup
    backup_path = f"{db_path}.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    print(f"Creating backup: {backup_path}")
    
    import shutil
    shutil.copy2(db_path, backup_path)
    
    conn = sqlite3.connect(db_path)
    
    try:
        # Add columns to IOC tables
        tables = ['ioc_ips', 'ioc_domains', 'ioc_urls', 'ioc_hashes']
        
        for table in tables:
            add_column_if_not_exists(conn, table, 'severity', 'TEXT')
            add_column_if_not_exists(conn, table, 'description', 'TEXT')
            add_column_if_not_exists(conn, table, 'created_at', 'DATETIME')
            add_column_if_not_exists(conn, table, 'updated_at', 'DATETIME')
        
        # Update severity based on confidence
        cursor = conn.cursor()
        for table in tables:
            cursor.execute(f"""
                UPDATE {table} SET severity = CASE 
                    WHEN confidence >= 90 THEN 'critical'
                    WHEN confidence >= 75 THEN 'high'
                    WHEN confidence >= 60 THEN 'medium'
                    ELSE 'low'
                END
                WHERE severity IS NULL
            """)
            
            cursor.execute(f"""
                UPDATE {table} SET description = threat_type 
                WHERE description IS NULL
            """)
            
            cursor.execute(f"""
                UPDATE {table} SET created_at = first_seen 
                WHERE created_at IS NULL
            """)
            
            cursor.execute(f"""
                UPDATE {table} SET updated_at = last_seen 
                WHERE updated_at IS NULL
            """)
        
        # Create unified view
        cursor.execute("""
            CREATE VIEW IF NOT EXISTS v_ioc_data AS
            SELECT 
                id,
                ip_address as ioc_value,
                'ip' as ioc_type,
                description,
                severity,
                source,
                created_at,
                updated_at,
                first_seen,
                last_seen,
                active,
                confidence,
                threat_type
            FROM ioc_ips
            UNION ALL
            SELECT 
                id,
                domain as ioc_value,
                'domain' as ioc_type,
                description,
                severity,
                source,
                created_at,
                updated_at,
                first_seen,
                last_seen,
                active,
                confidence,
                threat_type
            FROM ioc_domains
            UNION ALL
            SELECT 
                id,
                url as ioc_value,
                'url' as ioc_type,
                description,
                severity,
                source,
                created_at,
                updated_at,
                first_seen,
                last_seen,
                active,
                confidence,
                threat_type
            FROM ioc_urls
            UNION ALL
            SELECT 
                id,
                file_hash as ioc_value,
                'hash' as ioc_type,
                description,
                severity,
                source,
                created_at,
                updated_at,
                first_seen,
                last_seen,
                active,
                confidence,
                threat_type
            FROM ioc_hashes
        """)
        
        # Add performance indexes
        indexes = [
            "CREATE INDEX IF NOT EXISTS idx_ioc_ips_active_confidence ON ioc_ips(active, confidence)",
            "CREATE INDEX IF NOT EXISTS idx_ioc_ips_first_seen ON ioc_ips(first_seen DESC)",
            "CREATE INDEX IF NOT EXISTS idx_ioc_domains_active_confidence ON ioc_domains(active, confidence)",
            "CREATE INDEX IF NOT EXISTS idx_ioc_domains_first_seen ON ioc_domains(first_seen DESC)",
            "CREATE INDEX IF NOT EXISTS idx_ioc_urls_active_confidence ON ioc_urls(active, confidence)",
            "CREATE INDEX IF NOT EXISTS idx_ioc_urls_first_seen ON ioc_urls(first_seen DESC)",
            "CREATE INDEX IF NOT EXISTS idx_ioc_hashes_active_confidence ON ioc_hashes(active, confidence)",
            "CREATE INDEX IF NOT EXISTS idx_ioc_hashes_first_seen ON ioc_hashes(first_seen DESC)"
        ]
        
        for index_sql in indexes:
            cursor.execute(index_sql)
        
        conn.commit()
        conn.close()
        
        # Optimize database
        conn = sqlite3.connect(db_path)
        conn.execute("VACUUM")
        conn.execute("ANALYZE")
        conn.close()
        
        print("Threat intelligence database migration completed successfully!")
        return True
        
    except Exception as e:
        print(f"Error migrating threat intelligence database: {e}")
        conn.close()
        return False

def migrate_incidents_db(db_path):
    """Migrate incident management database"""
    print(f"Migrating incidents database: {db_path}")
    
    if not os.path.exists(db_path):
        print(f"Database not found: {db_path}")
        return False
    
    # Create backup
    backup_path = f"{db_path}.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    print(f"Creating backup: {backup_path}")
    
    import shutil
    shutil.copy2(db_path, backup_path)
    
    conn = sqlite3.connect(db_path)
    
    try:
        # Add columns to incidents table
        add_column_if_not_exists(conn, 'incidents', 'title', 'TEXT')
        add_column_if_not_exists(conn, 'incidents', 'source', 'TEXT')
        add_column_if_not_exists(conn, 'incidents', 'assigned_to', 'TEXT')
        add_column_if_not_exists(conn, 'incidents', 'updated_at', 'DATETIME')
        add_column_if_not_exists(conn, 'incidents', 'tags', 'TEXT')
        
        # Update existing records
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE incidents SET 
                title = COALESCE(title, incident_type || ' - ' || substr(incident_details, 1, 50) || '...'),
                source = COALESCE(source, 'system'),
                updated_at = COALESCE(updated_at, timestamp),
                tags = COALESCE(tags, '[]')
            WHERE title IS NULL OR source IS NULL OR updated_at IS NULL OR tags IS NULL
        """)
        
        # Create API-friendly view
        cursor.execute("""
            CREATE VIEW IF NOT EXISTS v_incidents AS
            SELECT 
                id,
                incident_id,
                COALESCE(title, incident_type || ' - ' || substr(incident_details, 1, 50) || '...') as title,
                incident_type,
                incident_details as description,
                severity,
                status,
                COALESCE(source, 'system') as source,
                timestamp as created_at,
                COALESCE(updated_at, timestamp) as updated_at,
                resolved_timestamp as resolved_at,
                assigned_to,
                COALESCE(tags, '[]') as tags,
                actions_taken,
                evidence_path,
                false_positive,
                rollback_available,
                rollback_data
            FROM incidents
        """)
        
        # Add performance indexes
        indexes = [
            "CREATE INDEX IF NOT EXISTS idx_incidents_status_timestamp ON incidents(status, timestamp DESC)",
            "CREATE INDEX IF NOT EXISTS idx_incidents_severity_timestamp ON incidents(severity, timestamp DESC)",
            "CREATE INDEX IF NOT EXISTS idx_incidents_type_timestamp ON incidents(incident_type, timestamp DESC)",
            "CREATE INDEX IF NOT EXISTS idx_incidents_updated_at ON incidents(updated_at DESC)"
        ]
        
        for index_sql in indexes:
            cursor.execute(index_sql)
        
        conn.commit()
        conn.close()
        
        # Optimize database
        conn = sqlite3.connect(db_path)
        conn.execute("VACUUM")
        conn.execute("ANALYZE")
        conn.close()
        
        print("Incidents database migration completed successfully!")
        return True
        
    except Exception as e:
        print(f"Error migrating incidents database: {e}")
        conn.close()
        return False

def main():
    """Main migration function"""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    security_suite_home = os.environ.get(
        'AEGIS_HOME', os.environ.get('SECURITY_SUITE_HOME', os.path.dirname(script_dir)))
    
    print("=" * 50)
    print("Aegis Security Suite Smart Database Migration")
    print("=" * 50)
    print(f"Security Suite Home: {security_suite_home}")
    print(f"Timestamp: {datetime.now()}")
    print()
    
    # Database paths
    behavioral_db = os.path.join(security_suite_home, 'configs', 'behavioral_analysis', 'behavioral_data.db')
    threat_db = os.path.join(security_suite_home, 'configs', 'threat_intelligence', 'ioc_database.db')
    incidents_db = os.path.join(security_suite_home, 'configs', 'incident_response', 'incidents.db')
    
    # Track success
    success = True
    
    # Run migrations
    if not migrate_behavioral_db(behavioral_db):
        success = False
    
    if not migrate_threat_intel_db(threat_db):
        success = False
    
    if not migrate_incidents_db(incidents_db):
        success = False
    
    # Summary
    print()
    print("=" * 50)
    print("Migration Summary")
    print("=" * 50)
    
    if success:
        print("✓ All database migrations completed successfully!")
        print()
        print("Next steps:")
        print("1. Restart the web dashboard: sudo systemctl restart aegis-dashboard")
        print("2. Test API endpoints to verify functionality")
        print("3. Check dashboard logs for any issues")
        return 0
    else:
        print("✗ One or more migrations failed!")
        print()
        print("Troubleshooting:")
        print("1. Check the error messages above")
        print("2. Verify database file permissions")
        print("3. Ensure sufficient disk space")
        print("4. Check database integrity with: sqlite3 <db_path> 'PRAGMA integrity_check;'")
        return 1

if __name__ == "__main__":
    sys.exit(main())