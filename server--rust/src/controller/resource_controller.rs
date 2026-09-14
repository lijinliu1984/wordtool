use std::path::PathBuf;

use tower_http::services::ServeDir;

/// 静态资源服务（类似 Java 静态资源映射配置）
///
/// 托管图片和音频文件，客户端通过 `{server_base_url}/resources/{filename}` 访问。
/// 在 main.rs 中通过 `nest_service("/resources", ...)` 注册。
pub fn create_serve_dir(resources_dir: PathBuf) -> ServeDir {
    ServeDir::new(resources_dir)
}
