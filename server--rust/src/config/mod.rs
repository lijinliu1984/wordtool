use std::path::PathBuf;

/// 应用配置（类似 application.yml + @Configuration）
#[derive(Clone, Debug)]
pub struct AppConfig {
    /// 服务监听地址
    pub host: String,
    /// 服务监听端口
    pub port: u16,
    /// 词库数据库文件路径
    pub db_path: PathBuf,
    /// 静态资源目录路径（图片/音频）
    pub resources_dir: PathBuf,
    /// 词库版本号
    pub db_version: String,
}

impl AppConfig {
    /// 从环境变量加载配置，未设置时使用默认值
    pub fn from_env() -> Self {
        Self {
            host: std::env::var("HOST").unwrap_or_else(|_| "0.0.0.0".to_string()),
            port: std::env::var("PORT")
                .ok()
                .and_then(|p| p.parse().ok())
                .unwrap_or(3002),
            db_path: PathBuf::from(
                std::env::var("DB_PATH").unwrap_or_else(|_| "sqlite/vocabulary_study.db".to_string()),
            ),
            resources_dir: PathBuf::from(
                std::env::var("RESOURCES_DIR").unwrap_or_else(|_| "resources".to_string()),
            ),
            db_version: std::env::var("DB_VERSION").unwrap_or_else(|_| "1.0.0".to_string()),
        }
    }

    /// 获取监听地址（host:port）
    pub fn bind_addr(&self) -> String {
        format!("{}:{}", self.host, self.port)
    }
}
