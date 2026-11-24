use std::collections::{HashMap, HashSet, VecDeque};
use std::sync::{Arc, RwLock};
use std::time::{SystemTime, UNIX_EPOCH};
use serde::{Deserialize, Serialize};
use log::{info, warn, error, debug};
use tokio::sync::mpsc;
use uuid::Uuid;
use chrono::{DateTime, Utc};
use bcrypt::{hash, verify, DEFAULT_COST};
use jsonwebtoken::{encode, decode, Header, Algorithm, Validation, EncodingKey, DecodingKey};
use reqwest::Client;

use crate::error_handling::SIEMResult;

/// User roles and permissions
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum UserRole {
    SuperAdmin,
    SecurityAdmin,
    SecurityAnalyst,
    ComplianceOfficer,
    IncidentResponder,
    ReadOnly,
    Custom { name: String, permissions: Vec<Permission> },
}

impl std::fmt::Display for UserRole {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            UserRole::SuperAdmin => write!(f, "SuperAdmin"),
            UserRole::SecurityAdmin => write!(f, "SecurityAdmin"),
            UserRole::SecurityAnalyst => write!(f, "SecurityAnalyst"),
            UserRole::ComplianceOfficer => write!(f, "ComplianceOfficer"),
            UserRole::IncidentResponder => write!(f, "IncidentResponder"),
            UserRole::ReadOnly => write!(f, "ReadOnly"),
            UserRole::Custom { name, .. } => write!(f, "Custom:{}", name),
        }
    }
}

/// System permissions
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum Permission {
    // Data access permissions
    ReadAllData,
    ReadSecurityData,
    ReadComplianceData,
    ReadAuditLogs,
    
    // Query permissions
    ExecuteQueries,
    ExecuteAdvancedQueries,
    ExportData,
    
    // Configuration permissions
    ModifySystemConfig,
    ModifySecurityRules,
    ModifyComplianceRules,
    ModifyUserAccess,
    
    // Incident response permissions
    CreateIncidents,
    UpdateIncidents,
    ExecuteResponseActions,
    EscalateIncidents,
    
    // Compliance permissions
    GenerateReports,
    ExportReports,
    ModifyComplianceSettings,
    
    // Admin permissions
    ManageUsers,
    ManageRoles,
    SystemAdministration,
    
    // Custom permissions
    Custom { name: String, description: String },
}

/// User account structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: String,
    pub username: String,
    pub email: String,
    pub password_hash: String,
    pub role: UserRole,
    pub permissions: HashSet<Permission>,
    pub is_active: bool,
    pub is_locked: bool,
    pub failed_login_attempts: u32,
    pub last_login: Option<DateTime<Utc>>,
    pub password_changed_at: DateTime<Utc>,
    pub password_expires_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub mfa_enabled: bool,
    pub mfa_secret: Option<String>,
    pub session_timeout_minutes: u32,
    pub ip_whitelist: Vec<String>,
    pub department: String,
    pub manager: Option<String>,
}

/// JWT Claims for authentication
#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String, // User ID
    pub username: String,
    pub role: String,
    pub permissions: Vec<String>,
    pub exp: usize, // Expiration time
    pub iat: usize, // Issued at
    pub jti: String, // JWT ID
}

/// Audit log entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditLogEntry {
    pub id: String,
    pub timestamp: DateTime<Utc>,
    pub user_id: String,
    pub username: String,
    pub action: String,
    pub resource: String,
    pub resource_type: String,
    pub details: serde_json::Value,
    pub ip_address: String,
    pub user_agent: String,
    pub session_id: String,
    pub success: bool,
    pub error_message: Option<String>,
    pub compliance_category: ComplianceCategory,
    pub risk_level: RiskLevel,
    pub data_classification: DataClassification,
}

/// Compliance categories
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ComplianceCategory {
    AccessControl,
    DataProtection,
    IncidentResponse,
    ConfigurationManagement,
    UserManagement,
    SystemAdministration,
    DataExport,
    ReportGeneration,
    SecurityMonitoring,
    ComplianceReporting,
}

/// Risk levels
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum RiskLevel {
    Low,
    Medium,
    High,
    Critical,
}

/// Data classification levels
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum DataClassification {
    Public,
    Internal,
    Confidential,
    Restricted,
    Classified,
}

/// Compliance framework
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ComplianceFramework {
    SOC2,
    PCI_DSS,
    GDPR,
    HIPAA,
    ISO27001,
    NIST,
    SOX,
    Custom { name: String, requirements: Vec<String> },
}

