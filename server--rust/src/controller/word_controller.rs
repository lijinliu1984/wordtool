use std::sync::Arc;

use axum::extract::{Multipart, State};
use axum::response::Json;

use crate::dto::word_image_response::WordImageResponse;
use crate::error::{AppError, AppResult};
use crate::AppState;

/// POST /api/word/image - 修改单词图片（multipart 上传）
///
/// 表单字段：
/// - `word_id`：单词 id（i64）
/// - `file`：图片文件（客户端已裁剪为 64x64 的 PNG）
///
/// 返回 `{"pic": "pic/xxx.png"}`。
pub async fn update_word_image(
    State(state): State<Arc<AppState>>,
    mut multipart: Multipart,
) -> AppResult<Json<WordImageResponse>> {
    let mut word_id: Option<i64> = None;
    let mut file_bytes: Option<Vec<u8>> = None;

    while let Some(field) = multipart
        .next_field()
        .await
        .map_err(|e| AppError::Internal(e.to_string()))?
    {
        match field.name() {
            Some("word_id") => {
                let text = field.text().await.map_err(|e| AppError::Internal(e.to_string()))?;
                word_id = text.trim().parse().ok();
            }
            Some("file") => {
                let bytes = field.bytes().await.map_err(|e| AppError::Internal(e.to_string()))?;
                file_bytes = Some(bytes.to_vec());
            }
            _ => {}
        }
    }

    let word_id = word_id.ok_or_else(|| AppError::Internal("缺少 word_id 字段".to_string()))?;
    let bytes = file_bytes.ok_or_else(|| AppError::Internal("缺少 file 字段".to_string()))?;

    let pic = state.word_image_service.update(word_id, &bytes).await?;
    Ok(Json(WordImageResponse { pic }))
}
