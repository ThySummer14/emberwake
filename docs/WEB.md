# 网页试玩与手机操作

网页版本使用 Godot 4.6.3 的单线程 Compatibility 导出。游戏内容、碰撞、敌人、地图、存档结构和原生素材与已发布的 0.8.1 一致；新增独立的浏览器输入层和手机操作面板。未合入仍在验证中的「未焚附页」。

手机建议横屏。方向盘可以滑动，也可以与跳跃、挥刃、冲刺同时按住。向下加挥刃是下劈；获得落砧环后，空中向下加冲刺发动落砧。疗愈需要持续按住。菜单和对话下方另有适合手机阅读、点击的文字和按钮。

点击「载入游戏」，再点击旅途菜单开始。浏览器通常需要点击后才能播放声音。切换标签页或离开窗口会释放按键并暂停；重新回来后点击「继续旅途」。

存档属于当前浏览器、当前网站。无痕模式、禁止网站存储、清理网站数据或换浏览器都可能丢失存档。网页提示不能替代实际关闭再打开的设备验证。网页存档不会自动与下载的原生版同步。

## 本地重建

需要 Godot 4.6.3 和 Python 3。运行 `python3 tools/fetch_web_template.py --extract`，从官方发行包精确读取非线程 Web release 模板，保存到工程内的 `tools/`。脚本验证 HTTPS 来源、范围长度、外层成员 CRC 与内层全部 ZIP CRC；只下载这个成员，因此没有声称验证完整 1.26 GB 发行包的 SHA-256。记录保存在 `tools/web_template_provenance.json`。这不是全局引擎安装。

运行 `python3 tools/build_web.py`。输出在 `dist/`，包含 HTML、JS、WASM、PCK、触屏面板和许可。将整个目录部署到支持 HTTPS 的静态网站。不能通过双击 HTML 的 file:// 路径运行。

Web 版关闭线程和扩展，不需要 SharedArrayBuffer、COOP/COEP 或额外服务工作线程。必须有 WebAssembly 与 WebGL 2。不要修改浏览器安全设置来强行运行。Godot 提供缺失功能提示。

## 验证范围

原生 0.8.1 已有相应 Godot 实际画面证据及 440 项工程检查。浏览器适配另测多指输入、短跳释放、暂停恢复、标题帮助保护存档、菜单和对话，以及中断后的按键释放。DOM 事件模拟与 Godot headless 测试不是手机实机游玩；WebGL 画面、实际音频、触屏手感和 IndexedDB 关闭后恢复需要在支持的浏览器上分别检查。

官方依据：
- https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html
- https://docs.godotengine.org/en/4.6/tutorials/platform/web/customizing_html5_shell.html
- https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable
