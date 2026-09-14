use serde::Serialize;

/// 数据库元信息实体（对应数据库统计信息，类似 Java domain / @Entity）
#[derive(Debug, Serialize)]
pub struct DbMeta {
    /// 单词总数
    pub word_count: i64,
    /// 学段数量
    pub level_count: i64,
    /// 分类数量
    pub category_count: i64,
}
