# 玄桌面 XuanDesk

Windows 桌面最底下的一层壁纸进程：可切换的 **3D 背景**（现有水族箱、星野两套）画在桌面图标与任务栏之下，
右上角一个独立、无边框、置顶、透明的 HUD。壁纸层由 `bin/host.exe` 挂进桌面的 WorkerW（所以它在图标**下面**），
HUD 是壳自己的 OS 窗口，**菜单是任务栏通知区里的一个托盘图标**（`host.exe` 自己画的 Win32 弹出菜单）。

本文只留概览：环境、命令、开关、架构、两套背景、性能、坑、验证。逐轮的量测账与历史讨论在 git 历史里，不再抄进来。

## 功能一览

- **壁纸层**：整屏 3D 场景挂在桌面图标之下、任务栏之下；多屏时可指定放哪一块屏。
- **可切换背景**：注册表一条一项，现成两套——**水族箱**（程序化 3D 水下场景 ＋ 硬件状态 HUD）与
  **星野**（真实天象星空：星表、银河、88 星座、日月行星、黄道与白道、廿八宿与星官）＋ 奇门/大六壬罗盘 HUD。
- **HUD 罗盘**：奇门时家盘与大六壬五环按当前时刻排盘，翻盘时字自己飞到新位置；外加时钟刻度、三根表针、视角弧与四角控件。
- **时间**：天钟可步进（时辰/日/月/年）、可加速、可冻结；盘上三针读的是**墙上时钟**。
- **桌面控制**：托盘菜单（换桌面 / 显示器 / 穿透 / 桌面 / 面板 / 退出）与热键；HUD 可拖、可鼠标穿透、可整体隐显（`面板`）。
- **静默**：星空按需渲染（静止不画），水族箱连续渲染。

## 目录