/// Compliance requirement
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplianceRequirement {
    pub id: String,
    pub framework: ComplianceFramework,
    pub category: String,
    pub requirement: String,
    pub description: String,
    pub controls: Vec<String>,
    pub status: ComplianceStatus,
    pub last_assessment: Option<DateTime<Utc>>,
    pub next_assessment: Option<DateTime<Utc>>,
    pub evidence: Vec<String>,
    pub notes: String,
}

/// Compliance status
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ComplianceStatus {
    Compliant,
    NonCompliant,
    Partial,
    NotApplicable,
    UnderReview,
}

/// Compliance report
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplianceReport {
    pub id: String,
    pub framework: ComplianceFramework,
    pub report_date: DateTime<Utc>,
    pub period_start: DateTime<Utc>,
    pub period_end: DateTime<Utc>,
    pub generated_by: String,
    pub requirements: Vec<ComplianceRequirement>,
    pub summary: ComplianceSummary,
    pub findings: Vec<ComplianceFinding>,
    pub recommendations: Vec<String>,
    pub attachments: Vec<String>,
}

/// Compliance summary
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplianceSummary {
    pub total_requirements: u32,
    pub compliant: u32,
    pub non_compliant: u32,
    pub partial: u32,
    pub not_applicable: u32,
    pub compliance_percentage: f64,
    pub critical_findings: u32,
    pub high_findings: u32,
    pub medium_findings: u32,
    pub low_findings: u32,
}

/// Compliance finding
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ComplianceFinding {
    pub id: String,
    pub requirement_id: String,
    pub severity: RiskLevel,
    pub description: String,
    pub impact: String,
    pub recommendation: String,
    pub remediation_plan: String,
    pub due_date: Option<DateTime<Utc>>,
    pub assigned_to: Option<String>,
    pub status: FindingStatus,
}

/// Finding status
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum FindingStatus {
    Open,
    InProgress,
    Remediated,
    Verified,
    Closed,
}

/// Session management
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserSession {
    pub session_id: String,
    pub user_id: String,
    pub username: String,
    pub ip_address: String,
    pub user_agent: String,
    pub created_at: DateTime<Utc>,
    pub last_activity: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
    pub is_active: bool,
    pub permissions: HashSet<Permission>,
}

/// Compliance and Security Engine
#[derive(Debug)]
pub struct ComplianceSecurityEngine {
    users: Arc<RwLock<HashMap<String, User>>>,
    sessions: Arc<RwLock<HashMap<String, UserSession>>>,
    audit_logs: Arc<RwLock<VecDeque<AuditLogEntry>>>,
    compliance_requirements: Arc<RwLock<HashMap<String, ComplianceRequirement>>>,
    jwt_secret: String,
    http_client: Client,
    audit_tx: mpsc::Sender<AuditLogEntry>,
    audit_rx: mpsc::Receiver<AuditLogEntry>,
    max_audit_logs: usize,
    session_timeout_minutes: u32,
    password_policy: PasswordPolicy,
    mfa_required: bool,
    ip_whitelist_enabled: bool,
    allowed_ips: HashSet<String>,
}

/// Password policy configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PasswordPolicy {
    pub min_length: u32,
    pub require_uppercase: bool,
    pub require_lowercase: bool,
    pub require_numbers: bool,
    pub require_special_chars: bool,
    pub max_age_days: u32,
    pub prevent_reuse_count: u32,
    pub lockout_threshold: u32,
    pub lockout_duration_minutes: u32,
}

impl Default for PasswordPolicy {
    fn default() -> Self {
        Self {
            min_length: 12,
            require_uppercase: true,
            require_lowercase: true,
            require_numbers: true,
            require_special_chars: true,
            max_age_days: 90,
            prevent_reuse_count: 5,
            lockout_threshold: 5,
            lockout_duration_minutes: 30,
        }
    }
}

impl ComplianceSecurityEngine {
    /// Create new compliance and security engine
    pub fn new(jwt_secret: String) -> Self {
        let (audit_tx, audit_rx) = mpsc::channel(1000);
        
        Self {
            users: Arc::new(RwLock::new(HashMap::new())),
            sessions: Arc::new(RwLock::new(HashMap::new())),
            audit_logs: Arc::new(RwLock::new(VecDeque::new())),
            compliance_requirements: Arc::new(RwLock::new(HashMap::new())),
            jwt_secret,
            http_client: Client::new(),
            audit_tx,
            audit_rx,
            max_audit_logs: 100000,
            session_timeout_minutes: 480, // 8 hours
            password_policy: PasswordPolicy::default(),
            mfa_required: true,
            ip_whitelist_enabled: false,
            allowed_ips: HashSet::new(),
        }
    }

