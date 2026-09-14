use serde::Serialize;

/// 词库版本信息（对应 vocabulary_study.db 中 version_info 表）
#[derive(Debug, Clone, Serialize)]
pub struct VersionInfo {
    pub id: i64,
    pub version_name: String,
    pub version_code: i64,
    pub title: String,
    pub update_content: String,
    pub update_date: String,
}
