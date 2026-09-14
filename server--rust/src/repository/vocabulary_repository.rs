use std::path::{Path, PathBuf};

use rusqlite::{Connection, OptionalExtension};

use crate::model::db_meta::DbMeta;
use crate::model::version_info::VersionInfo;

/// 词库数据访问层（类似 Java @Repository / MyBatis Mapper）
///
/// 以只读方式打开 SQLite 数据库，查询词库元信息和版本信息。
pub struct VocabularyRepository {
    db_path: PathBuf,
}

impl VocabularyRepository {
    pub fn new(db_path: impl AsRef<Path>) -> Self {
        Self {
            db_path: db_path.as_ref().to_path_buf(),
        }
    }

    /// 以只读方式打开数据库连接
    fn connect(&self) -> rusqlite::Result<Connection> {
        Connection::open_with_flags(
            &self.db_path,
            rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY | rusqlite::OpenFlags::SQLITE_OPEN_NO_MUTEX,
        )
    }

    /// 以读写方式打开数据库连接（仅用于修改单词图片）
    fn connect_rw(&self) -> rusqlite::Result<Connection> {
        Connection::open(&self.db_path)
    }

    /// 查询某单词当前的 pic 值（用于换图时删除旧文件）
    ///
    /// 返回 `None` 表示单词不存在；`Some(None)` 表示单词存在但 pic 为空；
    /// `Some(Some(pic))` 表示单词存在且带 pic。
    pub fn get_word_pic(&self, word_id: i64) -> anyhow::Result<Option<Option<String>>> {
        let conn = self.connect_rw()?;
        let pic = conn
            .query_row(
                "SELECT pic FROM words WHERE id = ?1",
                [word_id],
                |row| row.get::<_, Option<String>>(0),
            )
            .optional()?;
        Ok(pic)
    }

    /// 更新某单词的 pic 字段
    pub fn update_word_pic(&self, word_id: i64, pic: &str) -> anyhow::Result<()> {
        let conn = self.connect_rw()?;
        conn.execute(
            "UPDATE words SET pic = ?1 WHERE id = ?2",
            rusqlite::params![pic, word_id],
        )?;
        Ok(())
    }

    /// 查询数据库元信息（单词数、学段数、分类数）
    pub fn get_db_meta(&self) -> anyhow::Result<DbMeta> {
        let conn = self.connect()?;

        let word_count: i64 =
            conn.query_row("SELECT COUNT(*) FROM words", [], |row| row.get(0))?;

        let level_count: i64 =
            conn.query_row("SELECT COUNT(*) FROM word_level", [], |row| {
                row.get(0)
            })?;

        let category_count: i64 =
            conn.query_row("SELECT COUNT(*) FROM categories", [], |row| row.get(0))?;

        Ok(DbMeta {
            word_count,
            level_count,
            category_count,
        })
    }

    /// 查询最新的版本信息（version_code 最大的一条）
    pub fn get_version_info(&self) -> anyhow::Result<VersionInfo> {
        let conn = self.connect()?;
        let info = conn.query_row(
            "SELECT id, version_name, version_code, title, update_content, update_date
             FROM version_info ORDER BY version_code DESC LIMIT 1",
            [],
            |row| {
                Ok(VersionInfo {
                    id: row.get(0)?,
                    version_name: row.get(1)?,
                    version_code: row.get(2)?,
                    title: row.get(3)?,
                    update_content: row.get(4)?,
                    update_date: row.get(5)?,
                })
            },
        )?;
        Ok(info)
    }
}
