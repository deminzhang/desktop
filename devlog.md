# 玄桌面 devlog

README 只留概览、规矩与判据（它开头"本文只留概览"那句是认真的）。
带日期的现场记录 —— 当时量到了什么、据此改了什么、为什么这么改 —— 都搬到这份账里。

- 按时间记账，旧的在上；改完往末尾加一节，**不回头改写历史**（写错了就在新的一节里更正，README 的正文只反映当前结论）。
- 探针与驱动脚本一律**现写现删**（`.tmp/` 有 `.gdignore`、不进 git），所以这里只留判据与数字，不要去找脚本。
- 分工：README ＝ 现状与规矩（`W*`/`V*`/`G*`/`T*`/`X*` 那些编号陷阱表仍在那里）；本文 ＝ 怎么量出来的、踩了什么。
- 附录那份「调试日志线索」是从这里抽出来的索引：日志在哪、`--log-file` 为什么必需、面包屑长什么样。

| 日期 | 这一轮 |
|---|---|
| 2026-10-12 / 10-15 | 壳的开关全部搬进托盘；盘上的五星古名、节气刻、驿马着色 |
| 2026-10-16 | 原生件搬进进程内（门 1/2/3）；DLL 链补 `__USE_MINGW_ANSI_STDIO`；托盘标签乱码（G41） |
| 2026-10-21 | 桌面窗看护（W8）：丢了就重启进程 |
| 2026-10-26 | 第二次丢失，与 `wallpaper layer '<state>'` 那一行 |
| 2026-10-26 16:05 | 部署到真机、自愈第一次生效；"挂高一层"量了第二遍 |
| 2026-10-27 | 星空搬到纯黑副屏；上限那一处漏网（真 bug，已修） |
| 2026-10-27 18:20 | 月所在的那一宿用白字；"导出在原地"继承 Low 标签（T25 的新变种） |
| 2026-10-28 | 三垣补进星官图；星座开关改为默认关 |
| 2026-10-28 14:02 | 重导交付件（星座默认关这一版）：装好的 Steam Godot 直接导出即成功、包可复现、交付的 exe 自证默认关 |

---

## 2026-10-12 / 2026-10-15 · 壳的开关搬进托盘，与盘上那几处细节

- 10-12 一度把**壳自己的** `桌面` 开关转到盘左下角（`Background` 接口里给它留了 `hud_shell_slot()` 那个座）。
- 10-15 用户要求删掉那颗 chip ⇒ `hud_shell_slot()` 与它的座一起从接口里去掉。壳自己的开关反过来全部只留托盘：
  原来的 `桌面`（壁纸窗）＋ 新增的 `面板`（HUD 窗，只在这次运行真有 HUD 窗时画）。时间栏左列第三行那颗 `桌面` 也一并删掉 ⇒
  **`桌面` 从此只有托盘那一处座位**。
- 状态仍然只有客户端一份（`_desktop_shown`），谁动都走 `_toggle_desktop`，与 `Ctrl+Alt+H` 同一条路。
- 同一天定下的其余细节：
  - **五星两套名**（`星宿` 关＝`水/金/火/木/土星`，开＝`辰星/太白/荧惑/岁星/镇星`；天王、海王不属五行，名字不随开关）。
  - **廿四节气**名（λ 每 15° 一格，刻只往黄道**北侧**画、不画圈；**当令那一个**用青色、其余 23 个灰一档）。
  - **驿马 `马`**（r 92，正写，每过一个天空秒晃一下；按所落之支的五行着色 —— 寅青 / 申白 / 巳赤 / 亥玄）。

## 2026-10-16 · 原生件搬进进程内，与 `__USE_MINGW_ANSI_STDIO`

### 原生件搬进进程内那一轮的实测

探针与驱动脚本都是**现写现删**的（README 验证表里的手法照旧），所以这里只留判据与数字：

| 门 | 覆盖 | 结果 |
|---|---|---|
| 门 1 | 扩展框架、变体封送、`ptrcall` 派发 | **6/6** |
| 门 2 | 原生件逐项行为（走 `test()` 钩子） | **27/27**，只能在 debug DLL 上跑 |
| 门 3 | 指标采集（含真下载喂网卡） | **16/16**；峰值 75.9 MB/s，空载 28 KB/s |

门 1 与门 3 都是在**出货的 release DLL** 上跑的；门 2 换上 release DLL 会因为 `test()` 不存在而**直接编译失败** ——
这本身就是出货面干净的证据（release DLL 里既没有 `_gdext_init.log` 面包屑，也没有 `test()`）。

运行时（外部 `EnumWindows` ＋ 截图差分 ＋ 真实按键注入）：

- `SetParent … err=0`，父窗口是真正的 `WorkerW`；水族箱出现在 Progman 的子窗口表里。
- 副屏截图前后 **98.5%** 像素变化。
- 托盘：`HKCU\Control Panel\NotifyIconSettings` 出现新键，`ExecutablePath = E:\xuandesk\XuanDesk.exe`。
- 穿透：`Ctrl+Alt+T` 把 HUD 的扩展样式在 `0x8000098 ↔ 0x80800B8` 之间翻，同时 `WindowFromPoint`
  （Windows 给鼠标点击用的那同一套命中测试）从 HUD 变成它下面的浏览器窗口；`Ctrl+Alt+Q` 之后进程为 0。

### 给 DLL 链补上 `__USE_MINGW_ANSI_STDIO` 那一轮

补开关 → 重编 → 重出 → 把上面的判据重跑一遍（探针照旧现写现删）：

- **帧里的 64 位字段**（`start()` ＋ 8 帧）：`hinst=140734492901376`（> 2³²，只有真 `%llu` 印得出来）、`hud_hwnd=18446744073709551615`
  （即 -1）、`mem_total=68327845888`、`vram_used=6675/8188`、`gpu_temp=40`、两台 2560×1440 显示器主次正确
  ——8 帧全被 `JSON.parse_string` 吃成字典，没有一帧是垃圾数。
- **托盘**：`start()` 自报 `tray_added:1 tray_err:0 icon_ok:1`（Low 标签用"复制出去 → 删掉 → 移回来"洗掉后，`Shell_NotifyIcon` 不再 err=5）。
- **挂载**：外部 `EnumWindows` 看到 `XuanDesk.Aquarium`（`ParentClass=WorkerW`、2560×1440、可见）与顶层 `XuanDesk.HUD`。
- **改名后的信号链**（跑的就是交付的 exe ＋ PCK ＋ DLL，真按键注入）：`XuanDesk: native event 'toggle_clickthrough'`
  → `XuanDesk: HUD mouse passthrough on`，即扩展发事件 → `MetricsClient.native_event` → `hud_window.gd::_on_native_event` 全程通；
  同一次 emit 也调了 `main.gd::_on_native_event`（两条 `connect` 挂同一个信号，方法不存在 GDScript 会当场报 nonexistent function，日志里没有）。
- **交付件**：`XuanDesk.exe` 109,205,504 B ＋ `XuanDesk.pck` 2,100,784 B ＋ `xuandesk_native.dll` 133,451 B，三件标签都干净。
- **托盘标签**（debug 面包屑，跑的就是交付的 exe ＋ 修好的 DLL）：四个标签的字节长度全部等于字面长度 —— `水族箱` 9 B、`星空` 6 B、
  `主屏 2560×1440` 17 B、`副屏 1 2560×1440` 19 B。修前那一行读回来是 21 B（多出的字节在菜单里就是乱码，见下面 G41 那条）。

`Ctrl+Alt+H` 与 `Ctrl+Alt+Q` 的复核卡在环境上：测到一半显示器/会话进了非活动桌面（`SendInput` 返回 err=5、`GetForegroundWindow()=0`、
副屏截图整张全黑、WASAPI 掉设备），注入进不去。那是环境状态而不是应用行为，信号链本身已由上面那次 `Ctrl+Alt+T` 验到。

体积（T23）：本机 gcc 15.1.0 不加 `-D__USE_MINGW_ANSI_STDIO=1` 也把 `%llu` 印对，加上只是换成 mingw 自带的 printf，
实测 DLL 85,016 B → 114,023 B（+29,007 B，不含托盘资源；交付的 DLL 含 `tray_res.o` 19,474 B，共 133,451 B）。

### 托盘菜单标签乱码（G41）

2026-10-16 用户又报了一次：换桌面里的「星空」后面有乱码。同一个症状有**两层**，先前只治了第一层。

- **一**：`copy_str` 按字节截标签，按字节丢续字节会吃掉每个中文标签的最后一个字 —— 截断要**按字符**判（`trim_utf8`）。
- **二，真凶**：`string_to_utf8_chars` 的文档原文就是 **"It doesn't write a null terminator"**，而且 `p_max_write_length` 数的是**字符**、
  不是字节（一个字符最多 4 字节）。三个调用点却都当它写了 NUL 用，于是解析器读到了栈上残留：实测一条 17 字节的托盘行回来是 22 字节
  （多出的 4 个字节被 `MultiByteToWideChar` 变成 U+FFFD，中文标签后面就挂上乱码），那个按字符计的限长还能对一行 CJK 写出 4 倍缓冲区的长度
  （`line[512]` 会溢出）。处置：`string_to_utf8_bounded()` —— 先把缓冲区清零当终止符，再让引擎最多写 `(cap-1)/4` 个字符（即最多 cap-1 字节）。
- **判据**就是 debug DLL 的那行面包屑 `menu item[i] label N B: …`：修前「主屏 2560×1440」是 21 B，修后 17 B，四个标签全部等于字面长度。

## 2026-10-21 · 桌面窗看护那一轮

一夜之后桌面窗被销毁、托盘与 `Ctrl+Alt+H` 全成空转（W8），补上"检测到丢失就重启进程"的看护后，用 README 验证表那条**看护自测**实测：

- **触发**：headless 一代 `wall=waiting` 满 12s 就打印
  `XuanDesk: desktop window lost (wall=waiting for 12039 ms) - restarting: …godot.windows.opt.tools.64.exe --path E:/xuandesk
  --log-file …/logs/godot-restart-<ts>.log -- --wallpaper=1 --hud=0 --exit-after=17 --background=sky --desktop-screen=0 --wall-restart=3`。
  `--path` 只有编辑器版形态带（导出形态自己认 PCK），`--log-file` 是必需的：本代还攥着 `godot.log`（Windows 上改不动别人的打开文件，
  实测 `DirAccess.rename_absolute` 返回 1），而下一代开机就会轮转它，不给它一条自己的日志路径就等于下一代没有日志；
  `--background` / `--desktop-screen` 是**客户端当前状态**、不在原命令行里，所以由看护写回去——否则自愈会把用户的星空挪回主屏。
- **下一代真起来了**：`EnumWindows` 顶层多出 `XuanDeskTray` 与 `XuanDesk.Aquarium (DEBUG)`（编辑器版会给标题加 `(DEBUG)`，扩展按前缀认），
  pid 与本代不同，活到 `--exit-after` 到点后干净退出，没有遗留进程；沙箱里它挂不上 WorkerW（低完整性 token 被 `SetParent` 拒，README 早有记录），
  所以那两个窗停在顶层——真机形态下走的是每次正常启动都一样的那条挂载路径。
- **上限**：`--wall-restart=3` 的一代只打印 `XuanDesk: the desktop window is still gone after 3 restarts - leaving it alone`，不再产生任何进程。
  计数跨代传，所以上限是"一次运行最多重启 3 次"，而不是"每代各自 3 次"（后者是死循环）。
- **不能就地重建**（这条路被删掉了）：`get_window().hide()` 被引擎直接拒绝——`ERROR: Can't change visibility of main window.`。
  G9 说的是 `Window` **节点**（HUD 就是），进程主窗不吃这一套；真想省掉重启，就得把桌面自己做成一个 `Window` 节点。
- **沙箱的限制**（不是应用行为）：沙箱不许往 `%APPDATA%\Godot\app_userdata\…` 写文件，而 `OS.create_process` 又不把 stdout 交给子进程，
  于是下一代在沙箱里"隐身"——只能靠上面那条窗口标题判据看到它。真机（非沙箱）跑就会留下 `godot-restart-<ts>.log`。

现场（这一轮为什么会有这条看护）：2026-10-21 开了一晚之后实测到的 —— 桌面树里 1081 个窗口按标题、按类名都找不到 `XuanDesk.Aquarium`
（同进程的 `XuanDesk.HUD` 与托盘窗都在），日志里 2610 条 `VK_ERROR_SURFACE_LOST_KHR`，而系统侧
`TranscodedWallpaper` 在会话解锁后 48s 被重写——正是桌面层被重建的时刻。之前把「隐藏再显示桌面」当成失而复得的手段（`_toggle_desktop`），
那只在**窗口还活着**时成立。

## 2026-10-26 · 第二次丢失，与状态日志那一行

同一个故障在**还没部署修复**的那一版上又发生了一次（10-20 13:33 起的进程一直没退，跑的是 10-16 的 PCK）：

- 窗口又是真的没了：**递归**枚举整棵树（不只是顶层）都没有 `XuanDesk.Aquarium`，只剩 `XuanDesk.HUD` 与托盘窗（同一个 pid）。
- `godot.log` 在 **10-25 22:58:05** 停笔，最后 61.7 MB 全是 `swap_chain_resize` 的 `VK_ERROR_SURFACE_LOST_KHR`；
  而日志里最后两条客户端记录是 `native event 'toggle_desktop'` → `3D desktop hidden`、再来一次 → `shown`——
  那就是用户按了两次托盘 `桌面`：客户端以为显示了，扩展找不到窗口，与 10-21 的症状一字不差。
- 想直接换包会被拒：`XuanDesk.pck` 被在跑的实例攥着（`move /y` 报 "Cannot create a file when that file already exists"），
  两个文件都没坏 ⇒ **换包前进程必须先退出**；`.tmp/tools/deploy.bat` 就是按这条写的（先退出，再跑它＝换包＋启动，
  它自己会拒绝在进程还在时动手）。
- 客户端因此补了一行**状态日志**：壁纸层状态一变就打印 `XuanDesk: wallpaper layer '<state>'`（`waiting` / `no-worker` / `ok` / `hidden`），
  于是"丢失"这件事从此在日志里是**明写**的：新包一代丢窗会留下 `wallpaper layer 'waiting'`，接着是那条重启行，下一代挂上则是 `'ok'`。

## 2026-10-26 16:05 · 部署那一轮，与自愈在真机上的第一次生效

把 10-21 造的看护真正装到用户那台机器上：只换 `XuanDesk.pck`，`XuanDesk.exe` 与 `xuandesk_native.dll` 一个字节没动。

- **先修导出**：10-21/10-26 两次 `--export-pack` 出来的包里 `project.binary` 是坏的——交付的 exe 一跑就报
  `ERROR: Corrupted header in binary project.binary (not ECFG)` 与 `ERROR: Couldn't load file 'res://project.binary'`。
  后果很隐蔽：脚本、背景、挂载全照常（星空照出、WorkerW 照挂），**唯独工程设置整块丢了**，而 `debug/file_logging/*` 也在里面
  ⇒ 那一版**根本不写 `godot.log`**（文件被建出来、一直是 0 B）。日志这条诊断线等于断的，而它正是这次要用的东西。
  真因是导出时编辑器写自己的 `editor_data/temp/tmpproject.binary` 失败（那几行 `ERROR: Couldn't save project.binary …`
  当时被当成无关的缓存噪音）。重导后 `--export-pack` 退出码 0、无 ERROR，包 2,103,392 B；
  另外 `--export-pack` 的**落点目录不存在时会直接失败**（`无法以写入模式打开路径…`，退出码 1）——建目录这条别省。
- **自愈真机生效**（这次是**改壁纸**触发的，不是锁屏）：`SystemParametersInfo(SPI_SETDESKWALLPAPER)` 换掉桌面背景，
  Explorer 重建那一层，`XuanDesk.Aquarium` 当场从树里消失（同一 pid 只剩 `XuanDesk.HUD` 与托盘窗）。随后日志按顺序写下
  `wallpaper layer 'ok'` → `'waiting'` → `desktop window lost (wall=waiting for 12002 ms) - restarting: …XuanDesk.exe
  --log-file …godot-restart-2026-10-26T16.05.44.log -- --background=sky --desktop-screen=1 --wall-restart=1`，
  新 pid 起来后 `XuanDesk.Aquarium` 又回到 `WorkerW ← Progman`、2560,0 2560×1440。
  **"改壁纸"是这条故障的又一个触发器**——W7 里"Windows 主题会轮换壁纸图、症状过一会儿才出现"说的是同一件事，这次抓到了现场。
- **导出形态的 `godot.log` 是带缓冲的**：一代活着的期间它可能一直是 0 B，**退出时才整段落盘**（退出那代留下 3272 B，
  从 `sky: 9096 stars` 到那条重启行一条不少）。所以读日志的正确姿势是**看上一代的 `godot.log`**；自愈那一代自己那条
  `--log-file` 要等它自己退出才有内容。想同时看活的，就把 stdout 重定向到文件再启动（引擎把同一批行也写在那里，且是及时的）。
- **W7 又量了一次**：同刻跑着截一张、杀掉再截一张，副屏差 **MAE 0.34、变化像素 1.90%，且全部落在最下面 48 行的任务栏里**
  ⇒ 星空窗在那块屏上**一个像素都没露**。同时读到 `BackgroundType=2`（一张照片）、`TranscodedWallpaper` 的改动时间是当天 09:30:39
  ——**要看见星空，那块屏的桌面背景必须是纯色**（W7 的前置条件）。（当天夜里复查时更正：`Interval` 那次查错了键，它不是空，
  而是 24 小时，见下一条。）
- **桌面背景到底是谁换的**（当天夜里的复核）：`HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers` 的
  `BackgroundType=2` + `HKCU\Control Panel\Personalization\Desktop Slideshow` 的 **`Interval=86400000`、`Shuffle=0`**，
  历史路径 `BackgroundHistoryPath0..4` 全是 `c:\windows\web\wallpaper\{windows,themea,themeb,themec,themed}\*.jpg`
  ⇒ **桌面背景是"Windows 主题图片"的 24 小时幻灯片，它自己会换图**（不是用户按的）。
  这也是同一台机器上第二个症状的来源：**每次换图都会重建那一层、杀掉壁纸窗**（W8）——两个症状一个病根。
  设成纯色同时解掉两件事：照片不再盖住星空，也没有图可轮换、不会再每天杀一次窗。
- **"挂高一层"试过了，不通**：层堆叠只有两层——`Progman` 的子窗按 z 序是 `SHELLDLL_DefView`（0,0 5120×1440，双屏一整块）
  在其一、我们所在的 `WorkerW` 在其下。把一次性白色探针窗 `SetParent` 进 `SHELLDLL_DefView` 并压到 z 序最底
  （`parent(class)=SHELLDLL_DefView`、style 0x54000000、rect 0,0 2560×1440，都成功）之后，屏幕近白像素 **0.0%**、差图 MAE 0.13
  ⇒ 画照片的是 DefView **内部更上面**的图标视窗；能盖住照片的位置同样会盖住图标。W7 的"必须纯色"不是懒办法，是唯一解。

## 2026-10-27 · 星空搬到纯黑副屏，以及上限那一处漏网

用户问的是"是不是系统自动换屏照盖掉了星空，能不能让星空不被盖"。两半都量了。

- **是系统换的**：桌面背景是 Windows 主题图片的 24 小时幻灯片（`BackgroundType=2` + `HKCU\Control Panel\Personalization\Desktop Slideshow`
  的 `Interval=86400000`，见上一节末尾）。它自己换图，不用用户按。
- **"挂高一层"不通**：层堆叠只有两层——`SHELLDLL_DefView` 在上、我们所在的 `WorkerW` 在下，两个都跨双屏（0,0 5120×1440）。
  把一次性白色探针窗挂成 `SHELLDLL_DefView` 的最底层子窗（`SetParent` 成功、style 0x54000000），屏幕近白像素仍 **0.0%**。
- **"纯色"要用对接口**：`IDesktopWallpaper::SetWallpaper(monitorID, "")` **不是**纯色——它的效果是**撤掉那一块屏的独立设置、跟随全局**
  （实测：副屏立刻变成主屏那张 `img22.jpg`；应用停掉时那块屏 `dark(<12)` 只有 5.3%，纯黑该接近 100%）。
  真正管用的是**给那一块屏单独设一张纯黑图**：`%LOCALAPPDATA%\XuanDesk\solid-black.png`（2560×1440 全黑 PNG，10,811 B）。
  实测落地后：应用停掉时 `mean 13.18 / median 0 / dark 74.3%`，应用跑着时 `mean 64.41 / median 69 / dark 0.0%`，
  两者差 **MAE 51.31、变化像素 76.09%** ⇒ 星空确实画在黑底之上（对照：10-26 被照片盖住时同一条判据只有 MAE 0.34）。
  主屏的幻灯片一个字节没动（`GetWallpaper([0])` 前后都是 `img22.jpg`）。
  这台机器现在的状态：**DISPLAY1 幻灯片、DISPLAY2 纯黑图 + 星空**。
- **`SetBackgroundColor()` 本身也会触发重建**：`SetWallpaper` 那次因为路径写错（`img24.jpg` 在 ThemeB 不在 ThemeA）抛了 `0x80070002`，
  但前面的 `SetBackgroundColor(0)` 已经把层重建、把壁纸窗打掉了（日志照样 `'ok'` → `'waiting'`）。触发器又多一个。
- **上限那一处漏网（真 bug，已修）**：这天三次自愈（09:37:14 / 09:38:40 / 09:40:45）每一代都以 `--wall-restart=1` 结尾，
  说明计数从没跨代累加过。元凶在 `_watch_desktop_window()`："状态不是 `waiting`"的分支**每帧**都把 `_wall_restarts` 与
  `_wall_restart_since` 清零——可**一次成功挂载正是重启循环的样子**（重启、挂上、又丢），于是上限永远够不着；
  我自己的测试 4 分钟换了 4 次壁纸就拿到 4 次重启。（另一处 `_ready` 里已把 `_wall_restart_since` 置为当前时刻，
  本来无害，是配合第一处才致命。）改法：健康分支只清 `_wall_waiting_since` 与 `_wall_gave_up`，**计数留着按时间过期**
  （`WALL_RESTART_WINDOW_MS`，在 `_restart_process()` 里判）——于是"一天丢一次"永远能重启，"10 分钟内丢 4 次"会停下。
- **A/B 证明**：用 `--wall-restart=3` 起一代（等于"已经烧掉 3 次"），再改一次背景色制造丢失 ⇒
  `wallpaper layer 'ok'` → `'waiting'` → `the desktop window is still gone after 3 restarts - leaving it alone`，
  **pid 自始至终没变**（旧包在同一场景下必定重启）。随后起一代干净的，挂载与星空都正常。
- **换包的两个坑**（今天现学的）：`godot.windows.opt.tools.64.exe` 是 GUI 子系统，用 `&`／`Tee-Object` **抓不到它的标准输出，
  `$LASTEXITCODE` 也是空的** ⇒ 必须 `Start-Process -RedirectStandardOutput/-RedirectStandardError` 再读文件；
  而 `Start-Process -ArgumentList @('--export-pack','Windows Desktop',…)` 会把**预设名里的空格拆成两个参数**
  （Godot 报 `Invalid export preset name: Windows.`）⇒ 预设名要单独加引号，或整条命令串成一个字符串。
- **这一版的包**：`XuanDesk.pck` 2,103,312 B（10-27 09:45；`XuanDesk.exe` 109,205,504 B 与 `xuandesk_native.dll` 133,451 B 仍未动）。
  交付形态复核：交付的 exe 跑 `--headless -- --wallpaper=0 --hud=0 --exit-after=6`，退出码 0、stderr 无 `project.binary` 报错、
  默认路径 `godot.log` = **645 B**（与 10-26 那个好包复核时一字不差）。
  回滚件：`XuanDesk.pck.ok-1026`（2,103,392 B，10-26 那版）、`XuanDesk.pck.old`（2,100,784 B，10-16 原版）。坏的 `XuanDesk.pck.bad` 已删。

## 2026-10-27 18:20 · 月所在的那一宿用白字，与"导出在原地"那一坑

用户要的："月入某宿时，所在宿名用白字色显示，其它27宿不变"。

- **实现**：`Mansions.index_of_direction()`（由赤经算宿号，与盘上分野刻同一把尺）→ `SkyLabels.set_mansion_current()` →
  摆位时把月所在那一宿**先放、用白字**，其余 27 个照旧淡金；判据在 `Sky._moon_mansion()`，随每个时间步更新一次（宿没换就不重绘）。
  摆位优先级里"月所在那一宿"先于其余 27 个，免得它被相邻宿名挤掉。
- **两条独立判据都过**：headless 探针（28 个宿的中段往返 28/28 正确；28 个距星边界往返 19 个精确、9 个因 float32 约 1e-5°
  读回上一个宿，仍在容差内；40 天的月全部落在某个宿的跨度内）0 失败；**交付的 exe 自己出的那帧**（`--shot`，
  2026-10-27T12:00Z，月入胃宿）按像素读：**胃 = 34 中性白 / 0 金**，同帧可判的四个宿（室 23 金 / 奎 17 金 / 娄 16 金 / 昴 54 金）
  **全 0 白**（壁那格只 26 px 亮，颜色判不出，不计）；把时间推到月入井宿那一代，胃又回到金、0 白 ⇒ 白字确实跟着月走。
  这条判据不能写成"白像素最多的那个"：**月盘本身也是中性白**，同帧它比宿名大（要按墨团尺寸分开）。
- **这一版的包**：`XuanDesk.pck` **2,103,936 B**（18:17:47，比 10-27 09:45 那版多 624 B = 这次改动）；
  `XuanDesk.exe` 109,205,504 B 与 `xuandesk_native.dll` 133,451 B 一个字节没动。
- **"导出在原地"＝新 exe 与 pck 都继承 Low 标签（T25 的新变种，这次代价是整晚）**：导出把两个文件直接写进 `E:\xuandesk`
  （目录带 Low 标签）⇒ 都是 `Mandatory Label\Low Mandatory Level:(I)(NW)`。于是**无论谁拉起它**都以 Low 令牌运行：
  `Shell_NotifyIcon` 被拒（托盘里没有图标——用户："我启动了exe，没有托盘，无法退出"）、跨进程 `SetParent` 被拒
  （壁纸窗的父窗停在桌面窗 `#32769`，客户端自报 `wallpaper layer 'failed'`）、而且**只能写带 Low 标签的工作区**
  （写 `.tmp`／`%APPDATA%` 全失败、写项目根成功——一开始把它误读成"DSH 沙箱的路径授权"，直到量了令牌）。
  三条对照：同一个文件**复制到 `%TEMP%`** = Medium；**复制到 `E:\XuanDeskApp`** = Medium；**留在 `E:\xuandesk` 里**
  （同一个 exe 改名也一样）= Low；**计划任务（svchost 拉起）也是 Low** ⇒ 判据是**文件标签**，与父进程、路径、谁来启动都无关。
  修：`icacls … /setintegritylevel Medium` 在本 shell 里被拒（Access is denied），**复制出去 → 移回来**可以
  （重命名不重新继承标签）；`.tmp/tools/relabel_delivery.ps1` 就是这一对动作，**以后每次导出后跑一次**。
  修好后在同一路径的实测（就是项目根这份交付件）：令牌 `Medium`、`XuanDesk.Aquarium` 的父链
  `WorkerW '' <- Progman 'Program Manager'`、托盘图标注册在任务栏 2219,1392、客户端自报 `wallpaper layer 'ok'`、
  窗口 2560,0 2560×1440（DISPLAY2）、三件字节数与时间戳不变。
- **托盘在不在，不必问眼睛**：`FindWindowA("XuanDeskTray")` 取到托盘窗，再 `Shell_NotifyIconGetRect(hwnd, UID=1)`
  （UID 读 `HKCU\Control Panel\NotifyIconSettings` 里 `ExecutablePath = …\XuanDesk.exe` 那条）——注册着给 rect，
  没注册给 `0x80004005`。量令牌用 `.tmp/tools/token_level.ps1`（Low 令牌下 `NIM_ADD` 与 `SetParent` 都会 err=5）。
- **导出还有两个小坑**：项目根放着的草稿资源（当时是 `fenye_probe_map.png` 与它的 `.import`）会被
  `export_filter="all_resources"` **打进 pck**（+54,072 B）⇒ 草稿一律挪进 `.tmp`（那里有 `.gdignore`）；
  导出时 stderr 总会留一句 `Safe save failed … file_access_windows.cpp:277` 并留下一个 `xuandesk_native.dll<随机>.tmp`
  （导出进程自己加载着那个 DLL，改名失败），**无害**（残留件与交付件 sha256 相同），每次删掉即可。

## 2026-10-28 · 三垣补进星官图

- **数据**：`MansionFigures.ENCLOSURES` 收紫微垣 39、太微垣 20、天市垣 19，共 78 星官 304 星 314 条；与 28 宿合计
  287 星官 1261 条、1173 颗互不相同、860 段（探针 0 条失败）。来源与逐星处理见 `backgrounds/sky/data/SOURCES.md` 的「三垣」节。
  至此星名的总数：9096 颗里 **1173 颗**有名字（88 星座名 ＋ 28 宿名 ＋ 287 星官 1261 条星名
  （28 宿 209 星官 947 条 ＋ 三垣 78 星官 314 条；1173 颗互不相同）＋ 廿四节气名；2026-10-28 探针实测）。
- **画法**：三垣与 28 宿同层同色，共用 `MansionFigures.chains()/anchors()`；`Sky._build_mansion_figures()` 的日志行改成
  `星官图 … 287 星官 1261 星, 860 段`。
- **这一版的包**：`XuanDesk.pck` **2,108,256 B**（10-28 11:55，比 10-27 18:17 那版多 4,320 B＝三垣表）；`XuanDesk.exe`
  109,205,504 B 与 `xuandesk_native.dll` 133,451 B 未动。交付 exe 复核：`--headless -- --wallpaper=0 --hud=0 --exit-after=6`
  日志 676 B，末行 `shutting down`，无 `project.binary` 报错；包标签 Medium。
- **导出环境**：这台机器的 Godot 是 Steam 便携版（exe 旁有 `._sc_`），`editor_data` 在 Program Files 下不可写，
  `--export-pack` 会重演 10-26 的 `Couldn't save project.binary … tmpproject.binary` 坏包。绕法：把 Godot exe、
  `._sc_` 和 `export_templates/4.7.2.stable` 的 Windows 模板复制到 `%TEMP%\godot_build`，用那份便携副本导出，
  `project.binary` 即正常。回滚件：`XuanDesk.pck.ok-1027-1817`（2,103,936 B，10-27 18:17 那版）。

---

## 2026-10-28 · 星座开关改为默认关

用户要的："星座开关默认改为关"。四处默认值一起翻，**没有**只改命令行那一处：

- `Sky._figures_shown`：`true` → `false`（字段初值），并且 `_build_catalogue()` 里那一行从
  `opts == null or opts.flag("sky_figures", true)` 改成 `opts != null and opts.flag("sky_figures", false)`
  —— 注意 `opts == null` 那一支的含义跟着反了：没有 `Args` 时以前是"默认开"，现在必须是"默认关"（`and` 而不是 `or`）。
- `SkyLabels._figures_shown`：同样 `true` → `false`（88 星座名与图线同一条开关，得一起关）。
- 盘上那颗 `星座` chip 的初值本来由天空经 `SkyTimeBar.set_switch()` 下发（`build_hud()` 里调 `_show_layer_switches()`），
  所以无需改；但 chip 那个"天空没说就点亮"的兜底 `_switch_state.get(id, true)` 现在会撒谎（`星宿` 仍是默认开），
  改成按 id 查的 `SWITCH_DEFAULT := {"figures": false, "mansions": true}`。
- `星宿`（`--sky-mansions`）默认**不动**：三垣、星官、廿四节气名照旧默认画。
- README 里两处跟着改：命令行表的默认列 `1` → `0`，以及「盘外的两条地支环与开关」那节点明 `星座` 默认关。

判据（出图三张 ＋ HUD 两张；主视口 2560×1440、HUD 300×340；都带 `--sky-time=2026-10-27T12:00:00Z --sky-rate=0`）：

| 比法 | 结果 |
|---|---|
| 同参数两次（**噪声底**） | **2352 px（0.064%）**，散在全画幅、均值≈0 —— 星空出图本来就不是逐次逐像素可复现的 |
| 默认 vs 显式 `--sky-figures=0` | **759 px（0.021%）**，在噪声底**之下** ⇒ 默认＝关 |
| 默认 vs `--sky-figures=1` | **53080 px（1.44%）**，变化像素的均值 +17.7/+23.6/+24.8（蓝占优，与 `SkyLines.FIGURE_COLOUR` 同向）⇒ 88 图线确实由这颗开关加进来 |
| `--sky-figures=0` vs `=1` | 53486 px |
| HUD 上 `星座` chip 的内部 | 默认那张比**同一张卡上**的 `星宿` chip（仍是开）暗 **40.8**（45.2/77.3/89.4 对 49.5/130.5/154.2）；加 `--sky-figures=1` 后两格**完全同色** |
| chip 的旋钮 | 默认是**空心环**（中心 18/43/53 暗、环上 37.8/67.9/79.4 亮）；开着时整颗是实心点（中心＝环＝76/217/255 的强调色） |
| `星宿` chip（负对照） | 两张 HUD 出图之间 **0/912 px** 变化 —— 动的只有 `星座` 那一格 |

> chip 那格的坐标不是写死的，按卡自己的常量算：`Sky.hud_size()` 300×340、`Sky.HUD_COMPASS_HEIGHT` 300、`SkyTimeBar.ROW_LEFT` 12 / `ROW_TOP` −52 / `ROW_MIDDLE` −28 / `ROW_SIZE` 38×24。
> **噪声底这条留着**：同参数两次也会差两千来个像素（0.064%），所以"逐像素相等"不能当判据 —— 先量一张重复图当底，再比倍数。

---

## 2026-10-28 14:02 · 重导交付件（星座默认关这一版）

用户要的："重导可执行文件"。这一版把上一节那几处 `.gd` 改动装进交付件。

- **这一轮的 shell 是 Medium**，`E:\…\Godot Engine\editor_data\temp` 直接可写 ⇒ 10-27 那套"把 Godot exe、`._sc_`
  和 Windows 模板复制到 `%TEMP%\godot_build` 再用便携副本导出"的绕法**这次没用上**：装好的 Steam Godot 直接导出
  就成功，没有再出现 `Couldn't save project.binary … tmpproject.binary`（那个坑的根源是 Low 标签下 `editor_data` 写不进去）。
- 命令：`--headless --path E:\xuandesk --export-release "Windows Desktop" <工作区外的暂存目录>\XuanDesk.exe`。
  两条老规矩照旧：预设名带空格 ⇒ 整条命令行作为**一个**字符串交给 `Start-Process -ArgumentList`（拆成数组就会
  在空格处断开）；引擎是 GUI 子系统 ⇒ 必须 `-RedirectStandardOutput/-RedirectStandardError` 再读文件（`&` 抓不到）。
- 产物：exit 0、stderr 空；`XuanDesk.exe` 109,205,504 B、`XuanDesk.pck` 2,108,304 B、`xuandesk_native.dll` 133,451 B。
  预设里虽然写着 `debug/export_console_wrapper=1`，这次的产物里**没有** `XuanDesk.console.exe`，与旧交付件一致。

判据：

| 比法 | 结果 |
|---|---|
| 新导的 exe / dll 与旧交付件比 sha256 | **完全相同**（exe `6ADBDE85…`、dll `88CF8FA3…`）⇒ 重导换的是包，可执行文件本体一个字节没动 |
| 包的可复现性 | 同一份源码再 `--export-pack` 一次，两个包 sha256 一致（`F7C5B067…`，都是 2,108,304 B）⇒ 包是确定的，不是每次拼出来都不一样 |
| 与上一版包之差 | 2,108,304 − 2,108,256 = **+48 B**，就是这一轮那三个 `.gdc` |
| 交付形态复核（**就地**跑交付的 exe：`--headless -- --wallpaper=0 --hud=0 --exit-after=6`） | exit 0、`project.binary` / `Corrupted header` 报错 **0** 条、默认 `godot.log` **677 B**（末行 `shutting down`）⇒ 10-26 那类坏包没有复现 |
| **交付的 exe 自己出图**两张（`--shot`，2560×1440，各 6.2 s，比编辑器版快得多） | 默认 vs `--sky-figures=1` 差 **53090 px（1.440%）**、均值 +17.68/+23.62/+24.84 ⇒ 与编辑器跑出来的 53080 px 同量级：**装进去的包里默认就是关** |

换件与回滚：旧包先留 `XuanDesk.pck.ok-1028-1155`（2,108,256 B）；新件在**工作区外**的暂存目录生成后 **move** 进
`E:\xuandesk`（重命名不重新继承标签），装完三个件都不带 Low 标签。暂存目录用完即删。

> **教训（差点留在用户桌面上）**：这轮第一次出图时我把命令行拼漏了开头的 `--`，于是 `--wallpaper=0 --hud=0 --shot=…`
> 全被引擎当成自己的参数丢掉 —— 交付的 exe 直接以正式姿态起来了（日志 `wallpaper layer 'ok'`、桌面上多出一个
> `XuanDesk.HUD` 窗口），并且一直挂在那里等出图。规矩补两条：**出图前先把整条命令行打出来，看一眼有没有 `--`**；
> 再挂一个 `--exit-after`（这次 150 s）兜底，拼错了也自己退。
>
> 顺带纠正一条历史：10-19 15:54 那个常驻的 `godot.windows.opt.tools.64` 跑的其实是 **LingWang 的 `terrain_editor.tscn`**，
> 不是本项目 —— 前面几轮把它当成"用户那台 XuanDesk"是错的。它因此从来没占住 `app_userdata\XuanDesk\logs\godot.log`，
> 交付形态复核能读到刚写下的日志与此有关。

## 2026-11-02 · 罗盘消失：窗口活着、`visible=1`，坐标却在所有屏幕之外

用户报的："以前经常出现桌面背景不见了，这几天一直开着，桌面没出问题，这次是罗盘消失了"，并确认**右上角整块面板都没了**
（不是罗盘内容空掉），消失前**没拖过面板、没改显示设置**，这几天只是**锁屏两天以上**。

现场（在用户会话里读窗口，不靠观感）：

| 对象 | 实测 |
|---|---|
| `XuanDesk.HUD` | hwnd 318708896、pid 106304，`GetWindowRect` = **(2692,1520) 300×340**，`IsWindowVisible=1`、DWM `cloaked=0` |
| 桌面 | 主屏 `0,0 2560×1440`（可用区高 1392）、副屏 `2560,0 2560×1440` ⇒ 全部桌面 **5120×1440** |
| 壁纸窗 | hwnd 97591520，`2560,0 2560×1440`，父链 `Progman 'Program Manager' ← WorkerW ''` ⇒ 桌面层这一轮**没坏** |
| 这一代的日志 | 4356 B：启动 13 行（`sky: 9096 stars`、`wallpaper layer 'ok'`、`native event 'menu screen 1'`）之后全是 WASAPI 噪音；**没有**面板/拖动/重摆的任何一行 |

判据：y=1520 比整个桌面的下边缘 1440 还低 **80 px** ⇒ 窗口**整块**落在所有屏幕之外。`IsWindowVisible` 说的是"窗口没被
`ShowWindow(SW_HIDE)`"，不是"屏幕上看得见"——这两件事在 Windows 上分开，这一轮就是被它骗过去的（DWM 的 cloaked 也是 0）。

- **不是面板开关**：托盘「面板」那条走 `hud 0`，日志里一条也没有；而且 `hud 0` 会销毁原生窗口（G9），可那个 HWND 四天来一直在。
- **不是进程死了**：HUD 窗与托盘窗两个都在，壁纸层照画。
- **谁搬的，没有证据**：全项目只有两处写窗口位置——`set_content()` 的首次摆放与拖动（`_input`），两处都该留痕而当时都没留。
  所以这一轮先**补留痕再谈归因**：拖动松手一行 `panel dragged to (x,y)`、被外力改动一行 `panel window moved to (…)`
  （1 Hz 采样，拖动期间不重复报）、整块落在屏外一行 `off every screen …`。
- **为什么四天没人发现**：`main.gd::_on_frame` 的看护只管桌面窗（`wall` 状态），HUD 窗不在任何人的视野里；
  `wallpaper layer 'ok'` 一路正常，日志看上去"一切正常"。

修法（`shell/hud_window.gd`，与 10-21 那轮桌面窗看护同一形状：状态量 ＋ 每秒自检 ＋ 一次自愈）：

| 件 | 做什么 | 为什么这么定 |
|---|---|---|
| `keep_on_screen()` | 每秒（`main.gd::_on_frame` 里，桌面窗看护旁边）把 `GetWindowRect` 对每块屏求交，**整块窗落在所有屏幕之外**满 `LOST_GRACE_MS = 5000 ms` 才动它：搬回默认角（右边 26、顶边 100 ⇒ 本机 `(2234,100)`），丢失与归位各一行日志 | 判据按**每块屏各自的矩形**、不是包围盒（并排两屏的包围盒里有的是两块屏都不在的十字区）；宽高**各**要 `KEEP_VISIBLE = 40` px 才算"找得到"（一个能抓的角），20 px 宽的条子不算；grace 5 s 是不跟"显示器刚断电/正在重排"抢窗口 |
| 拖动夹 `clamp_into_screens()` | 拖动落点先问 `on_screen()`：**找得到就原样落**（跨缝、压任务栏、挂在下边缘都照旧），整块落在屏外才夹到最近那块屏里去 | 第一版把"整窗必须完全落在某块屏内"当规则，跨两块屏的缝时会**横跳 300 px**（实测：目标 x 过 2410 时窗口从主屏右沿 2260 跳到副屏左沿 2560）——夹子只在"已经丢了"时才有资格说话 |
| 留痕 | 上表三行 ＋ `panel window back on screen at (x,y)`（丢过又自己回来了） | 下一次丢失必须**能在日志里读出来**；10-21 那次是从几千条 `VK_ERROR_SURFACE_LOST_KHR` 里倒推的，不想再来一遍 |

触发条件仍**未证实**（用户没拖、没改设置，这几天只有"锁屏两天"这一件事；日志里那串 WASAPI
`Current output_device invalidated` 只说明这段时间音频端点被重排过，与显示端点可能同源）。
所以这一轮交付的是**能自愈 ＋ 留痕**的看护，不是"修好了某一个原因"。

验证（探针 ＋ 真窗 A/B；探针与脚本用完即删）：

| 手法 | 结果 |
|---|---|
| 现写探针 `--headless --path . --script res://shell/hud_window_probe.gd` | **14 条 pass / 0 FAIL**（退出码 0）：把**现场那个 rect** `(2692,1520) 300×340` 对两块 2560×1440 的屏 ⇒ `on_screen = false`；夹子把它送回 `(2692,1100)`（副屏内、整窗）；默认角 / 跨两块屏的缝 / 挂在下边缘 140 px 都判"找得到"；右沿外 20 px 条子判"找不到"；左屏 `-1920,0 1920×1080` 的负坐标两条；空屏表两条边界 |
| 真窗 A/B（dev 实例 `--wallpaper=0 --hud=1 --exit-after=90`；从外面 `SetWindowPos` 推它 ＋ `PostMessage` 发按下/移动/松开，**不动真光标**） | ① 健康 9 s：窗稳在 `(2234,100)`，日志里没有 `off every screen`；② 屏内拖动：落点仍 `(2234,100)` ＋ 日志 `panel dragged to (2234,100)`（夹子不插手）；③ 先推到 `(2692,1520)` 再拖：落点 `(2692,1100)` ＋ `panel dragged to (2692,1100)`（夹子把屏外那一拉拽回屏内）；④ 推到 `(2692,1520)` 后不动它：**+3 s 仍在屏外**（grace 内）、**+8 s 回到 `(2234,100)`**，日志两行 `panel window is off every screen at (2692,1520) 300×340 - waiting 5000 ms`、`panel window was nowhere for 5000 ms - back to the default corner (2234,100)` |

顺带一条现场观察（不是判据，但有用）：dev 实例的 HUD 一出现就被用户拖了几次，日志里 `panel dragged to (2588,1031) / (2572,1038) / (2560,1040)`
——**人真的会去拖它**，所以夹子不能把正常拖动改坏（这正是上面第 ② 条与"跨缝不横跳"那条的来由）。

- **这一版的包**：`XuanDesk.pck` **2,110,832 B**（17:17 导出，比 10-28 14:02 那版 **+2,528 B** ＝ `hud_window.gd` 与 `main.gd`
  两个 `.gdc` 的增量；sha256 `08DE5FC3…`），`XuanDesk.exe` 109,205,504 B 与 `xuandesk_native.dll` 133,451 B 一个字节没动；
  回滚件 `XuanDesk.pck.ok-1028-1402`（2,108,304 B，就是用户当时正在跑的那版）。
- **导出环境**（照 10-28 那条走）：Steam 便携版 Godot 的 `editor_data` 在 Program Files 下不可写 ⇒ 把 exe ＋ `._sc_` ＋
  `editor_data\export_templates\4.7.2.stable\windows_release_x86_64.exe` 复制到暂存目录导出。**暂存必须放在 E: 上**：
  成品要**改名**搬进 `E:\xuandesk`（改名不重新继承标签），若从 C: 复制/移动回去就会带上 Low 标签。
  落位后 `XuanDesk.pck.new` 无显式标签＝Medium（干净）。临时探针 `shell/hud_window_probe.gd` 导出前已删，
  **包内不含 `hud_window_probe`**（按包里的路径字符串核对），`hud_window` 在。
- **交付形态复核**（交付的 exe ＋ 新包，在 `E:\tmp\xd_check` 里按真形态摆好＝exe/pck/dll 三件同目录）：
  `--headless -- --wallpaper=0 --hud=0 --exit-after=6` → exit 0、stdout 里 `project.binary` / `Corrupted header` **0 条**、
  `background 'sky' built in 302 ms` 与 `wallpaper layer 'off'`、`shutting down` 都在；**默认路径** `godot.log` **676 B**、末行
  `shutting down`（10-26 那类坏包这条就是断的）；再跑一遍带 `--log-file` 的同样 676 B ⇒ 包内 `debug/file_logging/*` 完好。
  看护的行为 A/B 走的是编辑器版同一份源码、同一个引擎版本；交付形态只复核启动与日志线（`.gd` 编译成 `.gdc` 进包，编译不过导出就会报错）。
