use crate::config::AppConfig;
use crate::dto::version_response::VersionResponse;
use crate::model::version_info::VersionInfo;
use crate::repository::vocabulary_repository::VocabularyRepository;

/// 版本服务（类似 Java @Service）
///
/// 负责从数据库读取版本信息，与客户端传来的 version_code 对比，
/// 判断是否需要更新。
pub struct VersionService {
    #[allow(dead_code)]
    config: AppConfig,
    repository: VocabularyRepository,
}

impl VersionService {
    pub fn new(config: AppConfig) -> Self {
        let repository = VocabularyRepository::new(&config.db_path);
        Self { config, repository }
    }

    /// 获取版本更新信息
    ///
    /// 从 version_info 表读取最新版本，与客户端 version_code 对比。
    /// 如果服务端 version_code > 客户端版本，返回 has_update = true。
    pub fn check_update(&self, client_version_code: i64) -> anyhow::Result<VersionResponse> {
        // 查询服务端最新版本信息
        let version_info: VersionInfo = self.repository.get_version_info()?;

        // 对比版本号
        if version_info.version_code <= client_version_code {
            return Ok(VersionResponse::no_update());
        }

        // 查询词库统计
        let db_meta = self.repository.get_db_meta()?;

        Ok(VersionResponse::has_update(
            version_info.version_name,
            version_info.version_code,
            version_info.title,
            version_info.update_content,
            version_info.update_date,
            db_meta.word_count,
            db_meta.level_count,
            db_meta.category_count,
        ))
    }
}
