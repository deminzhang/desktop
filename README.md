# 玄桌面 XuanDesk

Windows 桌面最底下的一层壁纸进程：可切换的 **3D 背景**（现有水族箱、星野两套）画在桌面图标与任务栏之下，
右上角一个独立、无边框、置顶、透明的 HUD。壁纸层由**进程内**的原生扩展（`xuandesk_native.dll`）挂进桌面的 WorkerW（所以它在图标**下面**），
HUD 是壳自己的 OS 窗口，**菜单是任务栏通知区里的一个托盘图标**（同一个扩展自己画的 Win32 弹出菜单）。

本文只留概览：环境、命令、开关、架构、两套背景、性能、坑、验证。**逐轮的量测账与带日期的现场记录在 [devlog.md](devlog.md)**（10-16 之前的老账在 git 历史里），不再抄进来。

## 功能一览

- **壁纸层**：整屏 3D 场景挂在桌面图标之下、任务栏之下；多屏时可指定放哪一块屏。
- **可切换背景**：注册表一条一项，现成两套——**水族箱**（程序化 3D 水下场景 ＋ 硬件状态 HUD）与
  **星野**（真实天象星空：星表、银河、88 星座、日月行星、黄道与白道、廿八宿、三垣与星官）＋ 奇门/大六壬罗盘 HUD。
- **HUD 罗盘**：奇门时家盘与大六壬五环按当前时刻排盘，翻盘时字自己飞到新位置；外加时钟刻度、三根表针、视角弧与四角控件。
- **时间**：天钟可步进（时辰/日/月/年）、可加速、可冻结；盘上三针读的是**墙上时钟**。
- **桌面控制**：托盘菜单（换桌面 / 显示器 / 穿透 / 桌面 / 面板 / 退出）与热键；HUD 可拖、可鼠标穿透、可整体隐显（`面板`）。
- **静默**：星空按需渲染（静止不画），水族箱连续渲染。

## 目录