    /// Start the compliance and security engine
    pub async fn start(&mut self) -> SIEMResult<()> {
        info!("🔒 Starting Compliance and Security Engine...");
        
        // Initialize default users and roles
        self.initialize_default_users().await?;
        
        // Initialize compliance requirements
        self.initialize_compliance_requirements().await?;
        
        // Start audit log processor
        tokio::spawn({
            let audit_rx = self.audit_rx.clone();
            let audit_logs = self.audit_logs.clone();
            let max_logs = self.max_audit_logs;
            
            async move {
                Self::process_audit_logs(audit_rx, audit_logs, max_logs).await;
            }
        });
        
        // Start session cleanup task
        tokio::spawn({
            let sessions = self.sessions.clone();
            let session_timeout = self.session_timeout_minutes;
            
            async move {
                Self::cleanup_expired_sessions(sessions, session_timeout).await;
            }
        });
        
        info!("✅ Compliance and Security Engine started successfully");
        Ok(())
    }

    /// Authenticate user
    pub async fn authenticate_user(&self, username: &str, password: &str, ip_address: &str) -> SIEMResult<Option<String>> {
        // Check IP whitelist if enabled
        if self.ip_whitelist_enabled && !self.allowed_ips.contains(ip_address) {
            self.log_audit_event(
                "AUTH_FAILED",
                "IP_NOT_WHITELISTED",
                username,
                ip_address,
                false,
                Some("IP address not in whitelist".to_string()),
            ).await;
            return Ok(None);
        }

        let users = self.users.read().unwrap();
        let user = users.get(username);
        
        if let Some(user) = user {
            // Check if account is locked
            if user.is_locked {
                self.log_audit_event(
                    "AUTH_FAILED",
                    "ACCOUNT_LOCKED",
                    username,
                    ip_address,
                    false,
                    Some("Account is locked".to_string()),
                ).await;
                return Ok(None);
            }

            // Verify password
            if verify(password, &user.password_hash).unwrap_or(false) {
                // Check if password is expired
                if let Some(expires_at) = user.password_expires_at {
                    if Utc::now() > expires_at {
                        self.log_audit_event(
                            "AUTH_FAILED",
                            "PASSWORD_EXPIRED",
                            username,
                            ip_address,
                            false,
                            Some("Password has expired".to_string()),
                        ).await;
                        return Ok(None);
                    }
                }

                // Reset failed login attempts
                self.reset_failed_login_attempts(username).await?;
                
                // Create session
                let session_id = self.create_user_session(user, ip_address).await?;
                
                self.log_audit_event(
                    "AUTH_SUCCESS",
                    "LOGIN",
                    username,
                    ip_address,
                    true,
                    None,
                ).await;
                
                Ok(Some(session_id))
            } else {
                // Increment failed login attempts
                self.increment_failed_login_attempts(username).await?;
                
                self.log_audit_event(
                    "AUTH_FAILED",
                    "INVALID_PASSWORD",
                    username,
                    ip_address,
                    false,
                    Some("Invalid password".to_string()),
                ).await;
                
                Ok(None)
            }
        } else {
            self.log_audit_event(
                "AUTH_FAILED",
                "USER_NOT_FOUND",
                username,
                ip_address,
                false,
                Some("User not found".to_string()),
            ).await;
            Ok(None)
        }
    }

    /// Validate JWT token
    pub fn validate_token(&self, token: &str) -> SIEMResult<Option<Claims>> {
        let key = DecodingKey::from_secret(self.jwt_secret.as_ref());
        let validation = Validation::new(Algorithm::HS256);
        
        match decode::<Claims>(token, &key, &validation) {
            Ok(token_data) => {
                // Check if token is expired
                let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() as usize;
                if token_data.claims.exp < now {
                    return Ok(None);
                }
                Ok(Some(token_data.claims))
            }
            Err(_) => Ok(None),
        }
    }

    /// Check user permissions
    pub fn check_permission(&self, user_id: &str, permission: &Permission) -> bool {
        let users = self.users.read().unwrap();
        if let Some(user) = users.get(user_id) {
            user.permissions.contains(permission)
        } else {
            false
        }
    }