- **副作用一条**：复核实例把上一代（用户正跑着的那代）的日志轮转成了 `godot2026-11-02T17.17.46.log`（4356 B，内容一字未丢），
  `godot.log` 从此是复核那次写的。用户下次启动会再轮转一次，无影响。
- **交付时现场**：正在跑的那代仍是旧包，它的面板窗还停在 `(2692,1520)`（屏幕外，用户看不见）；换包＋重启后由新包的
  `set_content()` 摆回默认角 `(2234,100)`。不重启也想先把它拉回来的话：在 **Medium** 完整性的 shell 里对那个 HWND 发一条
  `SetWindowPos(h, 0, 2234, 100, 0, 0, SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE)` 即可——Low 沙箱里会被 UIPI 拒
  （`SetWindowPos` 返回 false、`GetLastError=5`），这也是这一轮前半程"看得见窗口却动不了它"的原因。
- **用户怎么换**：托盘「退出」或 Ctrl+Alt+Q 结束正在跑的那代（**必须**先退出：`XuanDesk.pck` 被它攥着，换不动），
  再跑 `.tmp\tools\deploy.bat`（把 `XuanDesk.pck.new` 覆盖过去并启动）。下一代的 `godot.log` 里应当有 `wallpaper layer 'ok'`；
  面板那两行看护日志只在"真的被搬走"时才写，健康的一代里一条都不该有。

## 2026-11-03 09:48 · 又一次"罗盘没了"：修复还没上机，包还被清掉了

用户报"罗盘又没了"。现场读窗口，还是同一个签名：`XuanDesk.HUD`（hwnd 318708896）`vis=True`、`GetWindowRect = (2692,1520) 300×340`，
整块在所有屏幕之外；壁纸窗 `XuanDesk.Aquarium` 照旧挂在 WorkerW 下（`2560,0 2560×1440`）⇒ 桌面层没坏。
**但那台机器上跑的仍是 10-28 那代**：`CreationDate = 2026-10-28 14:31:09`、命令行 `"E:\xuandesk\XuanDesk.exe"`，
而 `XuanDesk.pck` 的 **`CreationTime = 2026-10-09 15:42:27`**（原位导出那次留下的）⇒ 11-02 那一版**从来没上过机**：
`move /y` 真发生过的话 pck 的 CreationTime 会变成 11-02（改名保留源文件的创建时间），它还是 10-09。
同时 `XuanDesk.pck.new` 与全部 `XuanDesk.pck.ok-*`、`XuanDesk.pck.old` **一个都不在了**（像是被一条 `del XuanDesk.pck.*` 清的）
⇒ 修好的包被当成垃圾一起清掉了。

- **日志里捡到的一条真相**（`godot.log` 尾部）：`native event 'toggle_panel'` → `panel hidden` → `native event 'toggle_panel'` → `panel shown`
  ——有人切了两次「面板」（多半是想把它找回来）。**这条路救不回来**：隐藏会销毁原生窗口（G9），再显示是**按 Window 节点记住的位置重建**，
  而节点记住的正是屏幕外那个 `(2692,1520)` ⇒ 切换只是"原样重建一次"。11-02 那版的看护管的正是这件事（每秒自检、5 s 搬回默认角）。
- **09:52 先把它救回来**：对那个 HWND 发 `SetWindowPos(h, 0, 2234, 100, 0, 0, SWP_NOSIZE|SWP_NOZORDER|SWP_NOACTIVATE)`
  （Medium 完整性下 UIPI 不再拦：返回 True、`err=0`）⇒ 面板当场回到默认角。**十几分钟后用户又报"跑出屏了"** —— 因为搬它的那条路还活着（见下）。
- **09:55 用户一句话就是根因**：「我的鼠标移到罗盘，罗盘就自己躲鼠标，现在都跑出屏了」。前两轮一直在问的"谁搬的它"，答案就在这句话里。
  现场验证（**对用户那代正在跑的窗口**，只发消息、不动真光标）：

  | 步骤 | 结果 |
  |---|---|
  | 读现场 | `(2608,1456)` —— 又已经在桌面之外（y > 1439） |
  | 发一条 `WM_MOUSEMOVE`，**wParam = 0（没有任何键按下）** | 窗**跳到 `(588,1341)`** ⇒ `_dragging` 是**卡住的 true**：一次没收到松手的拖动，此后**每一次鼠标移动**都搬它 |
  | 由那次跳反推陈旧偏移 | `(588,1341) − 光标(691,1254)` ＝ **`(-103, +87)`**；`+87` 意味着按下那一刻**光标在窗口上边缘之外 87 px** —— 一个"按点在窗内"永远算不出来的偏移 |
  | 补发一条 `WM_LBUTTONUP`（旧代码里 `_dragging = false`） | 再发同样的 `WM_MOUSEMOVE` ⇒ **纹丝不动** ⇒ 卡住那次就是被这一条收尾的 |
  | `hwndCapture`（`GetGUIThreadInfo`，跨进程可读） | 之后读是 `0`；另在 dev 实例上量到 Godot 的行为是**按下 `SetCapture`、松手才放**（`0` → 按下 `127802128` → 松手 `0`）⇒ 丢的那次松手把**鼠标捕获**一起丢了：用户那几天的每一次移动与点击都送进了面板（"点别的东西没反应"就是这么来的） |

  **机制**（旧代码 `_input`）：按下时 `_drag_offset = window_get_position() − mouse_get_position()`，两个量都在**处理消息的那一刻**读。
  系统命中的是窗内一点，但读光标在稍后：一次甩鼠标、或者掉帧/后台编译卡住的几十毫秒，就够让读到的光标跑到窗口上边缘**之外** ⇒ 偏移为**正**（窗在光标**下方**）
  ⇒ 此后 `target = 光标 + _drag_offset` 把窗一路摆在光标下方，光标追、窗躲，最后 y 超过 1439 出了屏。
  松手那条消息只要丢一次（锁屏、G9 的隐藏重建、换显示配置都在这一列），这个偏移就**永远**生效——用户那台机器上它生效了好几天；
  **11-02 那个 `(2692,1520)` 也终于有了机制**：只要陈旧偏移的 y 是正的（够 +81，光标压到 1439 时就落到 1520），同一段代码、同一个方向。
- **修法**（`shell/hud_window.gd`，本轮只动这一个文件）：偏移不再"当场读光标算"，改成**按下事件自己的落点**：
  `_grab_point = Vector2i(event.position)`，移动时 `target = mouse_get_position() − _grab_point`。抓点**按定义就在窗内**，
  于是"窗被搬到光标另一侧"在几何上不可能，窗永远被摆成"抓点正压在光标下"。另外三条：落点**不在窗内**的按下不开拖动
  （只有抓了鼠标才收得到这种按下，它正是陈旧偏移的来源）；一次拖动超过 `DRAG_MAX_MS = 60 s` 就判它早该松手了，收尾并写一行日志；
  收尾统一走 `_end_drag()`（正常松手写 `panel dragged to (x,y)`，被判死写 `panel drag dropped (<理由>) at (x,y)`）。
  **`button_mask` 没有用作判据**：实测发出去的 `WM_MOUSEMOVE` 明明带 `MK_LBUTTON`，到 `_input` 里 `button_mask` 却是 `0`
  （第一次 A/B 三条判据全被这条掐断）⇒ 一条**没法证明"真拖动一定通过"**的判据不能上机（真拖动走 raw input 那条路，另有机会再验）。
- **A/B**（dev 实例 `--wallpaper=0 --hud=1 --exit-after=150`，`--log-file` 另写一份、不碰用户那份日志、不动真光标；脚本用完即删）：

  | 判据 | 结果 |
  |---|---|
  | 拖动活着时**从背后**把窗推到 `(2600,1450)`（桌面外），再发一条不带任何键的 `WM_MOUSEMOVE` | **PASS**：窗回到 `(1665,322)` ＝ 光标 `(1765,442) − 抓点(100,120)`，**在屏内** ⇒ 旧代码"往光标反方向跑"的那条路已经没了 |
  | 真拖动：按下(100,120) → 带 `MK_LBUTTON` 移动 → 松手 | **PASS**：窗在 `(1665,322)`（抓点压在光标下），日志 `panel dragged to (1665,322)` |
  | 落点在窗**外**的按下（`lParam=(-400,-400)`）＋ 带键移动 | **PASS**：窗不动 ⇒ 不开拖动 |
  | **拖动状态机探针**（现写 `shell/hud_drag_probe.gd`，`--headless --script res://…` 跑完即删）把手搓的 `InputEventMouseButton/Motion` 直接喂 `HudWindow._input()`，时间直接改 `_drag_started_ms` | **5 条 pass / 0 FAIL**（退出码 0）：窗内按下成抓（`grab=(100,120)`）、窗外按下被拒、新鲜拖动不被移动事件收尾、**超过 `DRAG_MAX_MS` 的拖动被收尾**、松手收尾。**探针不进包**（导出前已删；按包内路径串核对：`hud_window_probe` 无、`hud_window` 有） |
  | 60 s 那条的**真窗**尝试（作废两次，留作教训） | 第一次判 FAIL 是**用户真的在动鼠标**：留给测试的 dev 面板停在用户光标下，用户自己的移动＋点击把它带着走并正常收尾（日志多出 `panel dragged to (1884,307)`／`(2633,976)`）。第二次把面板**停到 (60,1280)**、离光标 2000 px 再等 62 s，仍然判 FAIL —— 因为按下会把**鼠标捕获**拿走（上表那条实测），用户的每一次移动还是送进这块面板，于是它又跑到光标下、又被用户的点击收尾。**结论**：这类"按住不放"的自测不能用真窗做（会劫持用户的鼠标），改用上面的 headless 探针 |
- **`XuanDesk.pck.new` 重新导出**：**2,111,232 B**，sha256 `8608FD77…`（比 11-02 那版 **−400 B**：少了"当场读光标"那两行、多了判据与注释，进包的是编译后的 `.gdc`，尺寸只做参考）。
  `XuanDesk.exe`（109,205,504 B）与 `xuandesk_native.dll` 一个字节没动；回滚件在**项目外**
  `E:\tmp\xuandesk-rollback\XuanDesk.pck.2026-10-28-1402`（2,108,304 B），免得再被 `del XuanDesk.pck.*` 一起清掉。
- **交付形态复核**（交付的 exe ＋ 新包 ＋ dll 三件同目录，`--headless -- --wallpaper=0 --hud=0 --exit-after=6`）：退出码 0；
  stdout 里 `project.binary` 的 ERROR **0 条**、`Corrupted header` **0 条**；`background 'sky' built in 316 ms`、`wallpaper layer 'off'`、`shutting down` 都在；
  `--log-file` 那份 **676 B**、末行 `XuanDesk: shutting down`。**默认路径那份没跑**：它就是用户那代正在写的 `godot.log`，跑一次等于把它轮转掉（内容不丢），
  而坏包的判据（`project.binary` 的 ERROR）本来就在 stdout 里，这条已经查过了。