- [快速开始](#快速开始) · [调试开关与热键](#调试开关与热键) · [架构](#架构桌面壳--可换背景)
- [背景一：水族箱](#背景一水族箱) · [背景二：星野](#背景二星野3d-星空) · [性能与静默](#性能与静默)
- [踩过的坑](#踩过的坑不要重踩) · [验证](#验证) · [逐轮的量测账 → devlog.md](devlog.md)

## 快速开始

### 环境与工具链

| 用途 | 说明 |
|---|---|
| 工程 | Godot 4.7.2 工程，就是本目录 |
| Godot 运行时 | **用装好的编辑器版**（用户要求：不要在工程里放引擎副本）。`run.bat` / `run_debug.bat` 按 C–H 盘常见 Steam 路径找它，也可 `set GODOT=<godot.windows.opt.tools.64.exe>`。它是 GUI 子系统程序：`print()` 的 stdout 只进得了 `> 文件 2>&1`，别指望管道 |
| gcc / windres | mingw-w64（`native/build.cmd` / `native/build.sh` 自己找它们并清中间件） |
| 原生扩展 | `native/gdext/xuandesk_native.c` → 项目根的 `xuandesk_native.dll`（GDExtension，**跑在本进程内**）：壁纸挂载 + 托盘菜单 + **HUD 的窗口样式**（置顶/工具窗/不激活/穿透）+ 热键 + 指标采集，唯一的原生件；纯 C，不用 godot-cpp/scons/cmake，清单 `xuandesk_native.gdextension` 也在项目根 |
| 扩展接口头 | `native/gdextension_interface.h`（编辑器 dump 出来的 GDExtension 接口）：纯 C 扩展的构建输入 |
| 参考工程 | 本地另一个 Godot 工程 lingwang：盘面与数据入口 `QimenSLG/compass/`（`compass_3d.gd` / `compass_view.gd` / `compass_data.gd`），排盘算法 `Scripts/Algorithm/{qimen,daliuren,calendar_util}.gd` + `Scripts/Defs/xuan_consts.gd`（本项目的奇门/大六壬由这四个文件移植） |

### 构建与运行

```bash
# 0) 引擎：装好的编辑器版（见上表）
export G="<Godot 编辑器版目录>/godot.windows.opt.tools.64.exe"

# 1) 原生扩展（GDExtension，等价于 native/build.sh）：编出项目根的 xuandesk_native.dll
native/build.cmd

# 2) 新增/移动 class_name 或目录后必须重导入，否则报 "Could not find type X"
"$G" --headless --path . --import

# 3) 跑（run.bat 自己找 Godot、并检查项目根的 xuandesk_native.dll 在不在）
run.bat

# 出图 / 校验：参数必须写在 `--` 之后，落点目录要先存在
"$G" --path . -- --shot=<落点>.png --shot-frames=120 --wallpaper=0 --hud=0 --background=sky
```

- 用户参数一律写在 **`--` 之后**：`OS.get_cmdline_user_args()` 没有 `--` 就返回空数组，参数全落空（G29）。
- 出图的落点**目录**要自己先建：写盘不会替你建目录（G34）。
- 跑之前/之后杀掉所有遗留的 godot 进程（进程名带点，按 `godot.exe` 杀不干净，见 T18）。
- `native/build.cmd debug` 换一个带面包屑的调试版 DLL（`_gdext_init.log` + `test()` 探针钩子）；出货的 release 版两者都没有。`native/build.cmd host` 仍能编出遗留的 `bin\host.exe`（只作这次移植的对照，不参与运行）。

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
| `--background=<id>` | `sky` | 开哪个背景（`aquarium` / `sky`）。默认值写在 `Backgrounds.DEFAULT`，**不是**注册表第一条。五行那四行（`wood` / `fire` / `earth` / `metal`）只是占位，`create()` 会拒了它们并报错 |
| `--fps=<n>` / `--interval=<ms>` | 60 / 1000 | 帧率上限 / 指标采样周期 |
| `--shot=<png>` / `--shot-frames=<n>` / `--shot-target=main\|hud` | — | 渲染 N 帧后存图退出；`hud` 存 HUD 窗（托盘弹窗是系统的，截不到） |
| `--exit-after=<秒>` | — | 定时退出 |
| `--no-activate=0\|1` | 1 | HUD 窗口是否加 `WS_EX_NOACTIVATE` |
| `--desktop-screen=<n>` | 0 | 3D 桌面放哪块屏（＝托盘 → `显示器` 那一行） |
| `--wall-restart=<n>` | 0 | **内部**：这次运行已经重启过几代（桌面窗看护自己传给下一代，见 W8）。手起一代时不要给 |
| `--sky-time=<unix\|ISO>` | 实时 | **星空专有**：天空的时刻（**按 UTC 写**，见 G32） |
| `--sky-rate=<倍>` | 1 | 天空时间流速（1＝实时，0＝冻结） |
| `--sky-view=<方位>,<高度>` | `180,42.5` | 相机朝向：正南、上抬 42.5°，即从整片天里截一段 |
| `--sky-fov=<度>` | 96 | 视场（12–179°）；地平线落在 `(0.5 + 高度/fov) × 画幅高`，最后几十 px 归任务栏 |
| `--sky-map=fisheye\|lens\|pan\|cylinder` | `fisheye` | 球面 → 屏用哪张网格（几何永远是那颗球，见「星点、记号与取舍」） |
| `--sky-figures=0\|1` | 0 | **星空专有**：星座图线与中文名（盘上 `星座` 那颗开关的初值，**默认关**） |
| `--sky-mansions=0\|1` | 1 | **星空专有**：宿名 + 星官图线/名（28 宿 + 三垣）+ 廿四节气名 + 斗的星改显神名 + 五星改显古名（盘上 `星宿` 那颗开关的初值） |

> 后七个由星空背景自己从同一命令行读（`shell/background.gd` 把 `Args` 注入每个背景）。

### 热键（扩展在进程内轮询 `GetAsyncKeyState`）

| 键 | 动作 |
|---|---|
| `Ctrl+Alt+H` | **显隐 3D 桌面本身**（壁纸窗口；事件 `toggle_desktop`，由 shell 决定） |
| `Ctrl+Alt+T` | HUD 鼠标穿透（锁定/解锁；与托盘的 `穿透` 同一件事） |
| `Ctrl+Alt+Q` | 退出 |
| 待定 | `Ctrl+Alt+B` 切换背景（现用托盘的 `换桌面`） |

> 跨进程穿透靠 `WS_EX_LAYERED | WS_EX_TRANSPARENT` 这一对，由扩展套在 HUD 窗口上；Godot 的
> `Window.mouse_passthrough` 只让窗口对 `WM_NCHITTEST` 回 `HTTRANSPARENT`，事件会被**吞掉**（G40）。
> 穿透打开后唯一还点得到的就是托盘图标，这也是菜单当初要独立出来的原因。因此**托盘里有 `桌面` 与 `面板` 两行**：
> 前者隐显 **3D 桌面本身**（壁纸层是唯一会被系统壁纸盖掉、也是唯一"藏起来再放出来"能逼它重画一帧的东西），
> 后者隐显 **HUD 窗本身**（右上角那颗罗盘连同状态读数）；两个窗口都由扩展隐显（`wall 0|1` / `hud 0|1`），
> 但开关的状态仍然只有壳里那一份（`main.gd`，谁动都走同一条路）。

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
	"sky":      {"script": preload("res://backgrounds/sky/sky.gd"),           "name": "星空"},
	"aquarium": {"script": preload("res://backgrounds/aquarium/aquarium.gd"), "name": "水族箱"},
	"wood":     {"name": "木TODO", "todo": true},   # 五行还差这四种桌面：名字先占座，
	"fire":     {"name": "火TODO", "todo": true},   # 托盘画出来但是**灰的**（`menu bg` 第三段
	"earth":    {"name": "土TODO", "todo": true},   # ＝todo，原生侧加 MF_GRAYED|MF_DISABLED），
	"metal":    {"name": "金TODO", "todo": true},   # create() 也拒绝它们
}                                      # 顺序 = 换桌面子菜单的顺序（水族箱就是这个集合的「水」）
```

> 占位行（`todo: true`）是**看得见、点不动**的一行：壳照样把它当模型发下去（`menu bg <i> <cur> <todo> <id> <label>`），
> 扩展把它画成灰的，而且 `tray_command` 再拒一次（万一还是有条命令到了）；`Backgrounds.create()` 也拒，
> 所以 `--background=wood` 只会得到一条 `push_error` 和一个空桌面，不会把壳带到半路上。加一个真背景＝把 `script` 补上、`todo` 去掉。

> 背景自己的开关（星空的 `星座` / `星宿`）画在背景自己的 HUD 里。**壳自己的开关**反过来只在托盘里：
> 背景的 HUD 不认识 `桌面`、也不给它留座（一度把它转到盘左下角，后来用户要求删掉那颗 chip，`hud_shell_slot()` 与其座一起从接口里去掉；缘由见 devlog 10-12 / 10-15）。
> 托盘那两行是**壳自己两个窗口**的开关：`桌面`（壁纸窗）与 `面板`（HUD 窗）——`桌面` 现在只有这一处座位，
> 状态仍只有客户端一份（`_desktop_shown`，谁动都走 `_toggle_desktop`，与 `Ctrl+Alt+H` 同一条路）。
> `面板` 行只在这次运行真有 HUD 窗时画（`--hud=0` 没有）。

### 目录结构

```
project.godot  run.bat  run_debug.bat  icon.svg
xuandesk_native.gdextension           ← 扩展清单（entry_symbol = xuandesk_library_init）
xuandesk_native.dll                   ← 扩展本体，必须与 exe/pck 同目录（为什么见 X1）
native/       gdext/xuandesk_native.c ← 进程内的壁纸壳 + 托盘菜单 + HUD 窗口样式 + 热键 + 指标采集
              host.c                  ← 旧的双进程宿主，只作这次移植的对照参考，不参与运行
              gdextension_interface.h ← 编辑器 dump 的 GDExtension 接口，纯 C 扩展的构建输入（-I.）
              build.cmd  build.sh  tray.rc  xuandesk.ico
bin/                                  ← 历史构建输出目录，现在空着
shell/        main.tscn main.gd          引导：窗口 + 背景注册表 + 切换 + 托盘模型 + 截图钩子
              background.gd              背景接口        backgrounds.gd  注册表
              wallpaper_window.gd        壁纸窗口设置（无边框/置顶/尺寸）
              hud_window.gd              HUD 窗壳：拖动 / 穿透 / 退出
              metrics.gd                 指标客户端（直接调扩展的 start/command/poll/status + `menu …` 模型下行）
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
  只有**第一次** `set_content()` 摆它，此后窗口待在用户拖到的位置——**唯一还会动它的是它自己的看护**（2026-11-02）：
  整块窗口落在所有屏幕之外满 5 s 就搬回这个默认角，丢失与归位各写一行日志。桌面窗那边管的是"窗被销毁"（看护重启进程），
  这边管的是"窗还在、只是不在任何屏幕上"（看护搬回来）；两者判据不同，见「验证」与 devlog 11-02。
  拖动＝**抓点**（按下事件自己那个点）一直压在光标下（2026-11-03）：偏移不再"处理消息时读一次光标"去算，见 G45。
- 菜单：托盘只放得下一枚图标和一次点击回调，**装不下别人的窗口**，所以菜单是扩展自己画的 Win32 弹出菜单，
  客户端只提供内容（图标 `tray.rc` + `xuandesk.ico` 用 `windres` 编进扩展 DLL；承载窗是类名 `XuanDeskTray` 的隐藏顶层窗口；
  注册 `TaskbarCreated` 让 Explorer 重启后重挂）。弹菜单时每次现建，点了以后**只发一条事件**（`menu background <id>` 等），
  走与热键同一条通道——**托盘是第二个键盘，不是第二个脑子**，状态仍然只有客户端一份。
  行：`换桌面 ▸`（背景注册表，顺序就是注册表顺序；没建好的四种画成灰的、点不动）、`显示器 ▸`（只在有两块以上时画）、`穿透`、`桌面`（隐显壁纸窗）、`面板`（隐显 HUD 窗）、`退出`；
  `桌面` 行随桌面层本身（`--wallpaper=0` 时不画，那颗开关是空操作），`面板` 行随 HUD 窗（`--hud=0` 时不画）。
- Win11 默认把新图标塞进任务栏溢出区，第一次要用户自己拖到可见区（不替用户改别人的机器）。

### 指标流（扩展在进程内采集 → `shell/metrics.gd` 取帧）

扩展在**本进程内**按周期采样、攒成换行分隔的 JSON 帧，默认 1 Hz，**永远开启**（星空不消费也不亏，成本 1 Hz）；
`shell/metrics.gd` 每帧调一次 `poll()` 取走帧、解出字段后发 `frame_received`：

```json
{"seq":12,"cpu":29.4,"mem_used":33285996544,"mem_total":68327845888,
 "gpu":44,"vram_used":6144,"vram_total":8188,"gpu_temp":63,
 "net_rx":134000,"net_tx":110000,"up":245,"wall":"ok","ev":["toggle_desktop"]}
```

字段：`cpu`（全核 %，`GetSystemTimes` 差值）、`mem_used/mem_total`（字节）、`gpu/vram_*/gpu_temp`（NVML；无 `nvml.dll` 时 `gpu=-1`）、
`net_rx/net_tx`（字节/秒，排除回环）、`up`（扩展运行秒数）、`wall`（壁纸状态 `ok/off/waiting/no-worker/hidden/failed`）、
`screens`/`screen`（显示器列表与当前那块，托盘的 `显示器` 读它）、`ev`（事件数组）。

事件（`ev` 里的字符串，热键与托盘那几行都走它）：`toggle_desktop` / `toggle_panel` / `toggle_clickthrough` / `quit` / `menu background <id>` / `menu screen <n>`。
反向通道（`shell/metrics.gd` → 扩展，走 `command()` 的裸文本行，一次一条）：`quit`、`wall 0|1`、`screen <n>`、`lock 0|1`、`hud 0|1` 与一族 `menu …`（模型整份重发，扩展只管画）。
字段名与命令文法都与旧的双进程版**逐字相同**（旧版走的是同一 socket 上的文本行），所以 `shell/main.gd` 与各背景一行都不用改；
变的只是投递方式：进程内直调，没有 socket、没有粘包，也不再有对端会消失。

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

- **本工程（壳）**：进程内扩展的壁纸挂载与热键（`xuandesk_native.dll`）、`hud_window.gd` 窗壳、`metrics.gd`、`args.gd`、`shots.gd`、`run.bat`。
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
  中文名：自建 —— 9096 颗里 **1173 颗**有名字（88 星座名 ＋ 28 宿名 ＋ **287 星官 1261 条星名**（28 宿 209 星官 947 条 ＋ 三垣 78 星官 314 条；1173 颗互不相同）＋ 廿四节气名）。
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
  摆位优先级：北极星/斗的八颗星/月 → 行星名 → **月所在的那一宿** → 其余 27 宿名 → 廿四节气名 → 星官名 → 88 星座名
  （月所在那一宿先于其余 27 个摆位，免得它被相邻宿名挤掉）。
- **记号**：北极星名（从同一份星表现查）；**北斗八星两套名**（`星宿` 关＝星名 `天枢…摇光` + 左辅，开＝神名 `贪狼…破军` + 洞明）；
  **五星也两套名**（`星宿` 关＝`水/金/火/木/土星`，开＝`辰星/太白/荧惑/岁星/镇星`；天王、海王不属五行，名字不随开关）；
  **廿四节气**名（λ 每 15° 一格，刻只往黄道**北侧**画、不画圈；**当令那一个**用青色、其余 23 个灰一档）；**天赤道**（淡赤）与 28 根**分野刻**（淡金，与节气刻同一根尺）、
  分野名（淡金，在赤道下方）与星官名（金，在星团身上）靠颜色分开；**月所在的那一宿用白字**、其余 27 宿的淡金不变（判据是赤道宿度 —— 月所在时圈落在哪两根分野刻之间，与盘上画的分划同一把尺，
  见 `Sky._moon_mansion()`）；**三垣**（紫微/太微/天市）的 78 个星官走同一层、同一金色，垣本身不另立标签——
  星官名就是它们在盘上的名字，北天极与北斗一带因此不再空着；**天顶**是一个 1 px 淡白虚线十字（锁 world 的 +Y）。
- **滑行**：转向钮走 `1 − e^(−9·delta)`、时辰± 走 `1 − e^(−7·delta)`（每帧发 `changed`，看得见天在转）；
  拖动 / `--sky-view` / `现在` 是"立刻到位"那条路。
- **自动旋转**（用户 2026-11-12「长按可启动自动旋转，再短点任一停止」，同日下午「再慢一半」、傍晚「再降一半转速」）：盘角那两颗 `↙/↘`
  **按住 0.4 s** 就开始自己转，`SPIN_AZIMUTH = 3.75°/s`（**一山 4 s**，整圈 96 s），松手**不**停；此后**短点任一**停
  （一帧不差地停，**不**再走那一山）。停的判据只有"点了一下"，所以按住 0.4 s 以内仍是老行为：站着时一山 15°、
  正在自转时是那一下停。速率上机那天被用户连着砍两半（15 → 7.5 → 3.75°/s，即"一秒一山"→"两秒一山"→"四秒一山"）：
  这颗 chip 是**微调**，天回答得比眼睛放得下位置还快就是那两轮的由头。面包屑的精度也跟着走到 `%.2f`
  （`%.0f` 会把 7.5 印成 8、`%.1f` 会把 3.75 印成 3.8，而那行日志正是判据）。
  自转里**没有止境**，一切手动动作都盖过它：拖动、方位三角、时辰±、缩放、`现在`、`--sky-view` 各自 `stop_spin()`
  （写在每个 `stop_sweep()` 旁边）。它与那套 0.30°/s 的**空转**（`start_sweep()`，目前没有调用者）互不相干：
  一个给没人看的壁纸，一个给按着键的观测者。
  长按是**卡自己的钟**（`HOLD_SECONDS`，`_process` 里走），不是 Button 的：`Button` 只会说"按下过"，
  `button_pressed` 只在 toggle 模式下有意义 ⇒ 松手那一半取自窗口的 `_input`，按到哪儿松都算数
  （2026-11-03 那条"松手会丢"的教训：chip 的 `button_up` 丢了不能把一次长按留成自转）。

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
  寅青 / 申白 / 巳赤 / 亥玄）。
- **盘四角 = 两列控件**：`↙/↘` 转向（点＝一山 15°，按住 0.4 s＝自动旋转，再短点任一停）；左列 `星座 / 星宿`（两行），右列 `时辰− / 时辰+ / 现在`（三行）；
  右列上方一颗 **`>>`** 换步长单位（**时辰 → 日 → 月 → 年** 循环，单位长度取整天 1/30/365 日；整圈一帧落地、只把余量平滑出来）。
- **HUD 只有一个圆，没有方形底板**（2026-11-03）：窗口的底色就是 `_draw()` 开头那**一个圆**，半径 `R_VIEW_ARC`
  （= 盘沿 138 + 5 = 143），于是盘沿之外还留 5 px 卡片、视角弧那条带正好压在卡片自己的边上；窗口四角是**真桌面**，
  300×340 里除这个圆（和它上面的字/针/按钮）没有一处矩形。
  用户："我是[想]你把 HUD 半透明的方形去掉，做成大圆角贴近罗盘圈" —— "方角／方形"指的是**窗口那层底板**，
  不是 `↙/↘` 的角（那两颗 chip 为此白改了两轮，11-03 全退回原样）。落点是两处：
  `hud_window.gd` 的 `transparent_bg = true`（`transparent` 只管 OS 窗口，视口照样用清除色刷底），
  以及 `project.godot` 的 `default_clear_color` **RGB 必须是 0**（见 T30）。
- 卦符是**画的不是字**：本机系统字体里没有 ☰…☷（`FontFile.has_char()` 全 false），`hud_compass.gd` 用三根爻自己画。
- **盘固定 上南下北；"当前看哪"由盘外那圈视角弧说。要动盘上的字或排法，先去问用户。**

### 时间栏

盘下那条 40 px 的带子只有两行读数（`盘下沿那两列控件也是它画的`）：

```
左列: 星座 / 星宿                    九紫离火 道历四七二三年九月十四      右列: 时辰− / 时辰+ / 现在
                                     丙午 戊戌 丁巳 丁未 寒露中元 阴九局
```

第一行 = 玄空运名（随立春翻）+ 农历日期（**年用道历** = 农历年 + 2697）；第二行 = 四柱 + 节气 + 三元 + 局数（符号即阴阳遁）。
`桌面` 那颗壳的开关只剩托盘那一处（曾占左列第三行，已按用户要求删掉，见 devlog 10-15）。

### 盘外的两条地支环与开关

- 盘外·壁纸上：**地平线上/下是两条地支环**（下＝地盘十二支、上＝大六壬天盘支，贴同一条交线）——它是壁纸上的地平方位尺。
  天盘那侧是两行两字的块（`干支` 在下、`贵人` 双字名在上，双字名整行红、天盘支是月将时染金），再下一行是八方向（45° 一根）。
- 星座图线与中文名、宿名与星官图线是星空自己的两颗开关（画在盘左下角）。
  **`星座` 默认关**（`--sky-figures` 默认 0）：默认画面是一整片星，88 图线与中文名要谁自己去开（盘上那颗 chip 或 `--sky-figures=1`）。
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
| 星空 · 二十八宿 | 与恒星同在 `SkyRoot` 上的静态几何（宿是 J2000 赤经分划），建好不动，名字每帧投影；**只有"月在哪一宿"这一步跟着月走**（`_moon_mansion()`，每时间步一次，宿没换就不重绘） |
| 星空 · 转向与步进 | 只在按下的那一两秒里逐帧重绘，之后回静默 |
| 渲染策略 | 归背景所有：`CONTINUOUS` 或 `ON_DEMAND`（`VIEWPORT_UPDATE_ONCE`，变化时背景自己 `request_redraw()`） |

实测 2560×1440：星空冻结 **0.47%**、实时（1 帧/秒）**0.83%**、连续 60 帧/秒 **16.2%**；水族箱 **36–51%**。
量之前先看整卡与显存，别把"别的进程占着卡"记到本工程头上。

**谁会要一帧**：时间（`changed`）、视角（`moved`）、HUD 的按钮，以及**扩展搬动/改尺寸窗口之后**（G36）——
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
| W6 | 锁屏/桌面重建后进程消失 | 外来 `WM_CLOSE` **不退出**（只认 HUD 退出钮 / `Ctrl+Alt+Q`）；扩展每 5s 复检挂载（复检只在**窗口还在**时有用，窗口被销毁见 W8） |
| W7 | 挂载成功、出图正确，**屏幕截图上只有系统壁纸照片** | 那张图由 `SHELLDLL_DefView` **里面**那一层画，而我们在它下面 ⇒ **桌面背景要设成纯色**（Lively / Wallpaper Engine 的标准前置条件）；Windows 主题会轮换壁纸图，症状会"过一会儿才出现"。**别想着"挂高一层"绕过去**：把窗挂成 `SHELLDLL_DefView` 的**最底层子窗**（`SetParent` 成功、style 0x54000000、rect 0,0 2560×1440）后屏幕近白像素仍为 **0.0%**——画它的是 DefView 内部更上面的图标视窗，而能盖住照片的位置也会一起盖住图标（实测数字见 devlog 10-26 / 10-27） |
| W8 | 桌面重建时**壁纸窗本身被销毁**（它是 WorkerW 的**子**窗口，父窗口一没它就跟着没）。进程还在、HUD 还在，但 `wall` 永远 `waiting` ⇒ 托盘 桌面 行与 `Ctrl+Alt+H` 全成空转，只能重启进程 | shell 侧的桌面窗看护（`main.gd::_watch_desktop_window`）：`wall` 连续 12s 读 `waiting` 且桌面是想显示的状态 ⇒ **重启进程**（带上限；计数跨代用 `--wall-restart` 传下去，否则每代都是一次重生＝死循环；计数**不能**因为某次挂载成功就清零——一次成功挂载正是重启循环的样子，只能按时间过期，见 devlog 10-27），新代用 `--log-file` 拿到自己的日志，并把用户**当前**的背景/显示器写回命令行 |

> 这一晚的现场在 [devlog.md](devlog.md) 的 10-21 那节（桌面树里 1081 个窗口都找不到 `XuanDesk.Aquarium`、
> 日志里 2610 条 `VK_ERROR_SURFACE_LOST_KHR`、`TranscodedWallpaper` 在会话解锁后 48s 被重写）。
>
> **"隐藏再显示桌面"只在窗口还活着时成立**：想省掉重启的唯一路子是把桌面做成**自己的 `Window` 节点**（HUD 就是），
> 那样能就地重建；但现在这条路走不通：主窗是 `get_window()`，`hide()` 被 Godot 直接拒绝
> （`ERROR: Can't change visibility of main window.`）——G9 讲的是 `Window` **节点**，不是进程主窗。
>
> 客户端另外把壁纸层状态的**变化**写进日志（`XuanDesk: wallpaper layer 'waiting' / 'ok' / …`，`main.gd::_on_frame`）：
> 下一次丢失不必再从几千条交换链错误和窗口树快照里反推。

正确顺序（`gdext/xuandesk_native.c::apply_wallpaper`）：EnumWindows 找 Progman → 找 Progman 内**可见**、且没有 `SHELLDLL_DefView` 子窗口的 WorkerW
→ 加 `WS_CHILD` → `SetParent` → `SetWindowPos(HWND_BOTTOM, 无 SWP_FRAMECHANGED)` → 回读 `GetParent` 的 class 与可见性才算成功。
找不到可用的 WorkerW 就**什么都不做**（窗口留在顶层、`wall=no-worker`），下一个 5s tick 再试，**绝不退化成挂到桌面窗口**。

### Godot + Vulkan + 重挂父窗口

| # | 陷阱 | 处置 |
|---|---|---|
| V1 | `Couldn't get Vulkan surface capabilities (VkResult error -1000000000)`＝`VK_ERROR_SURFACE_LOST_KHR` | **绝不传 `SWP_FRAMECHANGED`**：它会重建重定向表面，Godot 的 surface 随之失效且永不恢复 |
| V2 | 进程正常、指标正常，画面永远不出 | 同上：surface 丢了就不 present |
| V3 | 重挂进 WorkerW 后画面全空（能透视看到原壁纸），换个背景就正常、`--shot` 也正常 | 背景**必须有真实几何**（星空用内表面天球网格），只含 `Environment` 的场景不 present |

> 这条是本项目最贵的坑：挂了父窗口却什么都看不见，而所有 API 都返回"成功"。

> 合并成单进程**没有**让这条坑退休：WorkerW 属于 Explorer，`SetParent` 本来就是跨进程调用，进程边界只是从
> 「Godot ↔ host.exe」换成了「Godot ↔ Explorer」。所以 V1/V2/V3 的防法一条都没改：每次挂载只发一次 `SetWindowPos`、
> **绝不传 `SWP_FRAMECHANGED`**，只有 `GetParent != WorkerW` 时才改样式再 `SetParent`。

### Godot 4.7 API 陷阱（G）

| # | 陷阱 | 处置 |
|---|---|---|
| G1 | `TCPServer` 没有 `poll()` | 用 `is_connection_available()` / `take_connection()`（回环链路已随合并删掉，这条 API 事实留着） |
| G2 | shader 里 fragment 阶段认不得 `INSTANCE_CUSTOM` | 它只在 **vertex** 阶段可用；要用就自己声明 varying 传下去 |
| G3 | `SurfaceTool` 顶点的法线格式不一致就报错 | 顶点格式在第一个顶点处锁定：要么每个顶点都 `set_normal`，要么都不设再 `generate_normals()` |
| G4 | 顶点色明明深蓝，渲染出来一片白 | shader 里的顶点色是**线性空间**：按 sRGB 写的调色板要 `.srgb_to_linear()` |
| G5 | 换了着色器还是纯白 | `MultiMeshInstance3D` **必须显式给 `material_override`** |
| G6 | 入树前 `look_at()` 报错 | 用 `Basis.looking_at(dir, up)`，或先 `add_child` |
| G7 | 按标题找窗口（旧的 host 就是这么干的） | 现在扩展由壳把两个 HWND 直接传进 `start(main_hwnd, hud_hwnd, …)`，不再按标题匹配；真要按标题找，记住 `Window.title` 会覆盖 `DisplayServer.window_set_title()`，debug 构建还会追加 `" (DEBUG)"` |
| G8 | Godot 建的 overlay 窗 `IsWindowVisible = false` | 扩展启动后一次性 `ShowWindow(SW_SHOWNOACTIVATE)`（只做一次，否则后续隐藏会被顶回来） |
| G9 | 隐藏再显示 HUD 后置顶/穿透样式丢失 | Godot 隐藏 `Window` 会**销毁原生窗口**、再显示是新 HWND ⇒ 不缓存 HWND，扩展每 5s 重套样式。**2026-11-03 补**：同一个"销毁再建"还会把窗口按 **Window 节点记住的位置**重建 —— 面板已经在屏幕外时，用托盘「面板」或 Ctrl+Alt+H 切换**救不回来**（节点记住的就是那个屏外坐标，切一次等于原样重建一次）；能救它的只有看护（`HudWindow.keep_on_screen()`） |
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
| G36 | 换屏/扩展重贴窗口后，`ON_DEMAND` 的背景整块不画 | 窗口被外力改尺寸不会有人再要一帧：这些动作之后主动 `request_redraw()` |
| G37 | 新加的一层整层不见，进程照跑、出图照出 | 数组字面量取出的元素要**显式打类型**（推不出类型的那条 `Parse Error` 会拖垮一串脚本）；排查看完整 stderr |
| G38 | 探针里行星位置全是 `nan` | `Astro` 里有两套时间戳：Unix 秒要走 `julian_day_from_unix()`（JD 应在 2.4e6 附近） |
| G39 | `--script` 探针在 `_initialize()` 里就建场景 → "全中"其实假通过 | 那时树还没入、`get_frustum()` 是空数组（对任何点都返回 true）：活放在 `_process()` 第一帧 |
| G40 | 穿透打开了，点击既不到 HUD 也不到下面的进程 | `WS_EX_LAYERED \| WS_EX_TRANSPARENT` 两个一起才跨进程；判据要真点一下、让对方**自己**记下 `WM_LBUTTONDOWN` |
| G41 | 托盘菜单项尾部多一个乱码字 | 同一个症状有两层，先前只治了第一层。**一**：`copy_str` 按字节截标签，按字节丢续字节会吃掉每个中文标签的最后一个字 —— 截断要**按字符**判（`trim_utf8`）。**二，真凶**：`string_to_utf8_chars` 的文档原文就是 **"It doesn't write a null terminator"**，而且 `p_max_write_length` 数的是**字符**、不是字节（一个字符最多 4 字节）。三个调用点却都当它写了 NUL 用，于是解析器读到了栈上残留（实测一条 17 字节的托盘行回来是 22 字节、多出的字节被 `MultiByteToWideChar` 变成 U+FFFD，中文标签后面就挂上乱码；那个按字符计的限长还能对一行 CJK 写出 4 倍缓冲区的长度，`line[512]` 会溢出——数字见 devlog 10-16）。处置：`string_to_utf8_bounded()` —— 先把缓冲区清零当终止符，再让引擎最多写 `(cap-1)/4` 个字符（即最多 cap-1 字节）。判据用 debug DLL 的那行面包屑 `menu item[i] label N B: …`：四个标签的字节长度全都要**等于字面长度**（数字见 devlog 10-16） |
| G42 | 鱼眼探针在画幅正中的尺度量到 0，下游全成 `inf`/`nan` | `acos` 在极点的导数无限、float32 舍入成 0：差分步长取 0.25°，切向量从方向向量自己取正交对 |
| G43 | 地平以下浮着一条银河，天光/星点却规矩地停在地平线 | 银河是天球着色器里的一个**加项**、地平以下不是"层"而是色：地面改半透膜（三层、每层挡 1/4、缝上渐变） |
| G44 | 面板（罗盘）在屏幕上"消失了"，窗口却活着、`IsWindowVisible=1`、DWM 也没 cloaked | `visible` 说的是"没被隐藏"，不是"看得见"：实测窗口 300×340 在 **(2692,1520)**，而两块 2560×1440 的屏加起来只有 **5120×1440** ⇒ 整块窗落在所有屏幕之外 80 px。判据只能拿 `GetWindowRect` 对**每块屏各自的矩形**求交（包围盒不行：并排两屏的包围盒里有的是两块屏都不在的十字区），且要宽高**各**够抓（40 px）；看护落在 `HudWindow.keep_on_screen()`（每秒一次），现场见 devlog 11-02 |
| G45 | 鼠标一靠近罗盘它就"躲"，最后躲出屏幕（2026-11-03） | 拖动偏移是**按下那一刻读光标**算出来的（`window_get_position() − mouse_get_position()`，两个量都在**处理消息时**读）：系统命中的是窗内一点，而读光标晚了几十毫秒 —— 一次甩鼠标或者被卡住的一帧就足够让读到的光标跑到窗口上边缘**之外**，偏移于是为**正**（窗在光标**下方**），此后 `target = 光标 + 偏移` 一路把窗摆在光标下方，光标追、窗躲。**松手那条消息只要丢一次**（锁屏、G9 的隐藏重建、换显示配置都在这一列），这个偏移就**永远**生效：实测用户那台机器上它生效了好几天，`_dragging` 卡在 true ⇒ **每一次鼠标移动**都搬它（一条 `WM_MOUSEMOVE` 带 **wParam=0** 都能把窗从 `(2608,1456)` 搬到 `(588,1341)`；由那次跳反推陈旧偏移 ＝ `(-103,+87)`，`+87` 意味着按下时光标在窗口上边缘外 87 px —— 一个"按点在窗内"永远算不出的值）。处置：偏移改成**按下事件自己的落点**（`_grab_point = event.position`，按定义必在窗内）⇒ 窗永远被摆成"抓点压在光标下"，几何上不可能躲开；落点**不在窗内**的按下（只有抓了鼠标才收得到）不开拖动；一次拖动超过 `DRAG_MAX_MS = 60 s` 就收尾并写一行日志；任何卡住的拖动被**下一次真点击**（按下＋松手都在窗内）收尾。**顺带解释"点别的东西没反应"**：按下时 Godot 会 `SetCapture`（实测 `hwndCapture`：按下前 `0` → 按下 `127802128` → 松手 `0`），松手丢了捕获就一直在 ⇒ 用户的每一次移动与点击都被送进面板 |
| G46 | 自己画的凹多边形整块不显示（`ERROR: Invalid polygon data, triangulation failed`），盘上的 chip 只剩一圈空框 | `draw_colored_polygon` 走 `Geometry2D::triangulate_polygon`，它要一条**简单多边形**：① 采样圆角时留下的**相邻重复点**（我先把角弧的起点显式加了一遍、采样器又加了一遍）以及与首点重合的**闭合尾点**都算零长边 ⇒ 整块不画；② 轮廓**镜像**过去（x → 2·中心 − x）会把绕向反过来，反绕的同样不画（实测：左 chip 从"163 px 的空框"变成 552 px 的实心，`triangulation` 报错 4 条 → 0 条）。处置：出轮廓后去掉相邻重复点、去掉与首点重合的尾点，镜像之后再 `reverse()` 把绕向正回来。**另一个变种**：圆的交点算出来**飞到框外**（半径 400 时交点在 (−234) 与 540）同样整块不画 ⇒ 圆没穿过框就退回普通小圆角（这一条正好当了负对照） |
| G47 | 合成的 `WM_LBUTTONDOWN`/`WM_LBUTTONUP`（`PostMessage`）**驱动不了 Godot 的 GUI**：`Node._input` 照跑，Button 却一条信号都不发（2026-11-12） | 报文到得了窗口过程（`HudWindow._input` 那条 `panel dragged to (…)` 照写，说明事件进了视口），但 `Viewport::_gui_input_event` 那一段没把按下交给任何 Control ⇒ 看着像"芯片死了/信号没接"。实测同一颗 `↙`：`PostMessage` 打十次里只有两次真的走到 Button（按住 0.9 s 也不出 `自动旋转`），`SendInput`（进系统队列、和真鼠标同一条路）每次都成；判据因此不能是"发一条按下"，得是**日志里那两行**。**同一轮顺带量到 headless 的两条**：`Viewport.push_input()` 打进一个**子 Window** 不做 GUI 命中（要 `root.gui_embed_subwindows = true` 并打进**根**视口），而 headless 的根视口恒为 **64×64**、`root.size = Vector2i(1000,800)` **改不动**（嵌入子窗的命中发生在**父**坐标里 ⇒ 每次事件前把面板滑到让按点落进根内即可，`window.position = (28,42) - at`） |
| G13/G14/G28/G30 | 一整套"把窗口粘在窗口上"的坑（嵌套 Window 只画第一帧、`unfocusable` 丢点击、`z_index` 只管画不管点、非激活窗里原生弹窗不出现） | **已随菜单搬进托盘全部退休**。教训留着：叠在别人的窗口上，就会赢它的字形和点击，能不做就不做 |

### 本机工具链与脚本环境（T）

| # | 陷阱 | 处置 |
|---|---|---|
| T1 | bash 工具跑的是 WSL：`/c/...` 不存在 | 用 `/mnt/c/...`，或干脆别在脚本里调 Windows 程序 |
| T2 | WSL 执行不了 Windows 二进制 | 构建命令交给工具调度，别写进 bash 脚本 |
| T4 | `-mwindows` 链接报 `undefined reference to WinMain` | 用 `-mwindows` 就得定义 `WinMain`（本项目就是），好处是永不弹控制台 |
| T8 | 脚本里 `gcc` 报 command not found | PATH 在 WSL 侧不生效：用绝对路径，或让 `build.cmd` 自己把 mingw 塞进 PATH |
| T9 | 合成点击落点乱飞（本机有程序持续扰动鼠标） | 驱动 HUD 用 `PostMessage` 点击（完全不碰光标），或改走 `--shot` + `--background` |
| T10 | 按进程量 GPU 一直读到 0 | 合并后没有宿主进程了：PID 就是 XuanDesk 自己（`Get-Process XuanDesk`）；计数器要连续取样 |
| T11 | 判断"星点到底画出来没有" | 点状极大值（比 ±3px 邻域亮 30 以上）+ 与"无星版本"逐像素差分 |
| T17 | `curl` 拉 CDS 报 `CRYPT_E_REVOCATION_OFFLINE` | `curl --ssl-no-revoke`；落地后按字节数核对（半截文件不会报错） |
| T19 | 手摆的 chip 比设计尺寸高（要 60×24 量出 60×31） | `Button` 不会小于自己的最小尺寸，且样式盒还有内容边距：`set_content_margin_all(0)` + **`add_child` 之后再设 `position`/`size`** |
| T22 | `windres` 报 `preprocessing failed`，前面夹着一行"命令不是内部或外部命令"（gcc 装在带空格的路径下） | 它用**自己旁边那个 gcc** 预处理 .rc，并把那条路径原样拼进命令行：`--preprocessor` 换的是整条命令，要写全并让 PATH 去解析 |
| T23 | `bin/host.exe` 链得出，指标帧里的 `seq`/`mem_*`/`up` 却是垃圾数 | 老 mingw 的 `%llu` 落到 msvcrt：加 `-D__USE_MINGW_ANSI_STDIO=1`（判据：`-Wall` 一行输出都不该有）。这个开关两条链都要挂（host 链与 DLL 链）：本机 gcc 15.1.0 不加它也把 `%llu` 印对，加上只是换成 mingw 自带的 printf（体积数字见 devlog 10-16）。判据不是"跑不跑得起来"，是 64 位字段还是不是数：`start()` 的 `hinst=140734492901376`、`hud_hwnd=18446744073709551615`（即 -1） |
| T24 | 新机器上 `run.bat` 直接报缺 `xuandesk_native.dll`（或绕过检查跑起来时桌面浮在图标上面、HUD 不出现） | 它在 `.gitignore` 里（`*.dll` 被忽略）：装一台机器三步 = `native/build.cmd` → `--headless --path . --import` → `run.bat` |
| T25 | 本机 `E:\xuandesk` 这个目录带 **Low 完整性标签**（`Mandatory Label\Low Mandatory Level:(OI)(CI)(NW)`） | 在它**内部新建或复制**的文件都会继承 Low，Windows 于是以 Low 完整性启动那个 exe，UIPI 随即拒绝 `Shell_NotifyIcon`（err=5）与跨进程 `SetParent`（err=5）：症状是**托盘没图标、壁纸挂在桌面窗口 `#32769` 上而不是 WorkerW**。绕法：先在 `E:\xuandesk` 之外生成，再**移动**进来（重命名不重新继承标签，复制会）；`icacls /setintegritylevel Medium` 在当前 shell 里被拒绝。**又一个变种**：**导出直接在原地写**，于是新 `XuanDesk.exe` 与 `XuanDesk.pck` 都带上了 Low 标签、一跑就是 Low 令牌（没托盘 + 挂不上 WorkerW），而同一份文件在 `%TEMP%`／工作区外就是 Medium ⇒ 判据是**文件标签**，不是父进程也不是谁按的启动（连计划任务 svchost 拉起的也照样 Low）。洗标签用 `.tmp/tools/relabel_delivery.ps1`（复制出去→移回来），**每次导出后都该跑一次**（现场见 devlog 10-27 18:20） |
| T26 | 扩展 DLL 被正在跑的 `XuanDesk.exe` 加载着时，`native\build.cmd` 报 `ld.exe: cannot open output file …: Permission denied` | 先关掉应用再编 |
| T27 | 用 PowerShell 的 `>`／管道去取一个 UTF-8 文件（`git show HEAD:x.gd > x.gd`） | 管道先按**控制台代码页**解码、再按文本写回：中文注释与 `「↙」` 这类字面量被换成替换字符 ⇒ 那个 `.gd` 直接编不过，而报出来的却是"`add_child()` 收到的是 GDScript"这种不相干的错（`.godot` 里的类缓存也跟着乱）。取字节用 **cmd 的重定向**（`cmd /c "git show HEAD:x.gd > file"`）或 `[IO.File]::WriteAllBytes()`；`Copy-Item` 搬文件是逐字节的，可以放心用（现场见 devlog 11-03） |
| T28 | `--export-pack "Windows Desktop" XuanDesk.pck.new` 直接失败：`Export path "…pck.new" doesn't end with a supported extension` | 导出器只认 `.pck`／`.zip`：先导到临时目录里的 `XuanDesk.pck`，再 `Copy-Item` 成 `XuanDesk.pck.new`（逐字节，见 T27）。顺带：`--export-pack` 只写包、不碰 `XuanDesk.exe`，而 `--export-release` 会按 `export_path` 把 109 MB 的 exe 一起重写 |
| T29 | 想改一个常量做负对照，`Set-Content -Encoding utf8NoBOM` 报"无法将 utf8NoBOM 与有效的枚举器名称相匹配"，脚本继续往下跑 | 这个 shell 名字叫 `pwsh`，实际是 **Windows PowerShell 5.1**（枚举里没有 `utf8NoBOM`，也没有 `-NoNewline` 语义下的一致性）⇒ **替换根本没发生**，"对照"跑的还是原代码。改工程里的字面量一律走 `edit` 工具，别用 shell 重定向；而且**改完立刻打印一行"改到底了没有"**（这次正是那行 `control in place: False` 把一次假对照拦下来的） |
| T30 | HUD 盖住的那块地方多出一个**半透明矩形**，大小正好是窗口，盘外一圈桌面色都跟着偏（2026-11-03） | 逐像素透明窗口的角像素是 **(RGB = 清除色, alpha = 0)**，而 DWM 按**预乘 alpha** 读它们 ⇒ 清除色被"加"在桌面之上、铺满整个窗口。判据：窗口内外的差**恒等于清除色**（实测 +3/+9/+14，正是 `Color(0.012,0.035,0.055,1)` 的 RGB），并且边界是**一像素陡坎**（投影是渐变，不会这样）。治法：`project.godot` 的 `default_clear_color` **RGB 归零**（alpha 留 1，给不透明窗口用）＋ HUD 窗口 `transparent_bg = true`。另：编辑器 `--main-pack` 跑出来的窗口会自己再铺一层底色，这条只能在**导出的 exe + 真桌面**上量 |

### GDExtension 与导出（X）

| # | 陷阱 | 处置 |
|---|---|---|
| X1 | 照 godot-cpp demo 的惯例把 `<name>.gdextension` 和库放进一个专用目录（如 `bin/`）→ 分发出去的副本找不到自己的库 | Windows 导出器把 GDExtension 库**按文件名拍平放到导出目录根部**，而 PCK 里的清单仍写着 `res://bin/xuandesk_native.dll`：路径对不上，`dlopen` 失败。所以清单与库都留在**项目根**（库就是 `res://xuandesk_native.dll`），导出时才会正好落在 exe 旁边；`.godot/extension_list.cfg` 登记 `res://xuandesk_native.gdextension` |
| X2 | 导出的星空缺星表，运行时报 `StarCat: catalogue missing at res://backgrounds/sky/data/catalog.txt`（VSOP87 表同理） | `all_resources` 模式**不包含裸 `.txt`/`.dat`**：`export_presets.cfg` 的 `include_filter` 要写成 `"*.txt,*.dat"` |
| X3 | PCK 里静静躺着 6.9 MB 的 `extension_api.json`（编辑器 dump 的绑定转储，工程里没有任何引用） | `.json` 是 Godot 的可导入资源，会被打进 PCK；它已移出工程（在 `.tmp/`）。移走后 PCK 从 9,079,792 B 降到 **2,100,784 B**（该留的只有星表 `catalog.txt` 1.71 MB ＋ `vsop87b.dat` 40 KB 那一份） |

---

## 验证

改完必须**跑起来看**：判据是"屏幕上/数字上真的变了"，不是"代码看起来对"。

| 手法 | 判据 |
|---|---|
| **出图** `--shot=<png> --shot-frames=N --wallpaper=0 --hud=0 [--sky-time=<UTC> --sky-rate=0 --sky-view=<方位>,<高度>]` | 主视口 2560×1440；`--shot-target=hud` 存 HUD 窗；落点目录要先存在（G34） |
| **减图**（同机位两张逐像素差） | 差值只落在想量的那块；配一张"把改动退回去"的**负对照**。**盘面这种活内容别指望整窗零差**：三针与换字飞转的落点是亚像素的，同一份代码跑两次也会有几百个像素不同（2026-11-03 量到 705 px 挤在一颗字上）⇒ 判据要收进**要量的那个小 region** 里数。那一轮的负数：两颗 chip 各 24×24 框内 556 → 531，改动**全**在外侧 12×12 角里（139 → 114），框内其余部分 417 → 417 **逐像素相同**、箭头那 17 个亮像素一个不差；要冻住时钟就加 `--sky-time=<固定> --sky-rate=0`。**"少画一块"的改动，框内总像素数不是判据**：chip 的内角被视角弧切掉约 12 px，可切出来的那段弧边界又多了几 px ⇒ 同一颗 chip 只从 554 掉到 **552**（负对照＝把弧的半径改到圆穿不过框、退回小圆角，同一份代码同一个位置，554）⇒ 判据要落到**具体像素的颜色**：被切掉的那两 px（右 chip 的 `(262,63)`、`(263,64)`）该露出**弧自己的亮青** `rgb(73,208,244)`，而 chip 的填充压在上面时它们是 chip 的暗青 `rgb(47,117,136)`（两颗 chip 各 552 px、`triangulation` 报错 0 条） |
| **开关 A/B 出图**（同一瞬刻、只改一个参数） | 隔离开关/一层的贡献，看两端各画了什么 |
| **常驻探针** `--headless --path . --script res://backgrounds/sky/projection_probe.gd` | 逐条打印 pass/FAIL、**退出码 = 失败行数**；每条都拿 `lens` 当负对照（径向尺度、形状拉伸、转 10° 的残差、间距漂移、地平线的弧与地面占比、画幅比 frustum 宽、四支的取舍表） |
| **面板看护自测**（真窗、**不碰光标**；`PostMessage` 走按下/移动/松开，同 T9）起 dev 实例 `--wallpaper=0 --hud=1 --exit-after=90`，从外面 `SetWindowPos` 推 + 发 `WM_LBUTTONDOWN/MOUSEMOVE/LBUTTONUP` | 四条判据、都是**行数/坐标**不是观感：① 健康 9 s 窗稳在 `(2234,100)` 且日志里**没有** `panel window is off every screen`；② 屏内那段拖动落点不变（`panel dragged to (2234,100)`，夹子不插手）；③ 先推到 `(2692,1520)` 再拖 ⇒ 落点 `(2692,1100)`（夹子把屏外那一拖拉回副屏内）；④ 推到 `(2692,1520)` 后不动它 ⇒ +3 s 仍在屏外（grace 内）、**+8 s 回到 `(2234,100)`**，日志两行：`off every screen at (2692,1520) 300×340 - waiting 5000 ms` 与 `was nowhere for 5000 ms - back to the default corner (2234,100)` |
| **现写探针**（用完即删） | 结果 dump 成文件再比（编辑器版 stdout 进不了管道）；配 `timeout`，看不到输出先看 `Parse Error`（G19） |
| **面板拖动自测**（真窗、**不碰光标**；`PostMessage` 走按下/移动/松开，同 T9）起 dev 实例 `--wallpaper=0 --hud=1 --exit-after=150`，判据都是坐标 | ① 拖动活着时**从背后**把窗推到 `(2600,1450)`（桌面外），再发一条**不带任何键**的 `WM_MOUSEMOVE` ⇒ 窗回到 `(1665,322)` ＝ 光标 `(1765,442) − 抓点(100,120)`，**在屏内**（旧代码走这条路是往光标反方向跑，最后出屏）；② 落点在窗**外**的按下（`lParam=(-400,-400)`）＋带键移动 ⇒ 窗不动；③ 带键移动 ⇒ 窗摆在"抓点压着光标"处、松手写一行 `panel dragged to (…)`。**这一条会把鼠标捕获走**（Godot 按下即 `SetCapture`，见 G45）⇒ 别把 dev 面板留在用户光标底下：第一次跑第 ④ 条时就是这样被用户自己的移动与点击打断的（日志里多出 `panel dragged to (1884,307)`／`(2633,976)`） |
| **拖动状态机探针** `--headless --path . --script res://shell/hud_drag_probe.gd`（现写，用完即删） | 手搓 `InputEventMouseButton/Motion` 直接喂 `HudWindow._input()`：**不碰窗口消息、不抓鼠标**，时间直接改 `_drag_started_ms`，于是 60 s 那条不必攥着鼠标等一分钟。**5 条 pass / 0 FAIL**（退出码 0）：窗内按下成抓（`grab=(100,120)`）、窗外按下被拒、新鲜拖动不被移动事件收尾、超过 `DRAG_MAX_MS` 的拖动被收尾、松手收尾 |
| **看护自测**（不碰真桌面）`--headless --path . -- --wallpaper=1 --hud=0 --wall-restart=<n> --exit-after=<秒>` | headless 里没有原生窗，`wall` 必定一直是 `waiting`，看护必定触发：12s 后本代重启下一代，下一代命令行带 `--wall-restart=<本代+1>`。判据是**顶层窗口标题**（`.tmp/tools/probe_xd.ps1`：`XuanDesk.Aquarium` 与 `XuanDesk tray` 各多一个、pid 不同），到上限那一代只打印 `still gone after N restarts` 不再生 |
| **进程内按真钮 / 按卡自己的锚点取像素** | 起真 HUD 窗（`--wallpaper=0 --hud=1`），`button.pressed.emit()` 后抓窗纹理，按卡自己报的锚点读那一像素（坐标要从卡自己的常量算，写死就会量到别处） |
| **对权威** | 日月行星对 JPL Horizons 的 astrometric RA/Dec：实测太阳最差 16.83″、月亮 10.11″、行星 1800–2050 抽 20 日 < 5′ |
| **跨进程穿透** | HUD 下面摆一个**另一个进程**的窗口，`SendInput` 真点：穿透开它记下 `WM_LBUTTONDOWN`，关则一条都没有 |
| **停壳减图** | 桌面跑着时截一张 → 杀掉 godot 再截一张：与 HUD 无关的区域差 ~99% ⇒ 整块屏都是我们画的；被系统壁纸照片盖住时这个数 ≈ 0（W7 的唯一判据；实测数字见 devlog 10-26 / 10-27） |
| **交付形态复核** | 换完 PCK 必须用**交付的 exe**（不是编辑器版 + `--main-pack`）跑一次 `--headless -- --wallpaper=0 --hud=0 --exit-after=6`：stdout 里不许出现 `project.binary` 的 ERROR，且**默认路径**（不带 `--log-file`）的 `godot.log` 必须非空。**只有这条能看出坏包**（编辑器版会把工程设置从自己上下文里补齐，照样跑得欢；现场见 devlog 10-26）。**注意**：默认路径就是**用户那代正在写的** `godot.log`，跑一次就等于把它轮转掉（内容不丢，只是换了文件名，见 devlog 11-02 的副作用那条）——所以有活着的实例时，判据取 stdout 那两条（`project.binary` 的 ERROR ＋ 三条正常日志行）＋ `--log-file` 那份非空结尾 `shutting down`，别去碰默认路径 |
| **转向钮长按/短点探针**（headless、现写即删，三版）`--headless --path . --script res://shell/_tmp_sky_spin_probe.gd` | 真 `HudWindow` + 真 `SkyCompassHud` 摆进**根**视口，事件走 `root.push_input()` 的**真 GUI 分发**（Button 信号 → `_chip_down` / `_step_hold` / `_chip_up` → `CameraRig`），判据全是**度数**。15°/s 那版 **22 条 pass / 0 FAIL**：点一下 `↙` ＝ 恰好 `-15.000°` 且不自转；按住 0.2 s 松手 ＝ 一山 `+15.000°`、仍不自转；按住 0.5 s **按着就开始转**、量到 `-15.07°/s`、松手**继续**转；转着时短点另一颗 `↘` ⇒ 停，且此后 `0.000°`（那一下**不**再补一山）；按住 `↘` ⇒ 顺行、紧接着按 `↙` ⇒ 立刻反向；在 chip 上按下、拖到卡面上松手 ⇒ 一次点照走、自转照转；按**卡面** 0.5 s ⇒ 不自转且视角 `0.000°`（负对照）。两次减半后各重跑一版，**都是 12 条 pass / 0 FAIL**：7.5°/s 那版 rig 直走 4.0 s ＝ `30.000°`、松手后 1.0 s／2.0 s ＝ `7.55°`／`15.06°`；**3.75°/s 那版** rig 直走 8.0 s ＝ `30.000°`（整圈 **96.0 s**）、松手后 2.0 s／4.0 s ＝ `7.512°`／`15.022°`、按住那 0.1 s（0.4 s→松手）＝ `0.400°`、点一下仍 `-15.000°`、转着短点仍 `0.000°`。面包屑：`sky: 自动旋转 左（逆行） 3.75°/s`、`sky: 自动旋转停（左，转了 15.4°）`。**判据的坑**：计时窗口必须从**松手**那刻起 —— 0.5 s 的按住里已经转了（0.4 s→松手）那一段，从按下前算会平白多出 0.375°/0.75°，第一版就是这么报了个假 FAIL |
| **真窗长按**（交付形态 + `SendInput` 真键；只在机器空着时跑） | 判据是日志那**两行**，不是观感：真按住 `↙`（客户区 `(28,42)`）0.9 s ⇒ `sky: 自动旋转 左（逆行） 15°/s`（减半前那次；同一条路现在印 `7.5°/s`）；松开 1.2 s 后短点一下 ⇒ `sky: 自动旋转停（左，转了 26.0°）`（26.0 ≈ 自转真正走到的 1.7 s × 15°/s）。**两个坑**：① 合成点击必须 `SendInput`，`PostMessage` 到不了 GUI（G47）；② **用户自己的鼠标会插进来**（同 G45 那条）：`SetCursorPos` 之后光标被挪走、日志里多出一条不是我们点的 `panel dragged to (2234,100)`，于是合成键落在别处 ⇒ 有活实例/有人在用时判据取探针那条 |
| **负对照** | 每一条断言都要能被反过来证伪（等距刻在 15° 旋转下不变，所以盘上留了"子/北"那根青刻来读数，G25） |

碎图与探针**用完即删**（按 `.tmp/` 的约定：它们不进 git，也不留在工程里）；跑完整套前先确认没有遗留进程（`*godot*` 全为 0，本机那把 `xuankill.ps1` 在 `.tmp/tools/`）。

### 逐轮的量测账

带日期的现场记录、量到的数字、以及"当时为什么这么改"，都在 **[devlog.md](devlog.md)**：
2026-10-16 原生件搬进进程内（门 1/2/3）与 `__USE_MINGW_ANSI_STDIO`、10-21 桌面窗看护、10-26 两次丢失与真机自愈、
10-27 纯黑副屏与上限漏洞、10-27 月宿白字与 Low 标签、10-28 三垣、11-02 **面板窗落在所有屏幕之外**（面板看护那一轮）、
11-03 **面板被一次没松手的拖动带到光标外侧、最后出屏**（抓点那一轮：现场一条不带任何键的鼠标移动就能搬窗）、
11-03 **方形底板改成 r=143 的圆盘**（用户"把 HUD 半透明的方形去掉，做成大圆角贴近罗盘圈"→"到视角弧上"：逐像素透明窗口的清除色渗色清掉，盘只剩一个圆，四角就是真桌面；chip 那两轮白改已全退）、
11-04 **换桌面五行补齐**（星空第一项 + 木火土金四行灰置 TODO）、11-12 **转向钮长按自转、短点停**（自转 3.75°/s——先做 15，用户当天两度砍半「再慢一半」「再降一半转速」；停的那一下不补一山。另附 `PostMessage` 到不了 Godot GUI 那条），
末尾还附了一张「调试日志线索」表
（`--log-file`、`godot.log` 的缓冲、`wallpaper layer '<state>'`、debug DLL 的面包屑）。改完往那份账的末尾加一节即可。