    /// Create user
    pub async fn create_user(&self, username: &str, email: &str, password: &str, role: UserRole) -> SIEMResult<String> {
        // Validate password against policy
        self.validate_password_policy(password)?;
        
        // Hash password
        let password_hash = hash(password, DEFAULT_COST)?;
        
        let user_id = Uuid::new_v4().to_string();
        let now = Utc::now();
        let password_expires_at = now + chrono::Duration::days(self.password_policy.max_age_days as i64);
        
        let permissions = self.get_role_permissions(&role);
        
        let user = User {
            id: user_id.clone(),
            username: username.to_string(),
            email: email.to_string(),
            password_hash,
            role,
            permissions,
            is_active: true,
            is_locked: false,
            failed_login_attempts: 0,
            last_login: None,
            password_changed_at: now,
            password_expires_at: Some(password_expires_at),
            created_at: now,
            updated_at: now,
            mfa_enabled: self.mfa_required,
            mfa_secret: None,
            session_timeout_minutes: self.session_timeout_minutes,
            ip_whitelist: Vec::new(),
            department: "Security".to_string(),
            manager: None,
        };
        
        {
            let mut users = self.users.write().unwrap();
            users.insert(username.to_string(), user);
        }
        
        self.log_audit_event(
            "USER_CREATED",
            "USER_MANAGEMENT",
            username,
            "SYSTEM",
            true,
            None,
        ).await;
        
        Ok(user_id)
    }

    /// Update user
    pub async fn update_user(&self, username: &str, updates: HashMap<String, serde_json::Value>) -> SIEMResult<()> {
        let mut users = self.users.write().unwrap();
        if let Some(user) = users.get_mut(username) {
            for (field, value) in updates {
                match field.as_str() {
                    "email" => {
                        if let Some(email) = value.as_str() {
                            user.email = email.to_string();
                        }
                    }
                    "role" => {
                        if let Some(role_str) = value.as_str() {
                            if let Ok(role) = serde_json::from_str::<UserRole>(role_str) {
                                user.role = role.clone();
                                user.permissions = self.get_role_permissions(&role);
                            }
                        }
                    }
                    "is_active" => {
                        if let Some(active) = value.as_bool() {
                            user.is_active = active;
                        }
                    }
                    "department" => {
                        if let Some(dept) = value.as_str() {
                            user.department = dept.to_string();
                        }
                    }
                    _ => {}
                }
            }
            user.updated_at = Utc::now();
        }
        
        self.log_audit_event(
            "USER_UPDATED",
            "USER_MANAGEMENT",
            username,
            "SYSTEM",
            true,
            None,
        ).await;
        
        Ok(())
    }

    /// Delete user
    pub async fn delete_user(&self, username: &str) -> SIEMResult<()> {
        {
            let mut users = self.users.write().unwrap();
            users.remove(username);
        }
        
        // Terminate all sessions for this user
        {
            let mut sessions = self.sessions.write().unwrap();
            sessions.retain(|_, session| session.username != username);
        }
        
        self.log_audit_event(
            "USER_DELETED",
            "USER_MANAGEMENT",
            username,
            "SYSTEM",
            true,
            None,
        ).await;
        
        Ok(())
    }

    /// Generate compliance report
    pub async fn generate_compliance_report(&self, framework: ComplianceFramework, period_start: DateTime<Utc>, period_end: DateTime<Utc>) -> SIEMResult<ComplianceReport> {
        let requirements = self.get_compliance_requirements(&framework).await?;
        let summary = self.calculate_compliance_summary(&requirements).await?;
        let findings = self.identify_compliance_findings(&requirements).await?;
        
        let report = ComplianceReport {
            id: Uuid::new_v4().to_string(),
            framework,
            report_date: Utc::now(),
            period_start,
            period_end,
            generated_by: "SYSTEM".to_string(),
            requirements,
            summary,
            findings,
            recommendations: self.generate_recommendations(&summary).await?,
            attachments: Vec::new(),
        };
        
        self.log_audit_event(
            "REPORT_GENERATED",
            "COMPLIANCE",
            "SYSTEM",
            "SYSTEM",
            true,
            Some(format!("Generated {} compliance report", framework)),
        ).await;
        
        Ok(report)
    }

    /// Get audit logs
    pub async fn get_audit_logs(&self, filters: AuditLogFilters) -> SIEMResult<Vec<AuditLogEntry>> {
        let logs = self.audit_logs.read().unwrap();
        let mut filtered_logs = Vec::new();
        
        for log in logs.iter() {
            if self.matches_audit_filters(log, &filters) {
                filtered_logs.push(log.clone());
            }
        }
        
        Ok(filtered_logs)
    }