- **文件约定（用户 11-03 确认）**：`XuanDesk.pck.new` 与那几个 `XuanDesk.pck.ok-*`／`.old` 是用户当垃圾文件清掉的
  （一条 `del XuanDesk.pck.*` 之类，把没上机的修复包一起带走了）⇒ 从此**项目目录里只放 `XuanDesk.pck.new` 这一件**，
  回滚件一律放项目外（`E:\tmp\xuandesk-rollback\`）；`deploy.bat` 自己**不建**备份（只在已存在 `XuanDesk.pck.old` 时提示一句）。
- **换包仍交给用户**（`deploy.bat` 的注释就写着：从受限/沙箱 shell 里启动的进程挂不上 WorkerW），这边只放包、不启动。
  换完之后：面板默认在右上角；再"被搬出屏"会 5 s 自愈并留两行；拖动落点会被记一行；卡住的拖动最迟 60 s 自己收尾，且**永远跟着光标、不再躲开**。

---

## 2026-11-03 11:00 · 罗盘右上角的方角改成大圆角

> **11-03 16:25 更正**：这一节把要求读成了 `↙/↘` 两颗 chip 的角。用户要改的是**窗口那层方形底板**（见 16:25 那节），本节的改动已全部退回。

用户：「将HUD右上角右上角的方角去掉，做成大圆角贴近罗盘圈」。

- **先看清是哪一块**（没有图像输入，就把 HUD 的 `--shot-target=hud` 出图当数来读）：出一张 300×340 的 HUD 图，
  Pillow 把 alpha>8 当"有东西"、逐行列出墨迹范围，再按 5×5 粗印一张 ASCII 图。看到的是：盘心 (150,150)、盘径 138，
  **`↙/↘` 两颗 chip 是 24×24 的方框**（左 (16,30)、右 (260,30)），四个角的 7×7 盒全是墨（**49/49** —— 半径 5 的圆角在 1 px 上看不出来，这就是用户眼里的"方角"）。
  右 chip 的内角 (260,53) 离盘心 146.7 px = **盘沿外 8.7 px**，盘沿那道弧就在它左下角外一点（ASCII 图里那条斜的 `+###+`）。
- **改法**：`CHIP_RADIUS = 5`（朝盘的三个角）＋ `CHIP_CORNER = 12`（朝窗户边的那个角：右转的右上、左转的左上）
  ⇒ `StyleBoxFlat.corner_radius_top_right / top_left`。只改**画出来的形状**，按钮的 24×24 命中区一个像素没动（`_chip()` 多一个 `outer_right`）。
  左转那颗一并对齐（不然两颗不对称）。
- **判据**（同一时刻；"旧"＝把工作区那份换成 `git show HEAD:` 的原件再出图，负对照在前）：

  | 量的是什么 | 旧 | 新 |
  |---|---|---|
  | 右 chip 外侧 12×12 角里的墨 | 139 | **114** |
  | 右 chip 24×24 框内其余部分 | 417 | **417**（逐像素相同） |
  | 箭头亮像素（"字会不会被圆角切掉"那条） | 17 | **17** |
  | 右 chip 每行最后一个墨迹 x（y=30…38） | 280,282,282,283,283,283,283,283,283 | **275,277,278,279,280,281,282,282,283** ＝ 半径 12 的四分之一圆 |
  | 左 chip（镜像） | 139 / 417 / 17 | **114 / 417 / 17** |

  7×7 角盒的墨 **49 → 34**（两颗都如此）。
- **两处教训**：① 别用整窗逐像素差当判据 —— 盘是活的：三针与换字飞转的落点亚像素，同一份代码跑两次差出 **829 px**，
  其中 705 px 挤在一颗字上（(213..219,77..80)，正好在分针尖端半径 98 那一圈）。② 拿"旧代码"做负对照时**别用 PowerShell 管道**取文件：
  `git show HEAD:x.gd > x.gd` 会按控制台代码页解码再写回，中文与 `「↙」` 变成替换字符 ⇒ 那趟跑出 `Parse Error`（报的还是"`add_child()` 收到 GDScript"这种不相干的错），
  基线图成了 320×200 的种子尺寸；改用 `cmd /c "git show … > file"`（逐字节）才对 → README T27。
- **包**：重新导出并放回 `XuanDesk.pck.new`（**2,111,440 B**，sha256 `93773A5B…`）—— 比 11:08 之前那版（只含拖动修复的 2,111,232 B / `8608FD77…`）多了这一处；
  交付形态复核照旧（交付的 exe、`--headless -- --wallpaper=0 --hud=0 --exit-after=6`、exit 0、无 `project.binary`／`Corrupted header`、`--log-file` 676 B 末行 `shutting down`）。
  **注意**：用户 10:25 重启过一次（pid 106304 → 105420），但 `XuanDesk.pck` 仍是 10-28 那版 ⇒ 那次是重启不是换包；这一版把拖动修复与大圆角一起带上，只换这一次就够了。

## 2026-11-03 14:55 · chip 的内角切在视角弧上（"到视角弧上"）

> **11-03 16:25 更正**：同上一节 —— 这是同一个误读的第二轮。用户要的是窗口底板变成圆，本节改动已全部退回（源文件副本 `E:\tmp\xd_hud\hud_compass.chips-2026-11-03.gd`）。

上一节把 chip 朝窗户边那个角做成了 12 px 大圆角。收尾时我问用户"贴近罗盘圈"是哪种意思（保持现状／再往里挪一点／
让**内**角沿着盘沿的弧切），用户三个选项都没点，回了一句自己的话：**「到视角弧上」**。

- **先把这句话量成几何**：视角弧画在 r 143（`R_VIEW_ARC = R_DISC + 5`），带宽 3 px，只在相机看的那一段方位上；
  chip 原来的内角在 r 146.7 ⇒ **在弧外 3.7 px**。所以"到弧上"＝内角被**弧自己那个圆**切掉、内边落在弧上。
  框于是从上沿 30 下移到 `ROTATE_TOP = 41`（框自己的内角落到 r 139，圆才横穿它），盘沿 r 138 仍留 5 px 空 ——
  这条"内边就是弧"的关系写成一个常量 `CHIP_ARC := R_VIEW_ARC`，弧以后改半径，切法跟着走。
- **改法**：`StyleBoxFlat` 切不出**凹**角，所以两颗 chip 改成**盘自己画**（`_chip_outline()` 出轮廓、`_draw_chips()` 填色＋描边），
  按钮的 stylebox 全空、连悬停色也由盘画（`_chips` 记 hover，`mouse_entered/exited` → `queue_redraw`）。
  命中区一个像素没动（仍是 24×24 的 `Rect2`）。左转那颗是右转按盘心列镜像出来的。
- **判据**（同一时刻 `--sky-time=2026-11-03T03:00:00 --sky-rate=0`；"负对照"＝同一份代码只把 `CHIP_ARC` 改到 130，
  圆就穿不过框 ⇒ 退回普通 5 px 小圆角）：

  | 量的是什么 | 原版（方角，y30） | 大圆角（y30） | 切在弧上（y41） | 负对照（y41，圆够不着） |
  |---|---|---|---|---|
  | 右 chip 24×24 框内墨 | 556 | 531 | **552** | 554 |
  | 左 chip（镜像）框内墨 | 556 | 531 | **552** | 554 |
  | 朝盘心那个内角 | 满（49/49） | 满 | **空**（框外的 r139.6 处也没东西） | 满（5 px 圆角） |
  | 内角那两 px 的颜色 `(262,63)`,`(263,64)` | chip 暗青 | chip 暗青 | **弧的亮青 `rgb(73,208,244)`** | chip 暗青 `rgb(47,117,136)` |
  | `triangulation failed` 报错条数 | 0 | 0 | **0** | 0 |

  最后一行才是真正的判据：被切掉的那两 px 在最终版里露出来的是**弧自己的墨**，负对照里是 **chip 压住弧**的暗青 ——
  "框让开、弧还在"可以逐像素读出来。（前两列是 11:00 那一轮在 y30 量的，位置不同，只有"内角满/空"可比。）
- **三处教训**：① **"少画一块"不能拿框内总像素数当判据**：切掉的面积约 12 px，可切出来的那段弧边界又添了几 px，
  实测同一颗 chip 只从 554 掉到 552；判据要落到具体像素的**颜色**上。② `draw_colored_polygon` 走
  `Geometry2D::triangulate_polygon`，**重复点/闭合尾点/反绕**都能让它整块不画（左 chip 一开始只剩 163 px 的空框，
  报错 4 条），交出的轮廓要先去重、去尾、镜像后把绕向 `reverse()` 回来 → README G46。③ **负对照本身要先自证**：
  第一次把 `CHIP_ARC` 设成 400，交点算到 (−234)／540 —— 轮廓点飞到框外，整块不画，"看起来切了"其实什么都没画（坏对照）；
  而更早一次想用 `Set-Content -Encoding utf8NoBOM` 改常量，在 Windows PowerShell 5.1 上直接报枚举错、**替换根本没发生**，
  幸好那行 `control in place: False` 把它拦了下来 → README T29。
