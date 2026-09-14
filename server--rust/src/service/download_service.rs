use std::path::PathBuf;

use tokio::fs;

use crate::config::AppConfig;
use crate::error::{AppError, AppResult};

/// 下载服务（类似 Java @Service）
///
/// 负责读取词库 db 文件内容，供控制器返回给客户端。
pub struct DownloadService {
    db_path: PathBuf,
}

impl DownloadService {
    pub fn new(config: &AppConfig) -> Self {
        Self {
            db_path: config.db_path.clone(),
        }
    }

    /// 读取 db 文件的全部内容
    pub async fn read_db_file(&self) -> AppResult<Vec<u8>> {
        if !self.db_path.exists() {
            return Err(AppError::NotFound(format!(
                "数据库文件不存在: {:?}",
                self.db_path
            )));
        }
        let bytes = fs::read(&self.db_path)
            .await
            .map_err(|e| AppError::Io(e.to_string()))?;
        Ok(bytes)
    }
}
