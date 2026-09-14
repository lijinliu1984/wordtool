use serde::Serialize;

/// /api/word/image 接口响应 DTO
#[derive(Debug, Serialize)]
pub struct WordImageResponse {
    /// 更新后的图片相对路径（如 pic/123_1699999999.png）
    pub pic: String,
}