- **包**：重导一次放进 `XuanDesk.pck.new`（**2,113,664 B**，sha256 `4CADDA9C…`，14:56:42）。`--export-pack` 的输出必须
  以 `.pck` 结尾（写 `.pck.new` 会被拒），所以先导到 `E:\tmp\xd_export\` 再 `Copy-Item` 进来 → README T28。
  交付形态复核：**从包里**出 HUD 图（`--main-pack XuanDesk.pck.new --shot-target=hud`）与源码版比 —— 整图差 953 px，
  全是盘面活内容那笔老账（三针／飞转的亚像素落点；同一份代码跑两次也这样），而**两颗 chip 的 24×24 框内逐像素相同（0/576）**，
  无 `triangulation`／`Corrupted` 报错，stdout 有 `background 'sky' built`、`wallpaper layer 'off'`、`shutting down`。
  （14:43 用户已从托盘退出过一次 —— `%APPDATA%\Godot\app_userdata\XuanDesk\logs\godot.log` 末两行是
  `native event 'quit'` / `shutting down`，所以只差双击 `.tmp\tools\deploy.bat`；它先 `move` 再 `start`，
  一次把拖动修复与这两处 chip 改动一起上机。）
- 换包仍是用户自己动手（托盘退出／Ctrl+Alt+Q → `.tmp\tools\deploy.bat`）；换完之后：面板回到默认角 `(2234,100)`、
  日志里不该再出现任何 `panel …` 行，chip 的悬停色该随手一划就变（那条只能在真机上眼睛看，headless 出图看不到 hover）。

## 2026-11-03 16:25 · 方形底板不是 chip，是窗口清除色的渗色

用户（带截图）："我是[想]你把 HUD 半透明的方形去掉，你这啥也没动啊"。上两节把这句话读成了 `↙/↘` 两颗 chip 的角，改了两轮 chip ——
方向整个错了。真正要去掉的是 **HUD 窗口那层 300×340 的底板**。

**量它**：抓一块比窗口大 30 px 的屏幕区域（`CopyFromScreen`，HUD 是 `WS_EX_TOOLWINDOW`，屏上能拍到），逐边从内往外走亮度剖面。

| 位置 | 窗口内 | 紧贴外侧（4–6 px） | 差 |
|---|---|---|---|
| 左右下三边中点 + 四个角，共 8 处 | `rgb(24,30,37)` | `rgb(21,21,23)` | **恒为 (+3,+9,+14)** |

两条判据把它钉死是"窗口自己画的"：

- **差恒定**（8 个位置同一个数，桌面本身在那儿是平的）⇒ 不是渐变，是整块覆盖；
- 边界是**一像素陡坎**（窗口 x=0 是 (24,30,37)，x=−1 立刻 (21,21,23)）⇒ 不是投影（投影会向外渐隐）。

而 (+3,+9,+14) **正好等于** `project.godot` 里 `default_clear_color = Color(0.012,0.035,0.055,1)` 的 RGB。
机制：逐像素透明的视口把清除色留在角像素的 **RGB** 里、alpha 却是 0；DWM 按**预乘 alpha** 读，于是这个颜色被**加**到桌面之上、铺满整个窗口
—— 屏幕上就是一块"半透明矩形"。治法两处：`hud_window.gd` 加 `transparent_bg = true`（`transparent` 只管 OS 窗口那层 flag，视口照样用清除色刷底），
`project.godot` 的 `default_clear_color` **RGB 归零**（alpha 留 1，给不透明窗口用）。

卡片形状同时按用户"到视角弧上"定死：`_draw()` 开头那个圆从 `R_DISC`(138) 改成 **`R_VIEW_ARC`(143)** —— 盘沿外留 5 px 卡片，
视角弧那条带正好压在卡片自己的边上。渲染验证（`--shot-target=hud`，按颜色找卡片轮廓的**最大半径**）：

| | 源码渲染 | 从包渲染 |
|---|---|---|
| 卡片色像素的最大半径 | **143**（r=144 起 0 像素） | **143** |
| 四角 | `rgba(0,0,0,0)` | `rgba(0,0,0,0)` |

上机（`XuanDesk.pck` = `8595038C3A65A33F…`，2,111,360 B，pid 41912 @16:24:55）：同一套 8 点测量，窗口内外**全部相等**（差 (0,0,0)），
灰度图上那块底板**变成一个圆**，四角回到桌面暗底。回滚件在 `E:\tmp\xuandesk-rollback\`。

三条教训：

- **"方角／方形"要先问是哪一块**。这个 HUD 的形状有两层：窗口层（`hud_window.gd` 那个 `Window`）和绘制层（`_draw()`）。
  我按字面去改了绘制层里两颗 button 的角，两轮工夫全废。改动已退（chip 恢复 10-28 原样）。
- **判"是不是窗口自己画的"**：内外亮度差**恒定** + 边界**一像素陡坎** ⇒ 窗口背景；差随位置变 + 向外渐隐 ⇒ 投影。屏幕上两者很像，只有这一条判据。
- **透明这件事不能用编辑器实例验**。`--main-pack` + `--wallpaper=0 --hud=1` 起真窗口确实能看渲染（这次圆盘半径就是这么量的），
  但那个窗口自己会再铺一层底色，把窗口背景的真相盖掉 —— 两次开发实例测量自相矛盾正是这个原因。只在**导出的 exe + 用户桌面**上量。

## 2026-11-04 · 换桌面：星空提到第一项，五行补齐（木火土金四个灰置 TODO）

用户："托盘的换桌面菜单，把星空放第一项，然再加配齐五行，水族箱是水了，再加木火土金四种桌面，
先写个木TODO火TODO土TODO金TODO并灰置"。

- **注册表**（`shell/backgrounds.gd`）：顺序改成 `sky, aquarium, wood, fire, earth, metal`；四个新条目只有 `name`
  与 `todo: true`（`木TODO` / `火TODO` / `土TODO` / `金TODO`，`display_name()` 就是它们，所以菜单上读到的就是这四个字）。
  `DEFAULT` 仍是 `sky`（与顺序无关）。新增 `is_todo(id)`，`create()` 见到 todo 一律 `push_error` 返回 `null`。
- **模型下行**（`shell/main.gd::_push_tray_model`）：`menu bg <i> <cur> <todo> <id> <label>` —— 第三段是新加的 todo 位
  （`显示器` 那一路 `menu screen` 不变，三段的形状没动）。
- **原生侧**（`native/gdext/xuandesk_native.c`）：`tray_item` 多一个 `todo`；`tray_set_item()` 多收一段；
  `tray_append_items()` 对 todo 行加 **`MF_GRAYED | MF_DISABLED`**；`tray_command()` 对 todo 行再拒一次（只写一行日志、
  不 push 事件）。面包屑两行：`menu item[i] label N B (todo, greyed): …` 与 `menu row[i] '…' flags=0xXXXX`（后者是真正
  交给 `AppendMenuW` 的那一组位）。

量到的（每条都有负对照）：

| 判据 | 结果 |
|---|---|
| debug DLL headless 面包屑（`菜单`模型的字节长度） | `item[0] label 6 B: 星空`、`item[1] label 9 B: 水族箱`、`item[2..5] label 7 B (todo, greyed): 木TODO/火TODO/土TODO/金TODO` —— 顺序、字符数、todo 位全对 |
| 现写探针 `--headless --script`（跑完即删）：`test(1, cmd)` 打同一条命令号 | **todo 行被拒**（`poll()` 里没有 `menu background wood`）／**负对照**：同一个 `101` 打在真行上必出 `menu background aquarium`。**0 FAIL**、退出码 0 |
| 真机截图（headed 实例 + 给托盘窗投 `TRAY_CALLBACK/WM_RBUTTONUP` + 悬停第一行展开子菜单） | 子菜单六行文字亮度：前两行 max **255**（`px>200` = 36 / 53）⇒ 白＝可点；后四行 max **109**、`px>200` = **0**、`px<160` = 全部 ⇒ 灰（`COLOR_GRAYTEXT`）。顶菜单四行全部 255 是负对照。**release DLL 复量数字相同**；再用**交付形态**（exe ＋ 新包 ＋ DLL 三件同目录）复量，仍是 2 白 4 灰 |
| 交付形态复核（`E:\tmp\xd_check` 按真形态摆好） | `--headless -- --wallpaper=0 --hud=0 --exit-after=6` → **exit 0**、无 `project.binary` 的 ERROR、`background 'sky' built` / `wallpaper layer 'off'` / `shutting down` 三行齐 |

两条这轮才踩到的坑：

- **`--main-pack` 在交付的 exe 上不可用**：`ERROR: --main-pack was specified on the command line, but this Godot binary was
  compiled without support for path overrides. Aborting.`（退出码 1）。官方模板没编路径覆盖，所以"用交付的 exe 直接验一个
  `XuanDesk.pck.new`"这条路**不存在** —— 11-03 那条 `--main-pack XuanDesk.pck.new --shot-target=hud` 能成，是因为它用的是
  **编辑器版**。交付形态只能按真形态摆（exe/pck/dll 同目录）或真换包，这次走的是前者。
- **`ld` 是重新创建输出文件**，不是在原地截断：新编出来的 `xuandesk_native.dll` 会继承 `E:\xuandesk` 的 Low 标签
  （T25 的又一个变种——触发它的不是导出，是编译）。洗标签的 copy-out → move-back **必须同卷**：这台机器 `$env:TEMP` 在 C:，
  跨卷 `Move-Item` ＝ 复制＋删除，回来还是 Low（实测：暂存处无显式标签＝Medium，搬回来 `Low Mandatory Level:(I)(NW)`）；
  把暂存目录放在 `E:\tmp\xdlabel` 才有效（同卷改名保留标签，搬回后无显式标签＝Medium，字节与 sha256 全对）。
  `.tmp/tools/relabel_delivery.ps1` 用的正是 `$env:TEMP` ⇒ 在现在的环境变量下**它是无效的**。顺带量到：Low 的 DLL 其实能用
  （Medium 的编辑器进程加载它，托盘照挂、菜单照画）——仍按交付约定洗成 Medium。

交付件（**换包仍是用户自己动手**：托盘「退出」或 `Ctrl+Alt+Q` → `.tmp\tools\deploy.bat`）：

| 件 | 数字 |
|---|---|
| `XuanDesk.pck.new` | **2,111,792 B**，sha256 `55286B2615E2F7B5EDD3DD3462A458B60B077F2289EAA4B8AD106D84254D00A4`（`--export-pack` 先导到 `E:\tmp\xd_export\` 再 `Copy-Item` 进来，T28；包里**不含**那个临时探针，按名字 grep 过） |
| `xuandesk_native.dll` | **133,451 B**（release，无面包屑无 `test()`），sha256 `403242AC948DF07427C1BDF399EC8EA3CF649CC00CFA7199EFFB8D6A2DAD3BD5`，Medium |

截图（delivery 形态那一次，3× 放大）：`.tmp/shots/tray_menu_2026-11-04.png`。

## 2026-11-12 · 转向钮：按住就自转，再短点任一停

用户：「HUD上的左右两个旋转按钮，长按可启动自动旋转，再短点任一停止」。上一轮那两颗 `↙/↘` 是**点一下走一山**
（15°，`turn()`），这一轮要在同一颗 chip 上再挂一条**长按 = 自动旋转**；而"短点"在自转**开着**时是"停"、
在自转**关着**时仍是"一山"，且停的那一下**不许**顺手再补一山。chip 的位置与画法一个字没动，落点是三处：

- `backgrounds/sky/camera_rig.gd`：新增 `SPIN_AZIMUTH = 15.0`（一秒一山，整圈 24 s）与 `spin(direction)` /
  `stop_spin()` / `is_spinning()` / `spin_direction()`。`advance()` 里自转**最先**判（`_spin != 0` 就 `_step_spin()`
  并 return），`_step_spin()` 沿更短的方向走方位，并把走过的度数**从视角本身**累起来（`_bearing_gap(was, now)`）——
  停的那行日志报的是天空**真的**转了多少，不是"速率 × 时间"。`stop_spin()` 写在**每一个** `stop_sweep()` 旁边
  （`face()` / `turn_to()` / `set_fov()` / `start_sweep()`），于是拖动、方位三角、时辰±、缩放、`现在`、`--sky-view`
  任何一下手动动作都盖过自转。`spin()` 里两处刻意的选择：**放弃**在飞的转向（`_turning = false`，自转从**当前**
  视角起算，不去追一次被抛弃的转向）、**同向重复按不重启**（`_spin == wanted` 直接 return，否则天空会在手指下跳一下）。
- `backgrounds/sky/hud_compass.gd`：`HOLD_SECONDS = 0.4`；两颗 chip 从 `pressed.connect(turn)` 改成
  `button_down.connect(_chip_down.bind(±1))` + `button_up.connect(_chip_up)`；`_step_hold(delta)` 在 `_process`
  **最前面**走（这一帧画之前就要定下来），到 0.4 s 就把 `_held_long` 立起来并 `rig.spin(方向)`。
- 松手那一半**另取**窗口的 `_input`（任何一次左键松开都到 `_chip_up()`，chip 的 `button_up` 也到，第二次是 no-op）。
  为什么另取：`Button` 只会说"按下过"，`button_pressed` 只在 toggle 模式下有意义；而**一条 `WM_LBUTTONUP` 是会丢的**
  （锁屏、隐藏重建、换显示配置，G45 的现场）⇒ 长按被留成自转而再没人点得停，正是这一条要防的。

量到的（headless 探针，**22 条 pass / 0 FAIL**，退出码 0；真 `HudWindow` + 真 `SkyCompassHud`，事件走
`root.push_input()` 的**真 GUI 分发**，判据全是度数）：

| 手势 | 量到的 |
|---|---|
| 点一下 `↙` | `-15.000°`，不自转 |
| 按住 0.2 s（< 0.4 s）松手 | 一山 `+15.000°`，仍不自转（**短按保持老行为**） |
| 按住 0.5 s | **按着**就开始转，1.0 s 走 `-15.07°`（＝ 15°/s），松手**继续**转 |
| 转着时短点 `↘` | 停，此后 `0.000°`（**不**再补一山） |
| 按住 `↘` 再按 `↙` | 顺行 → 立刻反向（`自动旋转 右（顺行）` 后紧跟 `自动旋转 左（逆行）`） |
| 在 chip 上按下、拖到卡面上松手 | 一次点照走、自转照转（松手取自 `_input`，落点在哪都算数） |
| 按**卡面** 0.5 s（负对照） | 不自转，视角 `0.000°` |

日志面包屑（**故意留的**，这一轮判据就是这两行）：`XuanDesk: sky: 自动旋转 左（逆行） 15°/s`、
`XuanDesk: sky: 自动旋转停（左，转了 22.7°）`。

真窗那半边（交付形态 ＋ `SendInput` 真键）也走到了：真按住 `↙` 0.9 s ⇒ `自动旋转 左（逆行） 15°/s`；
松开 1.2 s 后短点一下 ⇒ `自动旋转停（左，转了 26.0°）`（26.0 ≈ 自转真正走到的 1.7 s × 15°/s）。三个新坑：

- **`PostMessage` 的鼠标按下到得了 `Node._input`，到不了 GUI**（G47）：十次里只有两次真的走到 Button，
  而 `panel dragged to (…)` 次次都写（说明事件进了视口）⇒ 看着像芯片/信号坏了。合成点击要用 `SendInput`，
  判据只能是那两行日志。
- **用户自己的鼠标会插进来**（G45 那条的又一例）：`SetCursorPos` 之后光标被挪走（实测 `(2262,142)` → `(2236,564)`
  → `(1797,870)`），日志里多出一条**不是我们点的** `panel dragged to (2234,100)` ⇒ 有活实例、有人在用时，
  这条判据取探针那份。
- headless 的两条（同 G47）：`Viewport.push_input()` 打进**子 Window** 不做 GUI 命中（要嵌进**根**视口），
  而 headless 的根视口恒为 **64×64**、`root.size = Vector2i(1000,800)` **改不动** ⇒ 每次事件前把面板滑到让按点
  落进根内（`window.position = Vector2i(28,42) - at`）。这也是"右转那颗怎么点都点不着"的真正原因：它在
  根视口 64×64 之外，左转那颗恰好在里面。

交付件（**换包仍是用户自己动手**：托盘「退出」或 `Ctrl+Alt+Q` → `.tmp\tools\deploy.bat`）：

| 件 | 数字 |
|---|---|
| `XuanDesk.pck.new` | **2,113,936 B**，sha256 `606323D212A0D5D7DE687AB11DAE8D7E91A1F04AA0EA090CEFC41BBB0F14B775`（`--export-pack` 先导到 `E:\tmp\xd_export\`，再**同卷改名**进 `E:\xuandesk`，T25；包里**不含**探针，按名字 grep 过） |
| `xuandesk_native.dll` | 未动，仍是 **133,451 B**（sha256 `403242AC948DF07427C1BDF399EC8EA3CF649CC00CFA7199EFFB8D6A2DAD3BD5`，Medium） |

顺带：这一轮开始时**用户那代实例还活着**（11-10 起，`XuanDesk.HUD` 在 `(2575,1037)`，300×340），第一次探路的
实例**误挂了一次壁纸层**（`--wallpaper=0` 放在了 `--` 之前 ⇒ 被当引擎参数忽略，日志 `wallpaper layer 'ok'`），
9 s 后自己退出；默认 `godot.log` 也因此轮转过一次（内容不丢，只是换名，11-02 那条副作用）。

## 2026-11-12 14:43 · 自转再慢一半（15 → 7.5 °/s）

用户看完上面那版只回了三个字：「再慢一半」。`SPIN_AZIMUTH` 15.0 → **7.5**（两秒一山，整圈 **48 s**），
顺手把面包屑的 `%.0f` 改成 `%.1f` —— `%.0f` 会把 7.5 印成 `8°/s`，而那行日志正是这一轮的判据。

重量（同一套探针重写一版，**12 条 pass / 0 FAIL**，退出码 0；真 `HudWindow` + 真 `SkyCompassHud`，
事件走 `root.push_input()` 的真 GUI 分发）：

| 手势 | 量到的 |
|---|---|
| rig 直走 4.0 s（40 × 0.1 s，不过窗） | `30.000°` ⇒ 恰好 7.5°/s，整圈 48.0 s |
| 点一下 `↙` | `-15.000°`（一山没变），不自转 |
| 按住 0.5 s | **按着**就转；0.4 s → 松手那 0.1 s 走 `0.80°`（预测 0.75，差的是 0.4 s 那帧的边界） |
| 松手后 1.0 s / 2.0 s | `7.55°` / `15.06°`（＝ 7.5°/s） |
| 转着时短点 `↘` | 停，此后 `0.000°`（不补一山） |
| 按住 `↘` | 顺行（`自动旋转 右（顺行） 7.5°/s`），短点再停 |
| 按**卡面** 0.5 s（负对照） | 不自转，视角 `0.000°` |

一个**探针自己的**坑（值得记）：第一版把"按住 0.5 s 松手后 1.0 s"直接从**按下前**的方位算，量到 `-8.38°`
还判了 FAIL —— 0.5 s 的按住里已经转了 0.75°（0.4 s 之后那 0.1 s），所以**计时窗口必须从松手那一刻起**
（改成 `t0 = 松手后的方位` 就 12 条全过）。这不是代码错，是判据错。

交付件（**换包仍是用户自己动手**：托盘「退出」或 `Ctrl+Alt+Q` → `.tmp\tools\deploy.bat`）：

| 件 | 数字 |
|---|---|
| `XuanDesk.pck.new` | **2,113,952 B**，sha256 `0EF7DE199DAD2D5353DDBD0C9B01C12E8908EBA6BB1FE3D66747BA0F8F253CD8`（比 15°/s 那版 **+16 B**：注释多了两行、`%.1f` 多一个字符；交付形态起过一次 —— HUD 300×340、`wallpaper layer 'off'`、`shutting down` 收尾） |
| `xuandesk_native.dll` | 未动，仍是 **133,451 B**（sha256 `403242AC948DF07427C1BDF399EC8EA3CF649CC00CFA7199EFFB8D6A2DAD3BD5`，Medium） |

## 2026-11-12 17:15 · 自转再降一半（7.5 → 3.75 °/s）

用户（傍晚）：「再降一半转速」。`SPIN_AZIMUTH` 7.5 → **3.75**（一山 **4 s**，整圈 **96 s**），面包屑的精度从
`%.1f` 再挪到 **`%.2f`** —— 7.5 时 `%.0f` 会印成 `8`，3.75 时 `%.1f` 会印成 `3.8`，而那行日志正是判据（`3.75°/s`）。

重量（探针第三版，**12 条 pass / 0 FAIL**，退出码 0）：rig 直走 8.0 s ＝ `30.000°`（整圈 96.0 s，不是估的）；
点一下 `↙` 仍 `-15.000°` 且不自转；按住 0.5 s **按着就转**、0.4 s→松手那 0.1 s 走 `0.400°`；松手后 2.0 s
＝ `7.512°`、4.0 s ＝ `15.022°`（＝ 3.75°/s）；转着时短点 `↘` ⇒ 停且此后 `0.000°`；按住 `↘` ⇒ 顺行、短点再停；
按**卡面** 0.5 s（负对照）⇒ 不自转、视角 `0.000°`。

交付件（**换包仍是用户自己动手**：托盘「退出」或 `Ctrl+Alt+Q` → `.tmp\tools\deploy.bat`）：

| 件 | 数字 |
|---|---|
| `XuanDesk.pck.new` | **2,113,952 B**，sha256 `54E0E9804613D63ED4458C3BAB661E5F22ED4EA1579A492A07DCA9F3EEE0C9F9`（同上一版**同字节数**：多的那行注释与 `%.2f` 正好抵消；交付形态起过一次 —— HUD 300×340、`wallpaper layer 'off'`、`shutting down` 收尾） |
| `xuandesk_native.dll` | 未动，仍是 **133,451 B**（sha256 `403242AC948DF07427C1BDF399EC8EA3CF649CC00CFA7199EFFB8D6A2DAD3BD5`，Medium） |

## 附录 · 调试日志线索（从哪读、判据是什么）

| 线索 | 在哪 / 怎么开 | 判据与坑 |
|---|---|---|
| `--log-file <路径>` | 桌面窗看护重启下一代时**必带**（W8） | 本代还攥着默认 `godot.log`（Windows 改不动别人打开的文件，`DirAccess.rename_absolute` 返回 1），下一代开机就会轮转它 ⇒ 不给它自己的路径就等于下一代没有日志 |
| `logs/godot-restart-<ts>.log` | 上面那条的落点（如 `godot-restart-2026-10-26T16.05.44.log`） | 自愈那一代**活着时**它是空的，退出才有内容 |
| 默认 `godot.log` | 导出形态由 `debug/file_logging/*` 决定；带缓冲 | 一代活着的期间可能一直是 0 B，**退出时才整段落盘**（10-26 退出那代留下 3272 B，从 `sky: 9096 stars` 到那条重启行一条不少）⇒ 读日志要看**上一代**那份；想同时看活的就把 stdout 重定向到文件再启动 |
| `XuanDesk: wallpaper layer '<state>'` | `shell/main.gd::_on_frame`，状态**一变**就打（`waiting` / `no-worker` / `ok` / `hidden` / `failed`） | 丢失从此在日志里是**明写**的：`'ok'` → `'waiting'` → 重启行 → 下一代 `'ok'`。10-21 那次是反过来从几千条 `VK_ERROR_SURFACE_LOST_KHR` 与窗口树快照里推出来的，所以才补这一行 |
| `XuanDesk: panel …`（`panel dragged to (x,y)` / `panel window moved to (x,y) …(was x,y)` / `panel window is off every screen at (x,y) W×H - waiting N ms` / `panel window back on screen at (x,y)` / `panel window was nowhere for N ms - back to the default corner (x,y)`） | `shell/hud_window.gd`：拖动松手一行、外力改动一行（每秒采样）、看护的丢失与归位各一行 | 面板"不见了"从此在日志里分得清三种：**被拖走**（有落点）、**被外力搬**（前后两组坐标）、**整块落在所有屏幕之外**（等待 ＋ 归位两行）。11-02 那次现场这三种一行都没有——因为那时还没有这些行。每秒采样的代价是"一秒内搬走又搬回"看不见，收益是不拖累帧 |
| `ERROR: Corrupted header in binary project.binary (not ECFG)` | 交付的 exe 一跑就报（坏包） | 症状极隐蔽：脚本/背景/挂载全照常，**唯独工程设置整块丢了**，而 `debug/file_logging/*` 也在里面 ⇒ 那一版根本不写 `godot.log`（文件建出来、一直 0 B），日志这条诊断线等于断的 |
| 交付形态复核 | 交付的 exe 跑 `--headless -- --wallpaper=0 --hud=0 --exit-after=6` | stdout 无 `project.binary` 的 ERROR、退出码 0，且**默认路径** `godot.log` **非空**（好包：10-27 = 645 B、10-28 = 676 B、10-28 14:02 重导 = 677 B，末行都是 `shutting down`）。编辑器版会把工程设置从自己上下文里补齐 ⇒ **只有这条能看出坏包** |
| `_gdext_init.log` ＋ `test()` 钩子 | `native/build.cmd debug` 编出的 debug DLL | 两者只在 debug 面；release DLL 上跑门 2 会**直接编译失败**，这本身就是出货面干净的证据 |
| `menu item[i] label N B: …` | 同一个 debug DLL 的面包屑（G41） | 四个托盘标签的字节长度都要**等于字面长度**（修前 `主屏 2560×1440` 读回 21 B、修后 17 B） |
| `shader error` | 改完 `.gdshader` 后 grep stderr（G27） | shader 编译错误只往 stderr 打一行、材质静默退化：整屏黑而进程与退出码全正常 |
| `Start-Process -RedirectStandardOutput/-RedirectStandardError` | 换包那一轮现学的（10-27） | 引擎是 GUI 子系统：用 `&`／`Tee-Object` 抓不到 stdout、`$LASTEXITCODE` 也是空的 ⇒ 必须重定向到文件再读 |

> 面包屑与 `test()` 都只在 debug 面，**别让它们进交付件**：T24 说装一台机器三步，而交付形态复核（本表第 6 行）是唯一能证明"日志线还活着"的那条。