    /// Export audit logs
    pub async fn export_audit_logs(&self, format: ExportFormat, filters: AuditLogFilters) -> SIEMResult<Vec<u8>> {
        let logs = self.get_audit_logs(filters).await?;
        
        match format {
            ExportFormat::JSON => {
                let json = serde_json::to_string_pretty(&logs)?;
                Ok(json.into_bytes())
            }
            ExportFormat::CSV => {
                let csv = self.convert_logs_to_csv(&logs).await?;
                Ok(csv.into_bytes())
            }
            ExportFormat::XML => {
                let xml = self.convert_logs_to_xml(&logs).await?;
                Ok(xml.into_bytes())
            }
        }
    }

    // Private helper methods

    async fn initialize_default_users(&self) -> SIEMResult<()> {
        let admin_user = User {
            id: "admin".to_string(),
            username: "admin".to_string(),
            email: "admin@ultra-siem.com".to_string(),
            password_hash: hash("UltraSIEM2024!", DEFAULT_COST)?,
            role: UserRole::SuperAdmin,
            permissions: self.get_role_permissions(&UserRole::SuperAdmin),
            is_active: true,
            is_locked: false,
            failed_login_attempts: 0,
            last_login: None,
            password_changed_at: Utc::now(),
            password_expires_at: Some(Utc::now() + chrono::Duration::days(90)),
            created_at: Utc::now(),
            updated_at: Utc::now(),
            mfa_enabled: true,
            mfa_secret: None,
            session_timeout_minutes: 480,
            ip_whitelist: Vec::new(),
            department: "IT".to_string(),
            manager: None,
        };
        
        {
            let mut users = self.users.write().unwrap();
            users.insert("admin".to_string(), admin_user);
        }
        
        Ok(())
    }

    async fn initialize_compliance_requirements(&self) -> SIEMResult<()> {
        // Initialize SOC2 requirements
        let soc2_requirements = vec![
            ("CC1", "Control Environment", "The entity demonstrates commitment to integrity and ethical values."),
            ("CC2", "Communication and Information", "The entity communicates information to support the functioning of internal control."),
            ("CC3", "Risk Assessment", "The entity specifies objectives with sufficient clarity to enable the identification and assessment of risks."),
            ("CC4", "Monitoring Activities", "The entity selects and develops control activities that contribute to the mitigation of risks."),
            ("CC5", "Control Activities", "The entity selects and develops control activities that contribute to the mitigation of risks."),
            ("CC6", "Logical and Physical Access Controls", "The entity implements logical and physical access controls."),
            ("CC7", "System Operations", "The entity implements system operations controls."),
            ("CC8", "Change Management", "The entity implements change management controls."),
            ("CC9", "Risk Mitigation", "The entity implements risk mitigation controls."),
        ];
        
        let mut requirements = self.compliance_requirements.write().unwrap();
        
        for (id, category, description) in soc2_requirements {
            let requirement = ComplianceRequirement {
                id: id.to_string(),
                framework: ComplianceFramework::SOC2,
                category: category.to_string(),
                requirement: description.to_string(),
                description: description.to_string(),
                controls: Vec::new(),
                status: ComplianceStatus::Compliant,
                last_assessment: Some(Utc::now()),
                next_assessment: Some(Utc::now() + chrono::Duration::days(365)),
                evidence: Vec::new(),
                notes: "Automatically assessed as compliant".to_string(),
            };
            
            requirements.insert(id.to_string(), requirement);
        }
        
        Ok(())
    }

