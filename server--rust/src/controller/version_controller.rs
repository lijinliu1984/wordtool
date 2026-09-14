use std::sync::Arc;

use axum::extract::{Query, State};
use axum::response::Json;
use serde::Deserialize;

use crate::dto::version_response::VersionResponse;
use crate::error::AppResult;
use crate::AppState;

/// 版本检查请求参数
#[derive(Debug, Deserialize)]
pub struct VersionQuery {
    /// 客户端当前 version_code
    pub version_code: i64,
}

/// GET /api/version?version_code=<int> - 检查词库版本更新
///
/// 服务端从 version_info 表读取最新版本号，与客户端传入的 version_code 对比。
/// 返回 has_update 及更新详情；客户端据此决定是否下载。
pub async fn get_version(
    Query(query): Query<VersionQuery>,
    State(state): State<Arc<AppState>>,
) -> AppResult<Json<VersionResponse>> {
    let response = state.version_service.check_update(query.version_code)?;
    Ok(Json(response))
}
