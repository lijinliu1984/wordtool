mod config;
mod controller;
mod dto;
mod error;
mod model;
mod repository;
mod service;

use std::sync::Arc;

use axum::routing::{get, post};
use axum::Router;
use tower_http::cors::{Any, CorsLayer};

use config::AppConfig;
use service::download_service::DownloadService;
use service::version_service::VersionService;
use service::word_image_service::WordImageService;

/// 应用共享状态（类似 Spring 容器中注入的 Bean）
pub struct AppState {
    pub version_service: VersionService,
    pub download_service: DownloadService,
    pub word_image_service: WordImageService,
}

#[tokio::main]
async fn main() {
    // 加载配置（类似读取 application.yml）
    let config = AppConfig::from_env();

    println!("=== 疯码单词助手 服务端 ===");
    println!("监听地址: http://{}", config.bind_addr());
    println!("数据库路径: {:?}", config.db_path);
    println!("资源目录: {:?}", config.resources_dir);
    println!("词库版本: {}", config.db_version);

    // 初始化各层服务（类似 Spring 依赖注入）
    let state = Arc::new(AppState {
        version_service: VersionService::new(config.clone()),
        download_service: DownloadService::new(&config),
        word_image_service: WordImageService::new(&config),
    });

    // CORS 配置（允许跨域，移动端无限制）
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    // 构建路由（类似 Spring MVC 路由注册）
    let app = Router::new()
        .route("/api/version", get(controller::version_controller::get_version))
        .route("/api/download", get(controller::download_controller::download_db))
        .route(
            "/api/word/image",
            post(controller::word_controller::update_word_image),
        )
        .nest_service(
            "/resources",
            controller::resource_controller::create_serve_dir(config.resources_dir.clone()),
        )
        .layer(cors)
        .with_state(state);

    // 启动 HTTP 服务
    let listener = tokio::net::TcpListener::bind(&config.bind_addr())
        .await
        .expect("端口绑定失败");
    println!("服务已启动，等待客户端连接...");
    axum::serve(listener, app).await.expect("服务运行异常");
}
