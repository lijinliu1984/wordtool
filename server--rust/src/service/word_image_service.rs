use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

use tokio::fs;

use crate::config::AppConfig;
use crate::error::{AppError, AppResult};
use crate::repository::vocabulary_repository::VocabularyRepository;

/// 单词图片服务（类似 Java @Service）
///
/// 负责接收客户端上传的图片字节，写入资源目录并更新词库 words.pic。
pub struct WordImageService {
    resources_dir: PathBuf,
    repository: VocabularyRepository,
}

impl WordImageService {
    pub fn new(config: &AppConfig) -> Self {
        Self {
            resources_dir: config.resources_dir.clone(),
            repository: VocabularyRepository::new(&config.db_path),
        }
    }

    /// 更新某单词的图片
    ///
    /// 1. 校验单词存在，取旧 pic（用于删除旧文件）
    /// 2. 生成新文件名 `pic/{word_id}_{millis}.png`
    /// 3. 写入 `resources/pic/` 目录
    /// 4. 更新 words.pic
    /// 5. 删除旧图片文件（仅当旧值为 `pic/...` 本地相对路径）
    ///
    /// 返回新的相对路径。
    pub async fn update(&self, word_id: i64, bytes: &[u8]) -> AppResult<String> {
        let old_pic = match self.repository.get_word_pic(word_id)? {
            None => {
                return Err(AppError::NotFound(format!("单词不存在: id={}", word_id)));
            }
            Some(pic) => pic,
        };

        let millis = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|e| AppError::Internal(e.to_string()))?
            .as_millis();
        let rel_path = format!("pic/{}_{}.png", word_id, millis);

        let pic_dir = self.resources_dir.join("pic");
        fs::create_dir_all(&pic_dir)
            .await
            .map_err(|e| AppError::Io(e.to_string()))?;

        let file_path = self.resources_dir.join(&rel_path);
        fs::write(&file_path, bytes)
            .await
            .map_err(|e| AppError::Io(e.to_string()))?;

        self.repository.update_word_pic(word_id, &rel_path)?;

        if let Some(old) = old_pic {
            if old.starts_with("pic/") && old != rel_path {
                let old_path = self.resources_dir.join(&old);
                if old_path.exists() {
                    let _ = fs::remove_file(&old_path).await;
                }
            }
        }

        Ok(rel_path)
    }
}
