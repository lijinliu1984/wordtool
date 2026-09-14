use serde::Serialize;

/// /api/version 接口响应 DTO
#[derive(Debug, Serialize)]
pub struct VersionResponse {
    /// 是否有新版本
    pub has_update: bool,

    /// 以下字段仅在 has_update 为 true 时返回
    #[serde(skip_serializing_if = "Option::is_none")]
    pub version_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub version_code: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub update_content: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub update_date: Option<String>,

    /// 词库统计信息（仅在 has_update 为 true 时返回）
    #[serde(skip_serializing_if = "Option::is_none")]
    pub word_count: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub level_count: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub category_count: Option<i64>,
}

impl VersionResponse {
    /// 构建"无更新"响应
    pub fn no_update() -> Self {
        Self {
            has_update: false,
            version_name: None,
            version_code: None,
            title: None,
            update_content: None,
            update_date: None,
            word_count: None,
            level_count: None,
            category_count: None,
        }
    }

    /// 构建"有更新"响应
    pub fn has_update(
        version_name: String,
        version_code: i64,
        title: String,
        update_content: String,
        update_date: String,
        word_count: i64,
        level_count: i64,
        category_count: i64,
    ) -> Self {
        Self {
            has_update: true,
            version_name: Some(version_name),
            version_code: Some(version_code),
            title: Some(title),
            update_content: Some(update_content),
            update_date: Some(update_date),
            word_count: Some(word_count),
            level_count: Some(level_count),
            category_count: Some(category_count),
        }
    }
}