- [快速开始](#快速开始) · [调试开关与热键](#调试开关与热键) · [架构](#架构桌面壳--可换背景)
- [背景一：水族箱](#背景一水族箱) · [背景二：星野](#背景二星野3d-星空) · [性能与静默](#性能与静默)
- [踩过的坑](#踩过的坑不要重踩) · [验证](#验证)

## 快速开始

### 环境与工具链

| 用途 | 说明 |
|---|---|
| 工程 | Godot 4.7.2 工程，就是本目录 |
| Godot 运行时 | **用装好的编辑器版**（用户要求：不要在工程里放引擎副本）。`run.bat` / `run_debug.bat` 按 C–H 盘常见 Steam 路径找它，也可 `set GODOT=<godot.windows.opt.tools.64.exe>`。它是 GUI 子系统程序：`print()` 的 stdout 只进得了 `> 文件 2>&1`，别指望管道 |
| gcc / windres | mingw-w64（`native/build.cmd` / `native/build.sh` 自己找它们并清中间件） |
| 原生宿主 | `native/host.c` → `bin/host.exe`：壁纸挂载 + 托盘菜单 + **HUD 的窗口样式**（置顶/工具窗/不激活/穿透）+ 热键 + 指标流，唯一的原生件 |
| 参考工程 | 本地另一个 Godot 工程 lingwang：盘面与数据入口 `QimenSLG/compass/`（`compass_3d.gd` / `compass_view.gd` / `compass_data.gd`），排盘算法 `Scripts/Algorithm/{qimen,daliuren,calendar_util}.gd` + `Scripts/Defs/xuan_consts.gd`（本项目的奇门/大六壬由这四个文件移植） |

### 构建与运行

```bash
# 0) 引擎：装好的编辑器版（见上表）
export G="<Godot 编辑器版目录>/godot.windows.opt.tools.64.exe"

# 1) 原生宿主（等价于 native/build.cmd / native/build.sh）
native/build.cmd

# 2) 新增/移动 class_name 或目录后必须重导入，否则报 "Could not find type X"
"$G" --headless --path . --import

# 3) 跑（run.bat 自己找 Godot、并检查 bin/host.exe 在不在）
run.bat

# 出图 / 校验：参数必须写在 `--` 之后，落点目录要先存在
"$G" --path . -- --shot=<落点>.png --shot-frames=120 --wallpaper=0 --hud=0 --background=sky
```

- 用户参数一律写在 **`--` 之后**：`OS.get_cmdline_user_args()` 没有 `--` 就返回空数组，参数全落空（G29）。
- 出图的落点**目录**要自己先建：写盘不会替你建目录（G34）。
- 跑之前/之后杀掉所有遗留的 godot 与 host 进程（进程名带点，按 `godot.exe` 杀不干净，见 T18）。

### 硬约束（违反必然白干）

1. **绝不在重挂父窗口的调用里传 `SWP_FRAMECHANGED`**（V1）：Vulkan surface 会永久失效、画面永远不出。
2. **壁纸层是 Progman *内部*的 WorkerW**（W2），不是顶层窗口；选错会"挂载成功但全黑"。
3. **背景必须有真实几何**（V3）：只含 `Environment`（`BG_SKY`）的场景在重挂后的窗口里不 present。
4. **改目录后删 `.godot/` 再 `--import`**，否则路径缓存会把报错指向不存在的文件（G11）。

## 调试开关与热键

### 命令行参数（`--` 之后为用户参数）

| 参数 | 默认 | 说明 |
|---|---|---|
| `--wallpaper=0\|1` | 1（截图时自动 0） | 是否重挂到桌面壁纸层 |
| `--hud=0\|1` | 1 | 是否建 HUD 窗口 |
| `--background=<id>` | `sky` | 开哪个背景（`aquarium` / `sky`）。默认值写在 `Backgrounds.DEFAULT`，**不是**注册表第一条 |
| `--fps=<n>` / `--interval=<ms>` | 60 / 1000 | 帧率上限 / 指标采样周期 |
| `--shot=<png>` / `--shot-frames=<n>` / `--shot-target=main\|hud` | — | 渲染 N 帧后存图退出；`hud` 存 HUD 窗（托盘弹窗是系统的，截不到） |
| `--exit-after=<秒>` | — | 定时退出 |
| `--no-activate=0\|1` | 1 | HUD 窗口是否加 `WS_EX_NOACTIVATE` |
| `--desktop-screen=<n>` | 0 | 3D 桌面放哪块屏（＝托盘 → `显示器` 那一行） |
| `--sky-time=<unix\|ISO>` | 实时 | **星空专有**：天空的时刻（**按 UTC 写**，见 G32） |
| `--sky-rate=<倍>` | 1 | 天空时间流速（1＝实时，0＝冻结） |
| `--sky-view=<方位>,<高度>` | `180,42.5` | 相机朝向：正南、上抬 42.5°，即从整片天里截一段 |
| `--sky-fov=<度>` | 96 | 视场（12–179°）；地平线落在 `(0.5 + 高度/fov) × 画幅高`，最后几十 px 归任务栏 |
| `--sky-map=fisheye\|lens\|pan\|cylinder` | `fisheye` | 球面 → 屏用哪张网格（几何永远是那颗球，见「星点、记号与取舍」） |
| `--sky-figures=0\|1` | 1 | **星空专有**：星座图线与中文名（盘上 `星座` 那颗开关的初值） |
| `--sky-mansions=0\|1` | 1 | **星空专有**：宿名 + 星官图线/名 + 廿四节气名 + 斗的星改显神名 + 五星改显古名（盘上 `星宿` 那颗开关的初值） |

> 后七个由星空背景自己从同一命令行读（`shell/background.gd` 把 `Args` 注入每个背景）。

### 热键（`host.exe` 轮询 `GetAsyncKeyState`）

| 键 | 动作 |
|---|---|
| `Ctrl+Alt+H` | **显隐 3D 桌面本身**（壁纸窗口；事件 `toggle_desktop`，由 shell 决定） |
| `Ctrl+Alt+T` | HUD 鼠标穿透（锁定/解锁；与托盘的 `穿透` 同一件事） |
| `Ctrl+Alt+Q` | 退出 |
| 待定 | `Ctrl+Alt+B` 切换背景（现用托盘的 `换桌面`） |

> 跨进程穿透靠 `WS_EX_LAYERED | WS_EX_TRANSPARENT` 这一对，由 `host.exe` 套在 HUD 窗口上；Godot 的
> `Window.mouse_passthrough` 只让窗口对 `WM_NCHITTEST` 回 `HTTRANSPARENT`，事件会被**吞掉**（G40）。
> 穿透打开后唯一还点得到的就是托盘图标，这也是菜单当初要独立出来的原因。因此**托盘里有 `桌面` 与 `面板` 两行**：
> 前者隐显 **3D 桌面本身**（壁纸层是唯一会被系统壁纸盖掉、也是唯一"藏起来再放出来"能逼它重画一帧的东西），
> 后者隐显 **HUD 窗本身**（右上角那颗罗盘连同状态读数）；两个窗口都由 `host.exe` 隐显（`wall 0|1` / `hud 0|1`），
> 但开关的状态在壳里（`main.gd`），所以 respawn 的宿主会被重发一遍。

---

## 架构：桌面壳 + 可换背景

### 背景接口（加背景 = 加一个目录 + 注册表一条）

```gdscript

# shell/background.gd
class_name Background extends Node3D

func id() -> String                    # "aquarium" / "sky"
func display_name() -> String          # 中文名，进托盘菜单
func build(host: Node) -> void         # 建 3D 世界（可 await）
func teardown() -> void                # 释放
func build_hud() -> Control            # 本背景的 HUD 内容（每次切换新建，避免状态残留）
func hud_size() -> Vector2i            # 水族箱 280×280；星空罗盘更大
func render_policy() -> int            # CONTINUOUS / ON_DEMAND
func vignette_shader() -> Shader       # 各自的收尾色调
```

```gdscript

# shell/backgrounds.gd —— 注册表
const DEFAULT := "sky"                 # 开机开哪个（与下面 ENTRIES 的顺序无关）
const ENTRIES := {
	"aquarium": {"script": preload("res://backgrounds/aquarium/aquarium.gd"), "name": "水族箱"},
	"sky":      {"script": preload("res://backgrounds/sky/sky.gd"),           "name": "星空"},
}                                      # 顺序 = 换桌面子菜单的顺序
```

> 背景自己的开关（星空的 `星座` / `星宿`）画在背景自己的 HUD 里。**壳自己的开关**反过来只在托盘里：
> 背景的 HUD 不认识 `桌面`、也不给它留座（2026-10-12 一度把它转到盘左下角，2026-10-15 用户要求删掉那颗 chip，
> `hud_shell_slot()` 与其座一起从接口里去掉）。
> 托盘那两行是**壳自己两个窗口**的开关：`桌面`（壁纸窗）与 `面板`（HUD 窗，2026-10-15）——`桌面` 现在只有这一处座位，
> 状态仍只有客户端一份（`_desktop_shown`，谁动都走 `_toggle_desktop`，与 `Ctrl+Alt+H` 同一条路）。
> `面板` 行只在这次运行真有 HUD 窗时画（`--hud=0` 没有）。

### 目录结构

```
project.godot  run.bat  run_debug.bat  icon.svg
native/       host.c  build.cmd  build.sh  tray.rc  xuandesk.ico   ← 壁纸壳 + 托盘菜单 + HUD 窗口样式
bin/          host.exe
shell/        main.tscn main.gd          引导：窗口 + 背景注册表 + 切换 + 托盘模型 + 截图钩子
              background.gd              背景接口        backgrounds.gd  注册表
              wallpaper_window.gd        壁纸窗口设置（无边框/置顶/尺寸）
              hud_window.gd              HUD 窗壳：拖动 / 穿透 / 退出
              metrics.gd                 指标客户端（host 进程 + 回环 TCP + `menu …` 模型下行）
              args.gd  shots.gd
shared/ui/    中文字体加载（Fonts）、通用控件、主题
backgrounds/
  aquarium/   aquarium.gd fish_school.gd mesh_factory.gd hud.gd shaders/
  sky/        sky.gd                 舞台门：天球 + 时钟 + 相机 + 各层的建与接线
              sky_view.tscn sky_view.gd   ← 正式对照场景：把 SkyBackground 立起来，看/出一张与壁纸同图的画
              astro.gd observer.gd timecore.gd camera_rig.gd
              projection.gd projection_probe.gd   ← 天球→屏的投影，以及它的常驻探针（见「验证」）
              starcat.gd starfield.gd constellations.gd sky_lines.gd sky_labels.gd
              precession.gd lunar_terms.gd ecliptic.gd mansions.gd mansion_figures.gd
              planets.gd vsop87.gd sun.gd moon.gd
              branches.gd ganzhi.gd lunar.gd qimen.gd liuren.gd  ← 术数层（排盘算法 + 农历/道历）
              sky_branches.gd                                   ← 地平线上下的地支环 + 八方向
              hud_compass.gd hud_timebar.gd                     ← 罗盘与时间栏
              shaders/          dome star line sun moon sky_projection
              data/             catalog.txt vsop87b.dat SOURCES.md
```

### 切换流程

```
switch_to(id):
  if id == current: return
  old.teardown(); await old.tree_exited        # 显式释放，避免残留 GPU 资源
  new.build(self); add_child(new)
  hud_slot.replace(new.build_hud());  hud_window.size = new.hud_size()
  apply new.vignette_shader();  renderer.set_policy(new.render_policy())
  用 vignette 做 ~200ms 淡入淡出盖住空白帧
```

### HUD 与菜单

- HUD 窗壳只管拖动/穿透/退出，内容 `content_slot` 由背景提供、切换时整体替换。默认落在可用区右上角（右边 26、顶边 100），
  只有**第一次** `set_content()` 摆它，此后窗口待在用户拖到的位置。
- 菜单：托盘只放得下一枚图标和一次点击回调，**装不下别人的窗口**，所以菜单是 `host.exe` 自己画的 Win32 弹出菜单，
  客户端只提供内容（图标 `tray.rc` + `xuandesk.ico` 用 `windres` 编进 exe；承载窗是类名 `XuanDeskTray` 的隐藏顶层窗口；
  注册 `TaskbarCreated` 让 Explorer 重启后重挂）。弹菜单时每次现建，点了以后**只发一条事件**（`menu background <id>` 等），
  走与热键同一条通道——**托盘是第二个键盘，不是第二个脑子**，状态仍然只有客户端一份。
  行：`换桌面 ▸`（背景注册表）、`显示器 ▸`（只在有两块以上时画）、`穿透`、`桌面`（隐显壁纸窗）、`面板`（隐显 HUD 窗）、`退出`；
  `桌面` 行随桌面层本身（`--wallpaper=0` 时不画，那颗开关是空操作），`面板` 行随 HUD 窗（`--hud=0` 时不画）。
- Win11 默认把新图标塞进任务栏溢出区，第一次要用户自己拖到可见区（不替用户改别人的机器）。

### 指标流（`host.exe` → Godot）

127.0.0.1 回环 TCP、换行分隔 JSON、默认 1 Hz，**永远开启**（星空不消费也不亏，成本 1 Hz）：

```json
{"seq":12,"cpu":29.4,"mem_used":33285996544,"mem_total":68327845888,
 "gpu":44,"vram_used":6144,"vram_total":8188,"gpu_temp":63,
 "net_rx":134000,"net_tx":110000,"up":245,"wall":"ok","ev":["toggle_desktop"]}
```

字段：`cpu`（全核 %，`GetSystemTimes` 差值）、`mem_used/mem_total`（字节）、`gpu/vram_*/gpu_temp`（NVML；无 `nvml.dll` 时 `gpu=-1`）、
`net_rx/net_tx`（字节/秒，排除回环）、`up`（宿主运行秒数）、`wall`（壁纸状态 `ok/off/waiting/no-worker/hidden/failed`）、
`screens`/`screen`（显示器列表与当前那块，托盘的 `显示器` 读它）、`ev`（事件数组）。

事件（`ev` 里的字符串，热键与托盘那几行都走它）：`toggle_desktop` / `toggle_panel` / `toggle_clickthrough` / `quit` / `menu background <id>` / `menu screen <n>`。
反向通道（Godot → host，同一 socket 的裸文本行）：`quit`、`wall 0|1`、`screen <n>`、`lock 0|1`、`hud 0|1` 与一族 `menu …`（模型整份重发，宿主只管画）。
宿主按 `\n` 切行，两条命令粘在一个 recv 里也不会丢。Godot 是服务端（bind 127.0.0.1:0），host 是客户端（对端消失即自退）；
`wall`/`screen`/`lock`/`hud` 这四个宿主侧状态旗在链路起来时要重发。

---

## 背景一：水族箱

- `aquarium.gd` 程序化建场：水箱 9.0×3.4×5.0，相机在水箱内（FOV 66）缓慢漂移，`_process` 驱动 boids。
- 沙床（噪声丘 + 焦散）、石壁、礁石 ×10、水草 MultiMesh、水面（Gerstner + 水下菲涅尔）、玻璃四面（掠射角反射）、
  框架与灯带、气泡与海雪 GPUParticles3D；水下体积雾 + ACES（`tonemap_white=4.8`）。
- 鱼 3 种 × MultiMesh（程序化网格），`fish_school.gd` boids（聚/散/对齐 + 边界 + 障碍规避）。
- 焦散尺度必须匹配场景尺寸（用小值整屏一片死 flat）。
- 渲染策略 `CONTINUOUS`（鱼一直在游）——因此**不能拿它去验证**只在 `ON_DEMAND` 上才出现的问题。

---

## 背景二：星野（3D 星空）

### 复用清单

- **本工程（壳）**：`host.exe` 的壁纸挂载与热键、`hud_window.gd` 窗壳、`metrics.gd`、`args.gd`、`shots.gd`、`run.bat`。
- **lingwang `compass/`**：`compass_line.gdshader`（屏幕空间恒定 1px 发丝线）、环层系统（ArrayMesh + 显式 `render_priority`）、
  `moon_lit_polygon()`、换字飞转、`compass_view.gd` 的 HUD 交互范式、`compass_data.gd` 的时间基元、`CalendarUtil.get_ganzhi_info()`、配色。
- **必须重做的是天文**：lingwang 的太阳是"平太阳时角、与日期无关"的**盘面语义**，不是天象；星空换真模型。

### 天文算法（全部本地计算，无网络）

```
GMST(°)  = 280.46061837 + 360.98564736629·(JD−2451545) + 0.000387933·T² − T³/38710000
LST(°)   = GMST + λ_east ;  H = LST − RA
sin h    = sinφ·sinδ + cosφ·cosδ·cosH
A        = atan2(−cosδ·sinH, sinδ·cosφ − cosδ·sinφ·cosH)   # 自北起，向东为正
ε        = 23.4392911 − 0.0130042·T − 1.64e−7·T² + 5.04e−7·T³
太阳      = Meeus 25；月亮 = Meeus 47 主项；行星 = JPL 近似开普勒根数（木土改 VSOP87B）
岁差      = IAU 1976/2006 三欧拉角 → 天球节点一次旋转
蒙气差 R  = 1.02 / tan(h + 10.3/(h+5.11)) 角分 (Bennett)   # 只用于黄道/地平的口径换算
白道      = 真黄经取 120 点；月相 = fposmod(λ_moon − λ_sun, 360°)
```

天球做成一个可旋转 `Node3D`（`SkyRoot`）：恒星/星座/银河/宿度全部静止于天球，时间变化只需
`basis = R_precess(T) · R_lst(LST) · R_lat(φ)` **一次旋转**；日月行星挂兄弟节点，时间变更时重算赤道坐标。

### 数据源与许可

- 恒星：**Yale BSC5**（9110 条定宽记录，**9096 颗**有位置与 V 星等 ≤6.5，公有领域；其余 14 条是星表自己置空的撤档条目，解析时跳过）。
  中文名：自建 —— 9096 颗里 **882 颗**有名字（88 星座名 ＋ 28 宿名 ＋ 209 星官 947 条星名（873 颗互不相同）＋ 北极星 ＋ 斗的八颗 ＋ 廿四节气名；2026-10-15 探针实测）。
- 行星：JPL SSD 近似根数（公有领域）；**木星/土星**改用 VSOP87B 级数（5:2 共振，直线速率的根数跟不上）。
- 太阳/月亮：Meeus 25/47 自写实现（公式无版权）。
- **红线**：d3-celestial 的星座连线虽然仓库许可是 BSD-3，但上游**未声明数据溯源**，只作对照、不进仓库；
  落地时在 `backgrounds/sky/data/SOURCES.md` 记「URL + 许可 + 获取日期」，星表目录放 `.gdignore`（G12）。

### 星点、记号与取舍

- **投影**：`projection.gd` 与 `shaders/sky_projection.gdshaderinc` 共用**一张**"方向 → 像素"的网格，两边必须逐像素一致——
  天球本身由 shader 画，而名字层、两条地支环、日月盘、行星标记、白道这些 2D 的东西由 `SkyProjection.screen_point()` 摆；
  不一致就是"名字飘在别处"。离球心的网格另要 `keep_visible()`：画幅比相机 frustum 宽，画上的天体会被剔掉。
  `lens` 那一支没有映射，CPU 与 shader 用同一台相机的矩阵。
- **默认 = 鱼眼（等距方位，极点就在视轴上）**：径向一 Degree 就是一 Degree 的像素，画幅里**没有比中心更大的尺度**。
  代价两条：地平线是**弧**，北极星在朝南的画幅外（要看"以北极星为中心转"就把视轴转向北 `--sky-view=0,40`）。
- 四支的取舍（开场 2560×1440、正南 42.5°、fov 96；"尺度"＝相对画幅中心的最大倍数）：

| map | 中间尺度 | 最差尺度 | 转 10° 的残差 | 代价 |
|---|---|---|---|---|
| **`fisheye`（默认）** | 15.00 px/° | 1.52× | 3.38% | 地平线是弧 |
| `lens` | 11.31 px/° | 4.40× | 58.14% | 四角按 `sec²` 放大 |
| `pan` | 15.00 px/° | 1.49× | 43.20% | 两轴各一个常数尺度 |
| `cylinder` | 15.00 px/° | 11.46× | 95.07% | 转方向 = 整片天平移 |

- **三件事不能同时要**：平的地平线 / 星间距不变 / 转视角＝绕天顶那点转。要"地平线完全直"只有两条路：
  视轴压到地平线上（构图变成半地半天）、或 `--sky-map=cylinder`（天顶被拉成一行、转方向变平移）。
- **星点**：星等 → 尺寸/亮度是一根**刻意压缩**的感知斜坡（不是 Pogson 能量比，线性比值会让人觉得"只有几颗星"）。
- **银河**：银道坐标里的一条高斯带（不是贴图）。地平以下是**三层半透地面**（6°/层、每层再挡 1/4、缝上 0.75° 渐变），
  银河从三层里被逐层压暗透出来；星点不透——那一条只对银河与天光成立。
- **昼夜**：白天不关星（`DAY_STAR_FLOOR = 0.65`，银河单独 0.10）；地平用 2° 淡出代替大气消光，**不做**蒙气差。
- **月球**：盘面是一颗被太阳照亮的真球（相位是真几何），半径**放大 3 倍**（真视半径在默认画幅里只有 3.9 px）；
  白道按真黄经取 120 点走完一圈、每天重走一次；**月不在投影画幅里就连白道一起不画**（判据是画幅，不是相机 frustum）。
- **标签**：六类都画在同一个 `SkyLabels` 上（2D 投影、恒定屏显字号、只投画幅内且地平以上、重叠即丢），
  摆位优先级：北极星/斗的八颗星/月 → 行星名 → 宿名 → 廿四节气名 → 星官名 → 88 星座名。
- **记号**：北极星名（从同一份星表现查）；**北斗八星两套名**（`星宿` 关＝星名 `天枢…摇光` + 左辅，开＝神名 `贪狼…破军` + 洞明）；
  **五星也两套名**（`星宿` 关＝`水/金/火/木/土星`，开＝`辰星/太白/荧惑/岁星/镇星`；天王、海王不属五行，名字不随开关，2026-10-15）；
  **廿四节气**名（λ 每 15° 一格，刻只往黄道**北侧**画、不画圈；**当令那一个**用青色、其余 23 个灰一档，2026-10-15）；**天赤道**（淡赤）与 28 根**分野刻**（淡金，与节气刻同一根尺）、
  分野名（淡金，在赤道下方）与星官名（金，在星团身上）靠颜色分开；**天顶**是一个 1 px 淡白虚线十字（锁 world 的 +Y）。
- **滑行**：转向钮走 `1 − e^(−9·delta)`、时辰± 走 `1 − e^(−7·delta)`（每帧发 `changed`，看得见天在转）；
  拖动 / `--sky-view` / `现在` 是"立刻到位"那条路。

### HUD 罗盘规格（自内向外）

- 盘面 = 两张按当前时刻排的盘（奇门时家 / 大六壬）+ 中心太极；**环是数据不是算法**（`QiMen.pan()` / `LiuRen.pan()` 给什么画什么）。盘径 276、盘心 (150,150)。
- 太极 → 后天八卦卦符环 → **八分盘底色**（阳遁亮 `8/3/4/1`、阴遁亮 `2/9/6/7`，提亮那半就是内盘）→ **八宫三行块**
  （`神` / `星+天盘干` / `门+地盘干`，字正写不随盘转，值符神/星/门只染名金，旬空在神名左边挂 `〇`）
  → **大六壬环**（天盘支 + 遁干 + 贵人；下方五组翻正、左右两宫竖排；月将支染金、贵人染红）
  → **换字飞转**（同位不动 / 同心转 / 直线飞 / 淡出淡入，0.42 s，帧由卡自己推）
  → **时钟式度刻**（12 大 × 每大 5 小 = 60 根，"子"那根青色、唯一标记）
  → **视角弧**（张角 = 画幅真正的水平视场角，正中 = 相机方位−180°）
  → **四个方位三角**（上南下北，各自 24×24 真 Button）
  → **三针**（时针/分针/秒针从太极边缘向外；读的是观测者的**墙上时钟**，不是天钟）
  → **驿马 `马`**（r 92，正写，每过一个天空秒晃一下；按所落之支的五行着色——
  寅青 / 申白 / 巳赤 / 亥玄，2026-10-15）。
- **盘四角 = 两列控件**：`↙/↘` 转向；左列 `星座 / 星宿`（两行），右列 `时辰− / 时辰+ / 现在`（三行）；
  右列上方一颗 **`>>`** 换步长单位（**时辰 → 日 → 月 → 年** 循环，单位长度取整天 1/30/365 日；整圈一帧落地、只把余量平滑出来）。
- 卦符是**画的不是字**：本机系统字体里没有 ☰…☷（`FontFile.has_char()` 全 false），`hud_compass.gd` 用三根爻自己画。
- **盘固定 上南下北；"当前看哪"由盘外那圈视角弧说。要动盘上的字或排法，先去问用户。**

### 时间栏

盘下那条 40 px 的带子只有两行读数（`盘下沿那两列控件也是它画的`）：

```
左列: 星座 / 星宿                    九紫离火 道历四七二三年九月十四      右列: 时辰− / 时辰+ / 现在
                                     丙午 戊戌 丁巳 丁未 寒露中元 阴九局
```

第一行 = 玄空运名（随立春翻）+ 农历日期（**年用道历** = 农历年 + 2697）；第二行 = 四柱 + 节气 + 三元 + 局数（符号即阴阳遁）。
`桌面` 那颗壳的开关曾占左列第三行，2026-10-15 按用户要求删掉（只有托盘那一处了）。

### 盘外的两条地支环与开关

- 盘外·壁纸上：**地平线上/下是两条地支环**（下＝地盘十二支、上＝大六壬天盘支，贴同一条交线）——它是壁纸上的地平方位尺。
  天盘那侧是两行两字的块（`干支` 在下、`贵人` 双字名在上，双字名整行红、天盘支是月将时染金），再下一行是八方向（45° 一根）。
- 星座图线与中文名、宿名与星官图线是星空自己的两颗开关（画在盘左下角）。
  开关只关它自己说的那件事（G35：`星座` 不动宿与行星，`星宿` 不动赤道刻度、黄道与节气刻、行星与北极星的记号与位置——五星只换名字）。
- `sky_view.tscn` 是把 `SkyBackground` 立起来的**正式对照场景**（球 + 相机那几颗节点都在文件里，星星运行时布上去，跑 F6 才看得见）；
  判据：球上有星、地平线与地面占比与壁纸同图。

---

## 性能与静默

| 场景 | 策略 |
|---|---|
| 水族箱 | 连续渲染（鱼在游） |
| 星空 · 静态几何 | 恒星/星座/银河/网格静态，时间变化只改 `SkyRoot.basis` 一次旋转 |
| 星空 · 日月行星 | 只在时间步进时重算坐标（微秒级），本体只改 `Transform3D` 与亮度 uniform，**从不重建网格** |
| 星空 · 行星尾迹 / 月球轨道 | 每个**整数日**重算一次，其余时间静止 |
| 星空 · 二十八宿 | 与恒星同在 `SkyRoot` 上的静态几何（宿是 J2000 赤经分划），建好不动，名字每帧投影 |
| 星空 · 转向与步进 | 只在按下的那一两秒里逐帧重绘，之后回静默 |
| 渲染策略 | 归背景所有：`CONTINUOUS` 或 `ON_DEMAND`（`VIEWPORT_UPDATE_ONCE`，变化时背景自己 `request_redraw()`） |

实测 2560×1440：星空冻结 **0.47%**、实时（1 帧/秒）**0.83%**、连续 60 帧/秒 **16.2%**；水族箱 **36–51%**。
量之前先看整卡与显存，别把"别的进程占着卡"记到本工程头上。

**谁会要一帧**：时间（`changed`）、视角（`moved`）、HUD 的按钮，以及**宿主搬动/改尺寸窗口之后**（G36）——
漏掉最后一条的症状是"桌面换屏之后整块不见了"，而且只在 `ON_DEMAND` 的背景上出现。

---

## 踩过的坑（不要重踩）

### Windows 桌面壁纸层（Win11 25H2 · build 26200）

| # | 陷阱 | 处置 |
|---|---|---|
| W1 | 挂到了一个**隐藏的** WorkerW → `wall=ok` 但桌面纹丝不动 | 判定必须同时要求 `IsWindowVisible(worker)` |
| W2 | 顶层找不到可用的 WorkerW（本机 `0x052C` 不产生可见的顶层 WorkerW） | 真正的壁纸层是 **Progman 的子窗口 WorkerW**（与 `SHELLDLL_DefView` 同级） |
| W3 | 挂成 Progman 的子窗口 → 被 DefView/Progman 自己画的东西盖住 | **必须挂进那个 WorkerW**，不是 Progman |
| W4 | `FindWindowA("Progman", NULL)` 返回 0，而 `EnumWindows` 能枚举到 | 统一用 `EnumWindows` + `GetClassNameA` 找窗口 |
| W5 | 重挂后 `GetParent` 返回 0 | 跨进程 `SetParent` 要求目标窗口带 `WS_CHILD`：先把 `WS_POPUP` 翻掉 |
| W6 | 锁屏/桌面重建后进程消失 | 外来 `WM_CLOSE` **不退出**（只认 HUD 退出钮 / `Ctrl+Alt+Q`）；host 每 5s 复检挂载 |
| W7 | 挂载成功、出图正确，**屏幕截图上只有系统壁纸照片** | 那张图由 `SHELLDLL_DefView` 那一层画，而我们在它下面 ⇒ **桌面背景要设成纯色**（Lively / Wallpaper Engine 的标准前置条件）；Windows 主题会轮换壁纸图，症状会"过一会儿才出现" |

正确顺序（`host.c::apply_wallpaper`）：EnumWindows 找 Progman → 找 Progman 内**可见**、且没有 `SHELLDLL_DefView` 子窗口的 WorkerW
→ 加 `WS_CHILD` → `SetParent` → `SetWindowPos(HWND_BOTTOM, 无 SWP_FRAMECHANGED)` → 回读 `GetParent` 的 class 与可见性才算成功。

### Godot + Vulkan + 重挂父窗口

| # | 陷阱 | 处置 |
|---|---|---|
| V1 | `Couldn't get Vulkan surface capabilities (VkResult error -1000000000)`＝`VK_ERROR_SURFACE_LOST_KHR` | **绝不传 `SWP_FRAMECHANGED`**：它会重建重定向表面，Godot 的 surface 随之失效且永不恢复 |
| V2 | 进程正常、指标正常，画面永远不出 | 同上：surface 丢了就不 present |
| V3 | 重挂进 WorkerW 后画面全空（能透视看到原壁纸），换个背景就正常、`--shot` 也正常 | 背景**必须有真实几何**（星空用内表面天球网格），只含 `Environment` 的场景不 present |

> 这条是本项目最贵的坑：挂了父窗口却什么都看不见，而所有 API 都返回"成功"。

### Godot 4.7 API 陷阱（G）

| # | 陷阱 | 处置 |
|---|---|---|
| G1 | `TCPServer` 没有 `poll()` | 用 `is_connection_available()` / `take_connection()` |
| G2 | shader 里 fragment 阶段认不得 `INSTANCE_CUSTOM` | 它只在 **vertex** 阶段可用；要用就自己声明 varying 传下去 |
| G3 | `SurfaceTool` 顶点的法线格式不一致就报错 | 顶点格式在第一个顶点处锁定：要么每个顶点都 `set_normal`，要么都不设再 `generate_normals()` |
| G4 | 顶点色明明深蓝，渲染出来一片白 | shader 里的顶点色是**线性空间**：按 sRGB 写的调色板要 `.srgb_to_linear()` |
| G5 | 换了着色器还是纯白 | `MultiMeshInstance3D` **必须显式给 `material_override`** |
| G6 | 入树前 `look_at()` 报错 | 用 `Basis.looking_at(dir, up)`，或先 `add_child` |
| G7 | host 按标题找不到窗口 | 按「**进程 PID + 标题前缀**」匹配：`Window.title` 会覆盖 `DisplayServer.window_set_title()`，debug 构建还会追加 `" (DEBUG)"` |
| G8 | Godot 建的 overlay 窗 `IsWindowVisible = false` | host 启动后一次性 `ShowWindow(SW_SHOWNOACTIVATE)`（只做一次，否则后续隐藏会被顶回来） |
| G9 | 隐藏再显示 HUD 后置顶/穿透样式丢失 | Godot 隐藏 `Window` 会**销毁原生窗口**、再显示是新 HWND ⇒ 不缓存 HWND，host 每 5s 重套样式 |
| G10 | 截图拿到上一帧或黑图 | 先 `await RenderingServer.frame_post_draw` 再取图 |
| G11 | 新克隆/新目录报 `Could not find type "X"` | 跑一次 `--headless --path . --import` |
| G12 | `.godot/imported/` 里堆满运行时截图与数据 | 纯运行时目录放 `.gdignore` |
| G15 | `Window.render_target_update_mode` 报"不存在" | 该属性只在 `SubViewport` 上；用 `RenderingServer.viewport_set_update_mode(viewport_rid, …)` |
| G16 | 星点之外的透明物完全不渲染、且无任何报错 | 不透明几何**不要**用 `depth_draw_never`（会被归入透明队列、最后画并盖掉星点） |
| G17 | `--headless` 下探针读回的 MultiMesh 实例全是 0 | headless 用 `RendererDummy`：要读回顶点/实例数据的探针跑真渲染器 |
| G19 | `--script` 探针"卡死"，没有输出 | 多半是 `Parse Error` 让 `_init()` 没跑、`quit()` 永不执行：探针配 `timeout`，先看有没有 `SCRIPT ERROR` |
| G20 | `PlaneMesh` 建的"面向相机的圆面"完全不出现 | 它默认 `FACE_Y`（水平）⇒ 显式 `mesh.orientation = PlaneMesh.FACE_Z` |
| G21 | 缩放星空后星点成团、星座细带变宽 | 天球几何是按固定视场建的：vertex 里按归一方向缩放，`size_scale = fov / BASE_FOV` |
| G23 | 盘上的字全挤在左上角，但 `draw_circle` 是对的 | 极坐标点要写 `CENTRE + dir * R`，不是 `dir * R` |
| G24 | 探针"多一个刻/少一个刻"，图上却好好的 | 跨 0°/360° 缝时算术平均无意义：角度平均一律用圆均值 |
| G25 | 只读等距刻的探针在任意 15° 整数倍方位上都通过 | 要留**一个唯一标记**（本项目是"子/北"那根青刻）来读数，并把"换个方位声明同一张图"当负对照 |
| G26 | 银河画成烧白的发丝线 + 糊光 | 凡"点积 + `asin`/`pow`"的向量函数，先 `normalize`（半径 500 会被 `pow(…,2.5)` 放大成 5590） |
| G27 | 改完 `.gdshader` 整屏黑，进程与退出码全正常 | shader 编译错误只往 stderr 打一行、材质静默退化：改完 grep `shader error` |
| G29 | `--shot` 跑完、退出码 0，就是没有图 | 用户参数必须写在 `--` 之后 |
| G31 | 星座连线穿到隔壁星座、大量自交，但"什么都不缺" | 错在**连接关系**：判据要几何化（球面多边形"点在多边形内" + 大圆采样 + 自交检测），按传统图形重排 |
| G32 | `--sky-time` 出图"整片天转了半圈" | 它按 **UTC** 解析，而 HUD 的时辰/四柱是本地时间：出图一律写 UTC 或给 unix 秒 |
| G33 | 照"跨度更大"的直觉选 Table 2 的根数，天王星差到 1018″ | JPL 两版近似根数**由使用窗口决定**：1800–2050 那版（Table 1）在每一项上都更准 |
| G34 | `--shot=<路径>` 报 `err=7`、连 `err=0` 那条打印都没有 | 写盘不会建目录：落点目录先建好 |
| G35 | 按一个开关，别的层的东西一起消失 | 开关只关它自己说的那件事；往已有开关的层里加东西前先问"这个名字还成立吗" |
| G36 | 换屏/宿主重贴窗口后，`ON_DEMAND` 的背景整块不画 | 窗口被外力改尺寸不会有人再要一帧：这些动作之后主动 `request_redraw()` |
| G37 | 新加的一层整层不见，进程照跑、出图照出 | 数组字面量取出的元素要**显式打类型**（推不出类型的那条 `Parse Error` 会拖垮一串脚本）；排查看完整 stderr |
| G38 | 探针里行星位置全是 `nan` | `Astro` 里有两套时间戳：Unix 秒要走 `julian_day_from_unix()`（JD 应在 2.4e6 附近） |
| G39 | `--script` 探针在 `_initialize()` 里就建场景 → "全中"其实假通过 | 那时树还没入、`get_frustum()` 是空数组（对任何点都返回 true）：活放在 `_process()` 第一帧 |
| G40 | 穿透打开了，点击既不到 HUD 也不到下面的进程 | `WS_EX_LAYERED \| WS_EX_TRANSPARENT` 两个一起才跨进程；判据要真点一下、让对方**自己**记下 `WM_LBUTTONDOWN` |
| G41 | 托盘菜单项尾部多一个乱码字 | UTF-8 截断要**按字符**判：按字节丢续字节会吃掉每个中文标签的最后一个字 |
| G42 | 鱼眼探针在画幅正中的尺度量到 0，下游全成 `inf`/`nan` | `acos` 在极点的导数无限、float32 舍入成 0：差分步长取 0.25°，切向量从方向向量自己取正交对 |
| G43 | 地平以下浮着一条银河，天光/星点却规矩地停在地平线 | 银河是天球着色器里的一个**加项**、地平以下不是"层"而是色：地面改半透膜（三层、每层挡 1/4、缝上渐变） |
| G13/G14/G28/G30 | 一整套"把窗口粘在窗口上"的坑（嵌套 Window 只画第一帧、`unfocusable` 丢点击、`z_index` 只管画不管点、非激活窗里原生弹窗不出现） | **已随菜单搬进托盘全部退休**。教训留着：叠在别人的窗口上，就会赢它的字形和点击，能不做就不做 |

### 本机工具链与脚本环境（T）

| # | 陷阱 | 处置 |
|---|---|---|
| T1 | bash 工具跑的是 WSL：`/c/...` 不存在 | 用 `/mnt/c/...`，或干脆别在脚本里调 Windows 程序 |
| T2 | WSL 执行不了 Windows 二进制 | 构建命令交给工具调度，别写进 bash 脚本 |
| T4 | `-mwindows` 链接报 `undefined reference to WinMain` | 用 `-mwindows` 就得定义 `WinMain`（本项目就是），好处是永不弹控制台 |
| T8 | 脚本里 `gcc` 报 command not found | PATH 在 WSL 侧不生效：用绝对路径，或让 `build.cmd` 自己把 mingw 塞进 PATH |
| T9 | 合成点击落点乱飞（本机有程序持续扰动鼠标） | 驱动 HUD 用 `PostMessage` 点击（完全不碰光标），或改走 `--shot` + `--background` |
| T10 | 按进程量 GPU 一直读到 0 | 真 PID 看 `%LOCALAPPDATA%\XuanDesk\host.log` 里的 `pid=NNNN`；计数器要连续取样 |
| T11 | 判断"星点到底画出来没有" | 点状极大值（比 ±3px 邻域亮 30 以上）+ 与"无星版本"逐像素差分 |
| T17 | `curl` 拉 CDS 报 `CRYPT_E_REVOCATION_OFFLINE` | `curl --ssl-no-revoke`；落地后按字节数核对（半截文件不会报错） |
| T19 | 手摆的 chip 比设计尺寸高（要 60×24 量出 60×31） | `Button` 不会小于自己的最小尺寸，且样式盒还有内容边距：`set_content_margin_all(0)` + **`add_child` 之后再设 `position`/`size`** |
| T22 | `windres` 报 `preprocessing failed`，前面夹着一行"命令不是内部或外部命令"（gcc 装在带空格的路径下） | 它用**自己旁边那个 gcc** 预处理 .rc，并把那条路径原样拼进命令行：`--preprocessor` 换的是整条命令，要写全并让 PATH 去解析 |
| T23 | `bin/host.exe` 链得出，指标帧里的 `seq`/`mem_*`/`up` 却是垃圾数 | 老 mingw 的 `%llu` 落到 msvcrt：加 `-D__USE_MINGW_ANSI_STDIO=1`（判据：`-Wall` 一行输出都不该有） |
| T24 | 新机器上 `run.bat` 起得来，但桌面浮在图标上面、HUD 不出现 | `bin/host.exe` **不在 git 里**（`*.exe` 被忽略）：装一台机器三步 = `native/build.cmd` → `--headless --path . --import` → `run.bat`；先看 `%LOCALAPPDATA%\XuanDesk\host.log` 在不在 |

---

## 验证

改完必须**跑起来看**：判据是"屏幕上/数字上真的变了"，不是"代码看起来对"。

| 手法 | 判据 |
|---|---|
| **出图** `--shot=<png> --shot-frames=N --wallpaper=0 --hud=0 [--sky-time=<UTC> --sky-rate=0 --sky-view=<方位>,<高度>]` | 主视口 2560×1440；`--shot-target=hud` 存 HUD 窗；落点目录要先存在（G34） |
| **减图**（同机位两张逐像素差） | 差值只落在想量的那块；配一张"把改动退回去"的**负对照** |
| **开关 A/B 出图**（同一瞬刻、只改一个参数） | 隔离开关/一层的贡献，看两端各画了什么 |
| **常驻探针** `--headless --path . --script res://backgrounds/sky/projection_probe.gd` | 逐条打印 pass/FAIL、**退出码 = 失败行数**；每条都拿 `lens` 当负对照（径向尺度、形状拉伸、转 10° 的残差、间距漂移、地平线的弧与地面占比、画幅比 frustum 宽、四支的取舍表） |
| **现写探针**（用完即删） | 结果 dump 成文件再比（编辑器版 stdout 进不了管道）；配 `timeout`，看不到输出先看 `Parse Error`（G19） |
| **进程内按真钮 / 按卡自己的锚点取像素** | 起真 HUD 窗（`--wallpaper=0 --hud=1`），`button.pressed.emit()` 后抓窗纹理，按卡自己报的锚点读那一像素（坐标要从卡自己的常量算，写死就会量到别处） |
| **对权威** | 日月行星对 JPL Horizons 的 astrometric RA/Dec：实测太阳最差 16.83″、月亮 10.11″、行星 1800–2050 抽 20 日 < 5′ |
| **跨进程穿透** | HUD 下面摆一个**另一个进程**的窗口，`SendInput` 真点：穿透开它记下 `WM_LBUTTONDOWN`，关则一条都没有 |
| **停壳减图** | 桌面跑着时截一张 → 杀掉 godot 与 host 再截一张：与 HUD 无关的区域差 ~99% ⇒ 整块屏都是我们画的；被系统壁纸照片盖住时这个数 ≈ 0（W7 的唯一判据） |
| **负对照** | 每一条断言都要能被反过来证伪（等距刻在 15° 旋转下不变，所以盘上留了"子/北"那根青刻来读数，G25） |

碎图与探针**用完即删**；跑完整套前先确认没有遗留进程（`*godot*` 与 `host` 全为 0）。
