use std::sync::Arc;

use axum::extract::State;
use axum::http::header;
use axum::response::Response;

use crate::error::AppResult;
use crate::AppState;

/// GET /api/download - 下载词库数据库文件（类似 Java @GetMapping 返回文件）
///
/// 返回完整的 vocabulary.db 文件，客户端下载后替换本地词库数据库。
pub async fn download_db(
    State(state): State<Arc<AppState>>,
) -> AppResult<Response> {
    let bytes = state.download_service.read_db_file().await?;
    let content_length = bytes.len().to_string();

    let mut response = Response::new(bytes.into());
    response.headers_mut().insert(
        header::CONTENT_TYPE,
        "application/octet-stream".parse().unwrap(),
    );
    response.headers_mut().insert(
        header::CONTENT_DISPOSITION,
        "attachment; filename=\"vocabulary.db\"".parse().unwrap(),
    );
    response.headers_mut().insert(
        header::CONTENT_LENGTH,
        content_length.parse().unwrap(),
    );

    Ok(response)
}