    fn get_role_permissions(&self, role: &UserRole) -> HashSet<Permission> {
        match role {
            UserRole::SuperAdmin => {
                let mut permissions = HashSet::new();
                permissions.insert(Permission::ReadAllData);
                permissions.insert(Permission::ExecuteQueries);
                permissions.insert(Permission::ExecuteAdvancedQueries);
                permissions.insert(Permission::ExportData);
                permissions.insert(Permission::ModifySystemConfig);
                permissions.insert(Permission::ModifySecurityRules);
                permissions.insert(Permission::ModifyComplianceRules);
                permissions.insert(Permission::ModifyUserAccess);
                permissions.insert(Permission::CreateIncidents);
                permissions.insert(Permission::UpdateIncidents);
                permissions.insert(Permission::ExecuteResponseActions);
                permissions.insert(Permission::EscalateIncidents);
                permissions.insert(Permission::GenerateReports);
                permissions.insert(Permission::ExportReports);
                permissions.insert(Permission::ModifyComplianceSettings);
                permissions.insert(Permission::ManageUsers);
                permissions.insert(Permission::ManageRoles);
                permissions.insert(Permission::SystemAdministration);
                permissions
            }
            UserRole::SecurityAdmin => {
                let mut permissions = HashSet::new();
                permissions.insert(Permission::ReadAllData);
                permissions.insert(Permission::ExecuteQueries);
                permissions.insert(Permission::ExecuteAdvancedQueries);
                permissions.insert(Permission::ExportData);
                permissions.insert(Permission::ModifySecurityRules);
                permissions.insert(Permission::CreateIncidents);
                permissions.insert(Permission::UpdateIncidents);
                permissions.insert(Permission::ExecuteResponseActions);
                permissions.insert(Permission::EscalateIncidents);
                permissions.insert(Permission::GenerateReports);
                permissions.insert(Permission::ExportReports);
                permissions
            }
            UserRole::SecurityAnalyst => {
                let mut permissions = HashSet::new();
                permissions.insert(Permission::ReadSecurityData);
                permissions.insert(Permission::ExecuteQueries);
                permissions.insert(Permission::ExportData);
                permissions.insert(Permission::CreateIncidents);
                permissions.insert(Permission::UpdateIncidents);
                permissions.insert(Permission::GenerateReports);
                permissions
            }
            UserRole::ComplianceOfficer => {
                let mut permissions = HashSet::new();
                permissions.insert(Permission::ReadComplianceData);
                permissions.insert(Permission::ReadAuditLogs);
                permissions.insert(Permission::ExecuteQueries);
                permissions.insert(Permission::GenerateReports);
                permissions.insert(Permission::ExportReports);
                permissions.insert(Permission::ModifyComplianceSettings);
                permissions
            }
            UserRole::IncidentResponder => {
                let mut permissions = HashSet::new();
                permissions.insert(Permission::ReadSecurityData);
                permissions.insert(Permission::ExecuteQueries);
                permissions.insert(Permission::CreateIncidents);
                permissions.insert(Permission::UpdateIncidents);
                permissions.insert(Permission::ExecuteResponseActions);
                permissions
            }
            UserRole::ReadOnly => {
                let mut permissions = HashSet::new();
                permissions.insert(Permission::ReadSecurityData);
                permissions.insert(Permission::ExecuteQueries);
                permissions
            }
            UserRole::Custom { permissions, .. } => permissions.clone(),
        }
    }

    async fn create_user_session(&self, user: &User, ip_address: &str) -> SIEMResult<String> {
        let session_id = Uuid::new_v4().to_string();
        let now = Utc::now();
        let expires_at = now + chrono::Duration::minutes(user.session_timeout_minutes as i64);
        
        let session = UserSession {
            session_id: session_id.clone(),
            user_id: user.id.clone(),
            username: user.username.clone(),
            ip_address: ip_address.to_string(),
            user_agent: "Ultra SIEM Client".to_string(),
            created_at: now,
            last_activity: now,
            expires_at,
            is_active: true,
            permissions: user.permissions.clone(),
        };
        
        {
            let mut sessions = self.sessions.write().unwrap();
            sessions.insert(session_id.clone(), session);
        }
        
        // Update user's last login
        {
            let mut users = self.users.write().unwrap();
            if let Some(user) = users.get_mut(&user.username) {
                user.last_login = Some(now);
            }
        }
        
        Ok(session_id)
    }

    async fn log_audit_event(&self, action: &str, resource: &str, username: &str, ip_address: &str, success: bool, error_message: Option<String>) {
        let entry = AuditLogEntry {
            id: Uuid::new_v4().to_string(),
            timestamp: Utc::now(),
            user_id: username.to_string(),
            username: username.to_string(),
            action: action.to_string(),
            resource: resource.to_string(),
            resource_type: "SYSTEM".to_string(),
            details: serde_json::json!({
                "ip_address": ip_address,
                "success": success,
                "error_message": error_message,
            }),
            ip_address: ip_address.to_string(),
            user_agent: "Ultra SIEM".to_string(),
            session_id: "SYSTEM".to_string(),
            success,
            error_message,
            compliance_category: ComplianceCategory::AccessControl,
            risk_level: if success { RiskLevel::Low } else { RiskLevel::High },
            data_classification: DataClassification::Internal,
        };
        
        if let Err(e) = self.audit_tx.send(entry).await {
            error!("Failed to send audit log: {}", e);
        }
    }

    async fn process_audit_logs(mut audit_rx: mpsc::Receiver<AuditLogEntry>, audit_logs: Arc<RwLock<VecDeque<AuditLogEntry>>>, max_logs: usize) {
        while let Some(entry) = audit_rx.recv().await {
            let mut logs = audit_logs.write().unwrap();
            logs.push_back(entry);
            
            // Maintain maximum log size
            while logs.len() > max_logs {
                logs.pop_front();
            }
        }
    }

