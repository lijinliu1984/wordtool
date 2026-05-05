# 疯码单词助手

一个基于 Flutter 开发的跨平台背单词应用，支持 Android、iOS、Windows、macOS、Linux 和 Web。采用"目录 → 分类 → 单词"三级结构管理词库，内置多种练习模式帮助记忆。

## 功能特点

- **三级词库管理**：目录九宫格导航 → 分类列表 → 单词详情，结构清晰
- **多媒体支持**：每个单词可关联音频（听力）和图片（图像记忆）
- **批量导入**：选择包含 JSON + 媒体文件的文件夹，一键导入完整词库
- **六种练习模式**：
  - 翻译练习（看学习词选母语词）
  - 听力练习 A（听音频选图片）
  - 听力练习 B（听音频选母语词）
  - 默写练习 A（听音频输入学习词）
  - 默写练习 B（看图片输入学习词）
  - 默写练习 C（看母语词输入学习词）
- **练习记录**：自动保存每次练习的正确率与每题明细，支持历史回顾
- **数据本地存储**：基于 SQLite，所有数据保存在本地，无需联网

## 界面预览

| 首页目录 | 单词列表 | 练习菜单 |
|:---:|:---:|:---:|
| ![首页](readme/home.png) | ![单词列表](readme/word_list.png) | ![练习菜单](readme/pracctice_list.png) |

| 听力练习 | 练习记录 | 记录详情 |
|:---:|:---:|:---:|
| ![听力练习](readme/pracctice_listen.png) | ![练习记录](readme/pracctice_history.png) | ![记录详情](readme/pracctice_history_detail.png) |

## 安装说明

1. 确保已安装 [Flutter](https://docs.flutter.dev/get-started/install) 环境
2. 克隆仓库后执行：
   ```bash
   flutter pub get
   flutter run
   ```
3. 打包发布：
   ```bash
   flutter build apk        # Android
   flutter build ios        # iOS（需 macOS + Xcode）
   flutter build windows    # Windows
   flutter build macos      # macOS
   ```

## 直接下载

| 扫码下载 |
|:---:|
| ![下载二维码](readme/download_QRCode_420.png) |

## 数据导入

应用支持通过 JSON 文件批量导入词库，JSON 中可同时指定音频和图片的相对路径，导入时会自动将媒体文件复制到应用缓存目录。

### JSON 格式模板

```json
{
  "name": "游戏开发",
  "version": "1.0",
  "categories": [
    {
      "id": "general",
      "name": "通用游戏开发术语",
      "terms": [
        {
          "abbreviation": "",
          "learn_word": "Game Loop",
          "my_word": "游戏循环",
          "description": "每帧更新逻辑、渲染的核心循环",
          "audio": "game_loop_en.mp3",
          "image": "game_loop.png"
        }
      ]
    },
    {
      "id": "programming",
      "name": "编程相关（通用）",
      "terms": [
        {
          "abbreviation": "",
          "learn_word": "Variable",
          "my_word": "变量",
          "description": "存储数据",
          "audio": "variable_en.mp3",
          "image": "variable.png"
        }
      ]
    }
  ]
}
```

### 字段说明

| 字段 | 说明 |
|------|------|
| `name` | 词库名称（作为根目录名称） |
| `categories` | 分类数组，每个分类作为一个子目录 |
| `id` | 分类唯一标识 |
| `name` | 分类显示名称 |
| `terms` | 单词数组 |
| `abbreviation` | 缩写（可选） |
| `learn_word` | 要学习的单词 |
| `my_word` | 母语释义 |
| `description` | 补充描述（可选） |
| `audio` | 音频文件相对路径（不可为空，无音频可填任意占位文件名） |
| `image` | 图片文件相对路径（不可为空，无图片可填任意占位文件名） |

### 快速生成词库

你可以使用 DeepSeek、ChatGPT 等 AI 工具生成词库数据。参考提示词：

> 帮我整理 30 个常用的德语单词，并生成 JSON 格式数据，JSON 格式内容如下：
> ```json
> {
>   "name": "德语基础词汇",
>   "version": "1.0",
>   "categories": [
>     {
>       "id": "daily",
>       "name": "日常生活",
>       "terms": [
>         {
>           "abbreviation": "",
>           "learn_word": "Haus",
>           "my_word": "房子",
>           "description": "名词，中性",
>           "audio": "haus_de.mp3",
>           "image": "haus.png"
>         }
>       ]
>     }
>   ]
> }
> ```
> 其中 audio 和 image 不要空值，用英文命名。

将 JSON 文件和所有媒体文件放在同一个文件夹中，点击应用首页「导入」按钮选择该文件夹即可。

## 联系方式

如有问题或建议，欢迎通过以下方式联系：

| 微信 | QQ |
|:---:|:---:|
| ![微信二维码](readme/wechat-qr.png) | ![QQ二维码](readme/qq-qr.png) |

## 技术栈

- [Flutter](https://flutter.dev/) - 跨平台 UI 框架
- [sqflite](https://pub.dev/packages/sqflite) - SQLite 数据库
- [audioplayers](https://pub.dev/packages/audioplayers) - 音频播放
- [file_picker](https://pub.dev/packages/file_picker) - 文件选择
- [path_provider](https://pub.dev/packages/path_provider) - 路径管理
- [uuid](https://pub.dev/packages/uuid) - 唯一标识生成

## 声明

本项目仅供个人学习、研究使用，禁止商用。