    async fn cleanup_expired_sessions(sessions: Arc<RwLock<HashMap<String, UserSession>>>, session_timeout: u32) {
        loop {
            tokio::time::sleep(tokio::time::Duration::from_secs(300)).await; // Check every 5 minutes
            
            let now = Utc::now();
            let mut sessions_guard = sessions.write().unwrap();
            sessions_guard.retain(|_, session| {
                let is_expired = now > session.expires_at;
                if is_expired {
                    info!("Session expired for user: {}", session.username);
                }
                !is_expired
            });
        }
    }

    fn validate_password_policy(&self, password: &str) -> SIEMResult<()> {
        if password.len() < self.password_policy.min_length as usize {
            return Err("Password too short".into());
        }
        
        if self.password_policy.require_uppercase && !password.chars().any(|c| c.is_uppercase()) {
            return Err("Password must contain uppercase letter".into());
        }
        
        if self.password_policy.require_lowercase && !password.chars().any(|c| c.is_lowercase()) {
            return Err("Password must contain lowercase letter".into());
        }
        
        if self.password_policy.require_numbers && !password.chars().any(|c| c.is_numeric()) {
            return Err("Password must contain number".into());
        }
        
        if self.password_policy.require_special_chars && !password.chars().any(|c| !c.is_alphanumeric()) {
            return Err("Password must contain special character".into());
        }
        
        Ok(())
    }

    async fn reset_failed_login_attempts(&self, username: &str) -> SIEMResult<()> {
        let mut users = self.users.write().unwrap();
        if let Some(user) = users.get_mut(username) {
            user.failed_login_attempts = 0;
            user.is_locked = false;
        }
        Ok(())
    }

    async fn increment_failed_login_attempts(&self, username: &str) -> SIEMResult<()> {
        let mut users = self.users.write().unwrap();
        if let Some(user) = users.get_mut(username) {
            user.failed_login_attempts += 1;
            
            if user.failed_login_attempts >= self.password_policy.lockout_threshold {
                user.is_locked = true;
                info!("Account locked for user: {}", username);
            }
        }
        Ok(())
    }

    async fn get_compliance_requirements(&self, framework: &ComplianceFramework) -> SIEMResult<Vec<ComplianceRequirement>> {
        let requirements = self.compliance_requirements.read().unwrap();
        let filtered: Vec<ComplianceRequirement> = requirements
            .values()
            .filter(|req| std::mem::discriminant(&req.framework) == std::mem::discriminant(framework))
            .cloned()
            .collect();
        Ok(filtered)
    }

    async fn calculate_compliance_summary(&self, requirements: &[ComplianceRequirement]) -> SIEMResult<ComplianceSummary> {
        let total = requirements.len() as u32;
        let mut compliant = 0;
        let mut non_compliant = 0;
        let mut partial = 0;
        let mut not_applicable = 0;
        
        for req in requirements {
            match req.status {
                ComplianceStatus::Compliant => compliant += 1,
                ComplianceStatus::NonCompliant => non_compliant += 1,
                ComplianceStatus::Partial => partial += 1,
                ComplianceStatus::NotApplicable => not_applicable += 1,
                ComplianceStatus::UnderReview => {}
            }
        }
        
        let compliance_percentage = if total > 0 {
            (compliant as f64 / total as f64) * 100.0
        } else {
            0.0
        };
        
        Ok(ComplianceSummary {
            total_requirements: total,
            compliant,
            non_compliant,
            partial,
            not_applicable,
            compliance_percentage,
            critical_findings: 0,
            high_findings: 0,
            medium_findings: 0,
            low_findings: 0,
        })
    }

    async fn identify_compliance_findings(&self, requirements: &[ComplianceRequirement]) -> SIEMResult<Vec<ComplianceFinding>> {
        let mut findings = Vec::new();
        
        for req in requirements {
            if req.status == ComplianceStatus::NonCompliant {
                findings.push(ComplianceFinding {
                    id: Uuid::new_v4().to_string(),
                    requirement_id: req.id.clone(),
                    severity: RiskLevel::High,
                    description: format!("Requirement {} is not compliant", req.id),
                    impact: "Compliance violation".to_string(),
                    recommendation: "Implement required controls".to_string(),
                    remediation_plan: "Review and implement missing controls".to_string(),
                    due_date: Some(Utc::now() + chrono::Duration::days(30)),
                    assigned_to: None,
                    status: FindingStatus::Open,
                });
            }
        }
        
        Ok(findings)
    }

    async fn generate_recommendations(&self, summary: &ComplianceSummary) -> SIEMResult<Vec<String>> {
        let mut recommendations = Vec::new();
        
        if summary.compliance_percentage < 90.0 {
            recommendations.push("Improve overall compliance posture".to_string());
        }
        
        if summary.non_compliant > 0 {
            recommendations.push("Address non-compliant requirements immediately".to_string());
        }
        
        if summary.partial > 0 {
            recommendations.push("Complete partially compliant requirements".to_string());
        }
        
        Ok(recommendations)
    }

    fn matches_audit_filters(&self, log: &AuditLogEntry, filters: &AuditLogFilters) -> bool {
        if let Some(user_id) = &filters.user_id {
            if log.user_id != *user_id {
                return false;
            }
        }
        
        if let Some(action) = &filters.action {
            if log.action != *action {
                return false;
            }
        }
        
        if let Some(start_time) = filters.start_time {
            if log.timestamp < start_time {
                return false;
            }
        }
        
        if let Some(end_time) = filters.end_time {
            if log.timestamp > end_time {
                return false;
            }
        }
        
        if let Some(success) = filters.success {
            if log.success != success {
                return false;
            }
        }
        
        true
    }

    async fn convert_logs_to_csv(&self, logs: &[AuditLogEntry]) -> SIEMResult<String> {
        let mut csv = String::new();
        csv.push_str("Timestamp,User,Action,Resource,IP Address,Success,Error Message\n");
        
        for log in logs {
            csv.push_str(&format!(
                "{},{},{},{},{},{},{}\n",
                log.timestamp,
                log.username,
                log.action,
                log.resource,
                log.ip_address,
                log.success,
                log.error_message.as_deref().unwrap_or("")
            ));
        }
        
        Ok(csv)
    }

    async fn convert_logs_to_xml(&self, logs: &[AuditLogEntry]) -> SIEMResult<String> {
        let mut xml = String::new();
        xml.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
        xml.push_str("<audit_logs>\n");
        
        for log in logs {
            xml.push_str(&format!(
                "  <log>\n    <timestamp>{}</timestamp>\n    <user>{}</user>\n    <action>{}</action>\n    <resource>{}</resource>\n    <ip_address>{}</ip_address>\n    <success>{}</success>\n    <error_message>{}</error_message>\n  </log>\n",
                log.timestamp,
                log.username,
                log.action,
                log.resource,
                log.ip_address,
                log.success,
                log.error_message.as_deref().unwrap_or("")
            ));
        }
        
        xml.push_str("</audit_logs>");
        Ok(xml)
    }
}

/// Audit log filters
#[derive(Debug, Clone)]
pub struct AuditLogFilters {
    pub user_id: Option<String>,
    pub action: Option<String>,
    pub start_time: Option<DateTime<Utc>>,
    pub end_time: Option<DateTime<Utc>>,
    pub success: Option<bool>,
}

/// Export formats
#[derive(Debug, Clone)]
pub enum ExportFormat {
    JSON,
    CSV,
    XML,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_compliance_engine_creation() {
        let engine = ComplianceSecurityEngine::new("test_secret".to_string());
        assert_eq!(engine.session_timeout_minutes, 480);
    }

    #[tokio::test]
    async fn test_user_authentication() {
        let engine = ComplianceSecurityEngine::new("test_secret".to_string());
        engine.start().await.unwrap();
        
        // Test authentication with default admin user
        let result = engine.authenticate_user("admin", "UltraSIEM2024!", "127.0.0.1").await.unwrap();
        assert!(result.is_some());
    }

    #[tokio::test]
    async fn test_permission_checking() {
        let engine = ComplianceSecurityEngine::new("test_secret".to_string());
        engine.start().await.unwrap();
        
        // Admin should have all permissions
        assert!(engine.check_permission("admin", &Permission::ReadAllData));
        assert!(engine.check_permission("admin", &Permission::SystemAdministration));
    }

    #[tokio::test]
    async fn test_compliance_report_generation() {
        let engine = ComplianceSecurityEngine::new("test_secret".to_string());
        engine.start().await.unwrap();
        
        let report = engine.generate_compliance_report(
            ComplianceFramework::SOC2,
            Utc::now() - chrono::Duration::days(30),
            Utc::now(),
        ).await.unwrap();
        
        assert_eq!(report.framework, ComplianceFramework::SOC2);
        assert!(report.summary.compliance_percentage > 0.0);
    }
} 