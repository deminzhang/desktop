# 玄桌面 XuanDesk

Windows 桌面最底下的一层壁纸进程：可切换的 **3D 背景**（现有水族箱、星野两套）画在桌面图标之下、任务栏之下，
右上角一个独立无边框透明置顶的 HUD（水族箱显硬件状态，星野显奇门/大六壬罗盘 + 时间栏）。
壁纸层由 `bin/host.exe` 挂进桌面的 WorkerW，HUD 与菜单是壳自己的两个 OS 窗口。

本文是**技术参考**：环境、命令、开关、架构、算法、盘面规格、踩过的坑、怎么验证——写的都是**已经落地的做法**。
"做到哪了 / 还差什么 / 每一条验收是怎么量出来的"在 `计划.md`（那里按轮次记流水）。

## 目录

- [快速开始](#快速开始) · [调试开关与热键](#调试开关与热键) · [架构](#架构桌面壳--可换背景)
- [背景一：水族箱](#背景一水族箱) · [背景二：星野](#背景二星野3d-星空) · [性能与静默](#性能与静默) · [验证](#验证)
- [踩过的坑](#踩过的坑不要重踩)

## 快速开始

### 环境与工具链

| 用途 | 路径 |
|---|---|
| 工程根 | `E:/xuandesk` |
| Godot 4.7.2 | **用装好的编辑器版**（用户要求：不要 `tools/` 里下载的副本）：`E:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe`（`4.7.2.stable.steam.ed1daf0bf`）。`run.bat` / `run_debug.bat` 自己按 C–H 盘的常见 Steam 路径找它（也可 `set GODOT=…` 指定）；find/replace 时用 `export G="…/godot.windows.opt.tools.64.exe"`。**注意**：它是 GUI 子系统的程序，`print()` 的 stdout 只进得了 `> 文件 2>&1`，不要指望管道。`tools/godot.exe` + `tools/godot_console.exe` 是旧副本（同一版），**已不再引用** |
| `tools/` 里的 PS 脚本 | `wins.ps1` 窗口几何 / `shot_screens.ps1` 逐屏截屏 / `desk_capture.ps1` 最小化后再截 / `click.ps1` 向窗口投 PostMessage 点击 / `xuankill.ps1` 杀干净 / `mon.ps1` 显示器列表 |
| gcc | `C:/mingw64/bin/gcc.exe`（mingw-w64 15.1.0） |
| 原生宿主 | `native/host.c` → `bin/host.exe` |
| 参考项目（罗盘 HUD / 排盘算法） | 盘面与数据入口：`E:/lingwang/Scenes/Features/QimenSLG/compass/`（`compass_3d.gd` / `compass_data.gd`）；**排盘算法**：`E:/lingwang/Scripts/Algorithm/{qimen,daliuren,calendar_util}.gd` + `E:/lingwang/Scripts/Defs/xuan_consts.gd`（本项目的奇门/大六壬就是从这四个文件移植的） |

### 三条命令

```bash

# 0) 二进制：装好的编辑器版（**不用 tools/ 里的副本**，见「环境与工具链」）
export G="E:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe"

# 1) 构建原生宿主（Windows 侧执行，不要在 bash 脚本里跑，见 T1/T2/T8）
C:/mingw64/bin/gcc.exe -O2 -s -Wall -Wextra -mwindows -o bin/host.exe native/host.c \
    -lws2_32 -liphlpapi -luser32 -ladvapi32 -lshell32
#    （或 native/build.cmd，它自己把 C:\mingw64\bin 加进 PATH）

# 2) 导入工程（新增/移动 class_name 或目录后必须跑，否则报 "Could not find type X"）
"$G" --headless --path . --import

# 3) 跑起来 / 出图 / 校验
powershell -NoProfile -Command "Start-Process 'E:\xuandesk\run.bat' -WorkingDirectory 'E:\xuandesk' -WindowStyle Hidden"
"$G" --path . -- --shot=shots/x.png --shot-frames=120 --wallpaper=0 --hud=0

#    （`--shot=shots/x.png` 要求 shots/ **已经存在**：写盘的路径不会建目录，见 G34）

# 4) 探针（`tests/` 下现写的 `probe_*.gd`）：headless 探针把结果 dump 成文件再比（写 `user://`），
#    写完即删；判据与手法见本文「验证」一节。
#    **注意**：引擎是 GUI 子系统的程序（编辑器版），`print()` 的 stdout 进不了管道，
#    只进得了 `> 文件 2>&1` 的重定向；探针别依赖它，把结果 dump 成文件（写 `user://`）再比。

# 5) 跑之前/之后一定要杀干净：`powershell -File tools/xuankill.ps1`
#    （它按 `*godot*` 通杀：直接跑编辑器版时一个进程就是真身，
#      旧的控制台壳 `godot_console.exe` 会拉子进程，两种都杀得干净）
```

### 三条硬约束（违反必然白干）

1. **不允许 `SWP_FRAMECHANGED`** 出现在重挂父窗口的调用里（V1），否则 Vulkan surface 永久失效、画面永远不出。
2. **壁纸层是 Progman *内部*的 WorkerW**，不是顶层窗口（W2），选错会"挂载成功但全黑"。
3. **改目录后必须删 `.godot/` 再 `--import`**，否则路径缓存会把报错指向不存在的文件。

## 调试开关与热键

### 命令行参数（`--` 之后为用户参数）

| 参数 | 默认 | 说明 |
|---|---|---|
| `--wallpaper=0\|1` | 1（截图时自动 0） | 是否重挂到桌面壁纸层 |
| `--hud=0\|1` | 1 | 是否建 HUD 窗口 |
| `--background=<id>` | `sky` | 开哪个背景（`aquarium` / `sky`），也是唯一能在无人干预下截到非默认背景的办法。默认值写在 `Backgrounds.DEFAULT`，**不是**注册表第一条——`换桌面` 的子菜单仍按注册表顺序列 `水族箱 / 星空` |
| `--fps=<n>` | 60 | `Engine.max_fps` |
| `--interval=<ms>` | 1000 | 指标采样周期 |
| `--shot=<png>` / `--shot-frames=<n>` / `--shot-target=main\|hud\|menu` | — | 渲染 N 帧后存图退出（开发用）；`hud` 存 HUD 窗、`menu` 存菜单窗 |
| `--menu=0\|1` | 0 | 开机就展开菜单面板（出图用） |
| `--exit-after=<秒>` | — | 定时退出 |
| `--no-activate=0\|1` | 1 | HUD 窗口是否加 `WS_EX_NOACTIVATE` |
| `--desktop-screen=<n>` | 0 | **3D 桌面放哪块屏**（0 = 主屏），发的就是 `菜单` → `显示器` 那一行发的同一条命令（`screen <n>`）。多屏时才在菜单里出现（单屏时那一行整行不画） |
| `--sky-time=<unix\|ISO>` | 实时 | **星空专有**：天空的时刻（**按 UTC 写**，见 G32），出图复现用 |
| `--sky-rate=<倍>` | 1 | 天空时间流速（1 = 实时；0 = 冻结） |
| `--sky-view=<方位>,<高度>` | `180,45` | 相机朝向（罗盘方位角 + 地平高度），出图复现用。默认即 `CameraRig.OPENING_ALTITUDE` |
| `--sky-fov=<度>` | 100 | 视场（12–110°，与滚轮缩放同一档位），出图量测用。默认即 `CameraRig.OPENING_FOV`（整片天空入画） |
| `--sky-boundaries=0\|1` | 0 | **星空专有**：是否画 IAU 星座边界（`data/constbnd.dat`，最暗的一层细带）。默认不画——它把星空割成一块块，用户要的是星座图线本身 |

> 后五个由星空背景自己从同一命令行读（`shell/background.gd` 把 `Args` 注入每个背景，见「背景接口」）。

### 热键（`host.exe` 轮询 `GetAsyncKeyState`）

| 键 | 动作 |
|---|---|
| `Ctrl+Alt+H` | **显隐 3D 桌面**（壁纸窗口本身；事件名 `toggle_desktop`，由 shell 决定）。原来是"隐显 HUD" |
| `Ctrl+Alt+T` | HUD 鼠标穿透（锁定/解锁） |
| `Ctrl+Alt+Q` | 退出 |
| 待定 | `Ctrl+Alt+B` 切换背景（现用右上角 `菜单` 即可；见 `计划.md` 的待定） |

---

## 架构：桌面壳 + 可换背景

### 背景接口（加背景 = 加一个目录 + 注册表一条）

```gdscript

# shell/background.gd
class_name Background extends Node3D

func id() -> String                    # "aquarium" / "sky"
func display_name() -> String          # 中文名，进 HUD 下拉框
func build(host: Node) -> void         # 建 3D 世界（可 await）
func teardown() -> void                # 释放
func build_hud() -> Control            # 本背景的 HUD 内容（每次切换新建，避免状态残留）
func hud_size() -> Vector2i            # 水族箱 280×280；星空罗盘更大
func render_policy() -> int            # CONTINUOUS / ON_DEMAND
func vignette_shader() -> Shader       # 各自的收尾色调
func menu_switches() -> Array          # 可选：右上角 菜单 里自己的开关行（星空的 星座，默认空）
func set_menu_switch(id, on) -> void   # 可选：那个开关被按下（默认空实现）
```

```gdscript

# shell/backgrounds.gd —— 注册表
const DEFAULT := "sky"                 # 开机开哪个（与下面 ENTRIES 的顺序无关）
const ENTRIES := {
	"aquarium": {"script": preload("res://backgrounds/aquarium/aquarium.gd"), "name": "水族箱"},
	"sky":      {"script": preload("res://backgrounds/sky/sky.gd"),           "name": "星空"},
}                                      # 顺序 = 换桌面子菜单的顺序
```

### 目录结构

```
E:/xuandesk/                        ← 根目录
  project.godot  run.bat  run_debug.bat  icon.svg
  native/       host.c  build.cmd  build.sh       ← 壁纸壳，唯一原生件
  bin/          host.exe
  shell/        main.tscn main.gd        引导：窗口 + 背景注册表 + 切换 + 截图钩子
                background.gd            背景接口
                backgrounds.gd           注册表
                wallpaper_window.gd      壁纸窗口设置（无边框/置顶/尺寸）
                hud_window.gd            HUD 窗壳：拖动 / 穿透 / 退出
                hud_menu.gd              右上角菜单窗口：换桌面（左侧子菜单）/ 背景开关 / 穿透 / 桌面 / 显示器 / 退出
                metrics.gd               指标客户端（host 进程 + 回环 TCP）
                args.gd  shots.gd
  shared/ui/    中文字体加载（Fonts）、通用控件、主题
  backgrounds/
    aquarium/   aquarium.gd fish_school.gd mesh_factory.gd hud.gd shaders/
    sky/        sky.gd            舞台门：天球 + 时钟 + 相机 + 各层的建与接线
                astro.gd          JD/GMST/LST/altaz/黄赤/岁差/ΔT/太阳/月亮
                observer.gd timecore.gd camera_rig.gd
                starcat.gd starfield.gd constellations.gd sky_lines.gd sky_labels.gd
                precession.gd lunar_terms.gd
                ecliptic.gd mansions.gd planets.gd vsop87.gd  ← 黄道 / 廿八宿 / 七行星 / 木土级数
                sun.gd moon.gd    ← 太阳 / 月球（盘面 ×3 + 白道 + 「月」名）
                branches.gd ganzhi.gd lunar.gd qimen.gd liuren.gd  ← 术数层（排盘算法 + 农历/道历）
                sky_branches.gd                               ← 地平线上下的地支环 + 八方向
                hud_compass.gd hud_timebar.gd                 ← 罗盘与时间栏
                shaders/          dome star line sun moon
                data/             catalog.txt constbnd.dat bound_20.dat vsop87b.dat SOURCES.md
  shots/        出图（放 `.gdignore`，不进 importer）
```

`tools/` 是 PS 脚本（窗口几何 / 逐屏截屏 / 最小化后截屏 / PostMessage 点击 / 杀进程 / 显示器列表）；
`tests/` 里的探针是"现写、跑完即删"的一次性脚本（判据与手法见「验证」）。**引擎不进 `tools/`**（用户要求）：
用装好的编辑器版，路径见「环境与工具链」；`tools/godot.exe`、`tools/godot_console.exe` 是同一版引擎的旧副本，已不再被任何脚本引用。

### 切换流程

```
switch_to(id):
  if id == current: return
  old.teardown(); await old.tree_exited        # 显式释放，避免残留 GPU 资源
  new.build(self); add_child(new)
  hud_slot.replace(new.build_hud())
  hud_window.size = new.hud_size()
  apply new.vignette_shader()
  renderer.set_policy(new.render_policy())
  用 vignette 做 ~200ms 淡入淡出盖住空白帧
```

### HUD 分层

```
HudWindow (shell：Window 壳，无工具条)
└── content_slot : Control                        ← 背景自带，切换时整体替换
HudMenu (shell：右上角菜单窗口，独立 OS 窗口)
└── 菜单面板：换桌面（背景表 = 面板**左侧**的子菜单） / 背景自己的开关 / 穿透 / 桌面 / 显示器 / 退出
      水族箱 → CPU/内存/显卡/显存/温度/网络/帧率 + 折线（280×280，无时钟列）
      星空   → 罗盘（四角：↙/↘ 转向 + 时辰±；盘外视角弧；奇门八分盘）
             + 时间栏（三元九运·道历日期 / 四柱·节气三元·阴阳局 + 现在）
```

`[桌面]` 不是"隐藏 HUD"（那个功能去掉了）：它 **显隐 3D 桌面本身**（壁纸窗口），
因为壁纸层是唯一会被系统自己的壁纸盖掉的东西，也是唯一"藏起来再放出来"能逼它重画一帧的东西。

壳的钮与背景内容**不在一个窗口里**：菜单是壳自己的 OS 窗口，所以 G13（`z_index` 管画）与 G28（树序管点）那对坑——
它们讲的都是旧的工具条——不再可能出现。

指标流**永远开启**（host.exe 同时负责壁纸挂载与热键）；星空 HUD 不消费它即可，成本 1 Hz 可忽略。

**指标流协议**（`host.exe` → Godot，127.0.0.1 回环 TCP，换行分隔 JSON，默认 1 Hz）：

```json
{"seq":12,"cpu":29.4,"mem_used":33285996544,"mem_total":68327845888,
 "gpu":44,"vram_used":6144,"vram_total":8188,"gpu_temp":63,
 "net_rx":134000,"net_tx":110000,"up":245,"wall":"ok","ev":["toggle_desktop"]}
```

| 字段 | 含义 |
|---|---|
| `cpu` | 全核占用 %（`GetSystemTimes` 差值） |
| `mem_used/mem_total` | 字节（`GlobalMemoryStatusEx`） |
| `gpu/vram_used/vram_total/gpu_temp` | NVML；**无 `nvml.dll` 时 `gpu=-1`、`vram_total=0`** |
| `net_rx/net_tx` | 字节/秒（`GetIfTable2` 差值，排除回环） |
| `up` | host 运行秒数 |
| `wall` | 壁纸状态：`ok` / `off` / `waiting` / `no-worker` / `hidden`（含"用户按桌面钮藏起来的"）/ `failed` |
| `screens` / `screen` | 宿主枚举到的显示器列表（主屏恒 0 号，其余按 x 排序）与当前选中的那块 —— `菜单` 的 `显示器` 那一行读它 |
| `ev` | 事件数组：`toggle_desktop` / `toggle_clickthrough` / `quit`（由热键产生） |

**反向通道**（Godot → host，同一 socket 的裸文本行）：`quit`（退出前）、**`wall 0|1`**（显隐 3D 桌面）与
**`screen <n>`**（把壁纸窗口搬到第 n 块屏）。三者都走 `MetricsClient.send_command()`，host 只在 `--wallpaper=1` 时执行——
`--wallpaper=0` 时那个窗口只是普通窗口。

TCP 角色：**Godot 是服务端**（bind 127.0.0.1:0 取临时端口），host 是客户端（带重试）。
host 在 socket 对端消失时自退，因此**永远不会比它的客户端活得久**。

---

## 背景一：水族箱

- `aquarium.gd` 程序化建场：水箱 9.0×3.4×5.0，相机在水箱内（FOV 66）缓慢漂移，`_process` 驱动 boids。
- 沙床（噪声丘 + 焦散）、石壁背景、礁石 ×10、水草 2 组 MultiMesh（约 600 叶）、水面（Gerstner 波 + 水下菲涅尔）、玻璃 4 面（掠射角反射而非透出黑房）、框架 + 灯带、气泡 + 海雪 GPUParticles3D。
- 鱼 3 种 × MultiMesh：程序化网格（lathe 体 + 尾/背/臀/胸鳍 + 眼），`fish_school.gd` boids（聚/散/对齐 + 边界 + 障碍规避）。
- 关键参数：水下体积雾、ACES、`tonemap_white=4.8`、`ambient 0.40`、`ssao_intensity=1.0`；焦散 `caustic_scale` 沙 2.2 / 石 2.0 / 壁 1.5（**尺度必须匹配场景尺寸**，用 0.3 时整屏一片死 flat）。
- 渲染策略 `CONTINUOUS`（鱼一直在游），所以它**不会**踩到 G36 那类"窗口被搬动后不再画"的坑——也因此**不能用它去验证**只在 `ON_DEMAND` 上才出现的问题。

---

## 背景二：星野（3D 星空）

### 复用清单

**复用本工程（壳）**：`host.exe` 壁纸挂载与热键、`hud_window.gd` 窗壳、`metrics.gd`、`args.gd`、`shots.gd`、`run.bat`、`tools/*`。

**复用 `E:/lingwang/Scenes/Features/QimenSLG/compass/`**：

| 资产 | 用途 |
|---|---|
| `compass_line.gdshader` | **屏幕空间恒定 1px 发丝线**（`fwidth` 距离场裁线宽，缩放不变粗不断线）→ 环界圆/分格线/天球坐标网格 |
| `compass_3d.gd` 环层系统 | 环带 ArrayMesh + 显式 `render_priority` 分层（半透不写深度，**必须显式定序**）+ `Label3D` 平铺盘面、字头朝圆心、`pixel_size=0.15` 高分辨率字模 |
| `moon_lit_polygon()` | 月相亮面几何（外缘半圆 + 终结线半椭圆），亮侧朝日 |
| 换字飞转 | 同位不动 / 相邻同心转 / 跨位直线飞 + `anim_started|finished` 供按需渲染切换（**尚未移植**，见 `计划.md`） |
| `compass_view.gd` | **HUD 交互范式**：`SubViewportContainer + SubViewport + 正交相机`、时间栏、拖动/滚轮/双指捏合、按需渲染（`UPDATE_ONCE` ↔ `WHEN_VISIBLE`） |
| `compass_data.gd` 时间基元 | `clock/now/display/days_in_month/shift_shichen|day|month|year`、`julian_day()`、`moon_elongation_deg()`、`phase_name()` |
| `CalendarUtil.get_ganzhi_info()` | 干支四柱 + 节气 + 农历日 |
| 配色 | `COL_DISC` 深蓝墨 / `BAND_COLORS` 半透蓝 / `COL_LINE` 浅蓝 / 金 / 青 |

> **必须重做**：lingwang 的天文模型是**盘面语义不是天象**——`sun_angle_at = (时−12)·15°` 是平太阳时角、与日期无关，`sun_angle_raw` 还把日期整圈取模抹掉。星空必须换真模型（见「天文算法」），否则星座位置全错。

### 天文算法（全部本地计算，无网络）

```
JD       = julian_day(y,m,d,h,min)                        # 复用 lingwang
T        = (JD − 2451545.0) / 36525
GMST(°)  = 280.46061837 + 360.98564736629·(JD−2451545) + 0.000387933·T² − T³/38710000
LST(°)   = GMST + λ_east
H        = LST − RA
sin h    = sinφ·sinδ + cosφ·cosδ·cosH
A        = atan2(−cosδ·sinH, sinδ·cosφ − cosδ·sinφ·cosH)   # 自北起，向东为正
ε        = 23.4392911 − 0.0130042·T − 1.64e−7·T² + 5.04e−7·T³
太阳 λ    = L0 + C                       (Meeus 25)
月亮      = Meeus 47 主项
行星      = JPL 近似开普勒根数 → 日心黄道 → 减地球 → 光行时迭代 1 次 → 地心赤道
           （**木星/土星例外**：这两行改用 VSOP87B 级数，见下「数据源」——直线速率的根数跟不上 5:2 共振）
岁差      = IAU 1976/2006 三欧拉角 → 天球节点一次旋转
蒙气差 R  = 1.02 / tan(h + 10.3/(h+5.11))  角分 (Bennett)   # 只用于黄道/地平的口径换算
月相      = fposmod(λ_moon − λ_sun, 360°)
```

**天球做成一个可旋转 `Node3D`（`SkyRoot`）**：恒星/星座/银河/宿度全部静止于天球，
时间变化只需 `basis = R_precess(T) · R_lst(LST) · R_lat(φ)` **一次旋转**，不逐星重算。
日月行星挂 `SkyRoot` 兄弟节点，按当日赤道坐标摆位，仅时间变更时重算。

### 数据源与许可

| 数据 | 源 | 许可（已核对） |
|---|---|---|
| 恒星 | **Yale BSC5** `cdsarc…/V/50/catalog.gz`（9110 颗 ≤6.5 等，定宽文本） | 公有领域 ✅ |
| 恒星/连线/边界（备选 JSON） | `d3-celestial/data/{stars.6,constellations.lines,constellations.bounds}.json` | 仓库 LICENSE = **BSD-3-Clause** ✅；但上游 README **未声明数据溯源** ⚠ |
| 中文名 | 自建 `data/zh_names.json`（88 星座 + ~120 亮星 + 28 宿） | 自撰 ✅ |
| 行星历表 | JPL SSD "Approximate Positions of the Planets" | NASA 公有领域 ✅ |
| 木星/土星历表 | **VSOP87B** `cdsarc…/VI/81/VSOP87B.{jup,sat}`（截断到 A ≥ 1e-6 rad → 40 KB，见 `backgrounds/sky/data/SOURCES.md`） | 公开天文数据（Bureau des Longitudes / IMCCE） ✅ |
| 太阳/月亮 | Meeus 第 25/47 章，自写实现 | 公式无版权 ✅ |

> **红线**：d3-celestial 的星座连线/边界在确认数据溯源前**只用做对照、不进仓库**；默认路径是 BSC5 + 自建连线。
> 落地时在 `data/SOURCES.md` 记「URL + 许可 + 获取日期」。星表目录放 `.gdignore`（同 G12）。
> `constellations.gd` 的连线就是按这条红线**自己重排**的（形状照传统图形，对照用的那份 JSON **只读不存**），
> 仓库里落下的仍然只是"拜耳字母/弗氏号 → 拜耳字母/弗氏号"的对照表，没有坐标、没有第三方文件（见 G31）。

### 星点、记号与取舍

**星点**：星等 → 尺寸/亮度是一根**刻意压缩**的感知斜坡（`star_size = lerp(0.8, 2.8, norm^0.55)`、
`star_brightness = 0.06 + 1.15·norm^1.6`、`norm = (6.5−V)/8`），**不是** Pogson 的能量比——
线性的真实比值会让人眼觉得"只有几颗星"；`V>6.5` 的钳到地板（与 6.5 等一样大一样亮）。颜色取 B−V。
**银河**是银道坐标里的一条高斯带（带内/带外 + 银心方向的凸起都由 shader 参数定），不是一张贴图。

**昼夜**：白天**不关星**——`DAY_STAR_FLOOR = 0.65`（星点/图线/黄道），银河单独 `DAY_BAND_FLOOR = 0.10`
（弥散带留 0.65 会变成一堵发光的墙）。尺度：2° 的地平淡出（mass extinction）代替大气消光，**不做**蒙气差，
那两样在这一层的收益远小于它们引入的分歧（「天文算法」里那条 Bennett 公式只用于口径换算）。

**月球**：盘面是**一颗被太阳照亮的球**（`moon.gd` + `moon.gdshader`，相位是真几何不是画的月牙），
但半径**放大 3 倍**（`SkyMoon.MAGNIFY`）：真视半径 0.26° 在默认 100° 画幅里只有 **2.7 px 半径**，是一颗点，
而月球是天上唯一"有脸"的东西。**代价**：日食时它多挡太阳。
**白道（月球自己的轨道）**：按**真黄经**取 120 点走完一圈（每点约 3 次 `Astro.moon_state()`，一次约 50 ms，
**每天翻日重走一次**，与行星尾迹同一节奏），折进星表帧后是一条比黄道高/低 **5.1°** 的银灰细带——
于是黄道与白道在月旁分开看得见。轨道挂 `SkyRoot` 而不是月球节点下：月球自身被缩放到盘面，
挂成子节点会连盘面缩放一起继承。它随昼夜变暗、随视场缩放，**盘面不随昼夜变**（它是天体不是墨线）。

**标签**：**五类**都画在同一个 `SkyLabels` 上，2D 投影、**恒定屏显字号**、只投 FOV 内且地平以上的对象、重叠即丢。
摆位优先级 = **春分点 / 北极星（各一个，丢了就没了）→ 月（一个球加一个名字，抬升按盘面半径算，盘面放大后名字才不会压在月脸上）
→ 行星名、宿名 → 88 个星座名**（稀的先占位，密的让路）；
`星座` 开关只关最后一层。

**三个记号**：
- **北极星名字**：α UMi 从同一份 BSC5 查得（`find("α","UMi")`），名字写在它自己那个点上方，不另存坐标。
- **春分点**：λ=0 上一个 **1.1° 的小圆环**（12 段）加 `春分点` 名字——岁差让它是天球上的一个动点，画出来才看得见"分划是跟着它走的"。
- **天顶虚十字**：4 条臂 ×3 段虚线的空心十字，锁在 **world 的 +Y**（不随天球转），是"天顶在哪"的唯一读数。

**滑行**：转向钮（`↙/↘` 与四个方位三角）走 `camera_rig.gd` 的 `1 − e^(−9·delta)`（沿短弧、连按累加、差 ≤0.02° 吸附）；
时辰± 走 `timecore.gd` 的 `1 − e^(−7·delta)`（差 ≤1 s 吸附，**每帧发 `changed`**，所以整片星空看得见在转）。
`face()` 与 `set_time_unix()`（拖动、`--sky-view`、`现在`）是"立刻到位"那条路。

### HUD 罗盘规格（自内向外）

**盘面 = 两张按当前时刻排的盘**（奇门时家 / 大六壬）+ 中心的太极。环是数据，不是算法：
`QiMen.pan()` / `LiuRen.pan()` 给什么就画什么，时辰一变重排一次。盘径 276，盘心在 (150,150)。

| 层 | 内容 | 分度 |
|---|---|---|
| 盘心 | 小**太极**（半径 17.3，48 段拼的）——原来的方位读数与八风名已去掉 | — |
| 环一 | **后天八卦的卦符**（坎北、离南…），半径 **26**：奇门八宫就落在这八个方位上。**不写卦名、不写洛书数**——洛书宫号与卦的配对写在 `SkyCompassHud.BAGUA` 里（数据与质检都用），只是盘上不显示；**三根爻按盘心径向排**（卦是随盘转的，不像 神/星/门 那样正写） | 8 × 45° |
| **八分盘**（底色） | **盘被八个宫分成八扇、其中四扇微微提亮，提亮的那半就是内盘**（用户要求：洛书 `8341` 宫为阳宫、`2967` 为阴宫，"奇门阳局阳宫为内盘"，内盘加个微亮的底色）。扇区 = 盘角 45° 一格、以该宫方位为心，环带 **r 34…90**（卦环 26 之外、驿马 92 之内，正好垫在八宫块底下）；两档底色都是盘自己的青（`C_PANEL_INNER` α 0.13 / `C_PANEL_OUTER` α 0.045），**阳遁亮 8/3/4/1、阴遁亮 2/9/6/7**（`QiMen.is_inner()`）——一个节把局数翻过来，盘上亮的半边就换到对面去。八扇同宽同半径、接缝处不叠画；**没排到盘时不画** | 8 × 45° |
| **八宫块** | **奇门 三行一块**：八个宫各在**自己那个方位上**写**三行** —— `神` / `星 + 天盘干` / `门 + 地盘干`（自上而下），**每个字正写、不随盘转**；值符神/值符星/值使门**只染名**金。**"门在里、星在中、神在外"三个半径环已取消**：锚点 = 该宫方位、半径 **64**，三行相距 **14 px**，整块占 r **43…85**。旬空的宫在神名**左边**挂一个 `〇`——**挂在外边、不参与居中**，所以那块的三行标签仍然对齐 | 8 × 45° |
| **大六壬环** | **大六壬 天盘支 + 遁干 + 贵人**（空亡位为 〇）——**唯一还按环排的盘**，标签沿环的切向排、字头朝外。盘下方那 5 组（盘角 120°–240°）**翻 180° 正着写**（用户："下方5组字反着的，改成正过来方便读"）；盘正左/正右两宫（盘角 270°=东、90°=西）改成一列**竖排正字 神 / 干 / 支**（从上到下，用户要求），行距一 em——那两处本来就占 13×39 px 的竖框，字正过来后位置不动 | 12 × 30° |
| **刻度外** | **太阳**：随它是白天/黑夜的圆点 + 细圈（地平线下压到 30% 亮度）；**七行星**：与太阳**同一条道**（r 134）上各自一个实心小圆，颜色是行星自己的（水火金木土取五行色、天海取冷色），**大小按视星等的同一根斜坡**（`SkyPlanets.mark_norm` → 半径 1.3…2.6 px），地平线下压到 30%。它们和日月一样是"天空当下的位置"，不是盘上的环 | 方位 |
| **刻度内** | **月亮**：细月牙（同上，地平线下压暗） | 方位 |
| 环外 | **时钟式度刻**：**12 大**（每 30° —— 正对十二地支，也是大六壬环扇区的口径）× **每大 5 小**（小刻 6°），共 **60** 根；大刻 10 px、小刻 5 px 长，**"子"那根青色唯一标记**再长 5 px、加粗到 1.8 px——盘固定之后，这一根是探针唯一的方位读数（G25） | 60/12 |
| **视角弧** | **盘外那一圈弧 = 当前 3D 场景的相机视向**：半径 r=143（盘外、度刻之外，落在 12 px 的窗边里）、张角 **40°**、3 px 宽，圆心角正中 = `相机方位 − 180°`——点北（方位 0）时弧形正中转到**盘底**，点南时到盘顶。它替掉了原来盘顶那个三角（旧"基准指针"）：盘不再转，所以"当前看哪"必须由会动的东西来说。张角是**记号自己的宽度、不是视场**（rig 的是竖直 fov，盘不知道壁纸窗口什么形状）。视角正好压在某个方位上时弧的中间被那个方位自己的三角挡掉，弧的两端仍看得出转向 | 方位 |
| **方位三角** | **盘上四个方位三角 = 原来 `北/东/南/西` 那一行按钮**：上=南、下=北、左=东、右=西（上南下北），点在盘外、尖朝外，各自一个 **24×24 的真 Button**（`HudWindow._control_at` 靠这个把它和拖动区分开），点一下走 `CameraRig.face_cardinal()`——与旧那一行同一根接线，只是视角弧滑到那个方位上去。三角颜色照旧：东淡绿 / 北红 / 西白 / 南（用户没给色）取盘自己的青 | 4 |
| **时针 / 分针 / 秒针** | 都从太极边缘（`TAIJI_R+3` = 20.3）向外画：**时针短粗到 r 74、分针到 r 98、秒针细长到 r 124**（秒针尖端正落在 60 小刻的里端；它的里段要跨过八宫块和两条环，所以里段淡、外段实）。角度都 = **从顶部顺时针**：时 `(时+分/60)/12`、分 `(分+秒/60)/60`、秒 `秒/60` 圈——盘的**地支环就是钟面**（午在顶 = 正午/子夜，一根大刻 = 一小时），60 小刻同时是分格与秒格。**三针读的是观测者自己的墙上时钟，不是天钟**（`SkyCompassHud.wall_clock()` → `Time.get_unix_time_from_system() + utc_offset`）：按一次 时辰± 天钟会在一秒里走两个小时，跟着它读的针要转 120 圈；针靠自己的 `_process` 每秒要一帧来走 | 6°/秒、6°/分、30°/时 |
| **驿马 `马`** | 画在**它自己的一圈** r **92**（`R_HORSE`，落在两块之间的空档）、驿马支的方位。**正着写**（不随盘转），并且**每过一个天空秒横着晃一下**（切向 ±3 px、约 0.3 s 衰减）——盘上唯一写"排盘在往哪走"的记号 | 方位 |
| **廿八宿刻度** | **二十八宿的宿度**：每宿在自己**距星当下的方位**上刻一根短刻，落在**度刻那一圈**里（r 119…127），靠**颜色**（暖琥珀 `C_MANSION` vs 钟表刻的蓝灰）和长度区分——盘上因此有三套刻度：60 小刻、12 大刻、28 宿刻（不等分，赤经跨度）。赤道是条大圆，任一瞬刻**正好一半在地平线下**，那 14 根压到 30% 亮度 | 28 |
| 盘四角 | **盘的四个角各一颗 chip**：**左上 `↙` / 右上 `↘`** 是 左转/右转（各 ±15° = 一座山）——箭头朝"盘转的方向"（左上角朝左下 = 逆时针）。字体有 ↙ U+2199 / ↘ U+2198（`Font.has_char` 查过；◀ U+25C0 那一族全无），字号 16 + 1 px 同色描边。**左下 `时辰−` / 右下 `时辰+`** 是时间栏那两颗（坐标写在时间栏自己的坐标系里，所以是负的 y = -32） | — |

**卦符为什么是画的而不是字**：Unicode 有 ☰ U+2630…☷ U+2637，但本机系统字体（`Fonts.CANDIDATES` 里的微软雅黑等）
**一个都没有**（`FontFile.has_char()` 全 false，画出来是八个空框），所以 `hud_compass.gd` 用三根爻自己画
（阳爻一横、阴爻中间断开，位掩码写在 `BAGUA` 第三列）。

**盘固定 上南下北；"当前看哪"由盘外那圈视角弧说**。要动盘上的字或排法，先去问用户。

### 时间栏

盘下那条 40 px 的带子只有两行读数（基线 300+12 / 300+29，居中），加两颗 `时辰−/时辰+`（在盘的下两角，见「盘四角」）
和一个 `现在`：

```
三元九运 + 道历日期    九紫离火 道历四七二三年九月初一
四柱 + 节气三元 + 局    丙午 戊戌 丁巳 丁未 寒露中元 阴九局      [现在]
```

- 第一行 = `GanZhi.jiu_yun_name()` 给的那个运（**玄空星名**，一白坎水 … 九紫离火，随立春翻）+
  `Lunar.date()` 给的农历日期（**年用道历计**，道历 = 农历年 + 2697）。
- 第二行 = 四柱（年/月/日/时）+ 节气 + 三元 + 局：`QiMen.yuan_name()` / `ju_name()` 把 `QiMen.pan()["yuan"]` 与
  `["ju"]` 写成 `上元/中元/下元` 与 `阴九局` 这种（局数的符号就是阴阳遁）。两行的文本由 `SkyTimeBar.read_date()` /
  `read_chart()` 组，数据由 `SkyBackground._chart()` 用 `set_pillars()` / `set_lunar()` / `set_ju()` 交过去。
- `现在` 只占 x 244…288 那条竖带，**挂在留得出这条带的那一行末尾**：第一行最长 196 px（`闰冬月廿九` 那种日期，居中止于 x 248）
  会压到这条带，第二行（每个字段都是两三字，定宽 180 px）止于 x 240 —— 所以它挂第二行（时间栏 y 14…36 = 窗 y 314…336）。

### 盘外的两条地支环、星座边界与开关

> 盘外的**地平线上/下是两条地支环**（下=地盘十二支、上=大六壬天盘支，同贴一条交线，见 `sky_branches.gd`）——
> 它是壁纸上的地平方位尺，不是 HUD。天盘那一侧是**两行两字的块**：`干支`（遁干 + 天盘支，贴交线）在下、
> `贵人`（天将的**双字名**）在上，两块同以该方位居中。**地盘那一侧再往下一行是八方向**（`北/东北/…/西北`，
> 45° 一根、字号 12、暖色更淡）：地支是时辰刻度（30°），方向只回答"这一圈朝哪边"，两行交错。

> **星座边界**（`SkyLines` 的 IAU 层，`data/constbnd.dat`）是星空里除星座图线之外的那些细线，**默认不画**
> （`--sky-boundaries=1` 才画）：它把天空割成一块块，用户要的是星座本身。

> **星座图线与中文名**是星空自己的一个开关，挂在右上角 `菜单` 里（那一行写 `星座`）：行由**背景**交给壳——
> `Background.menu_switches()` / `set_menu_switch()` 这对可选钩子（见 `计划.md` 的背景路线），
> 所以壳仍然不认识任何具体背景，水族箱的菜单里就没有这一行。开关只关它自己说的那件事（G35）。

---

## 性能与静默

| 场景 | 策略 |
|---|---|
| 水族箱 | 连续渲染（鱼在游） |
| 星空 · 静态几何 | 恒星/星座/银河/网格静态，时间变化只改 `SkyRoot.basis` |
| 星空 · 日月行星 | 仅时间步进时重算（10 次多项式求值，微秒级）；七行星每步重算位置（7 × 3 次开普勒解 + 光行时，微秒级），本体只改 `Transform3D` 与两个亮度 uniform，**从不重建网格** |
| 星空 · 行星尾迹 | 每个**整数日**重算一次（7 × 49 次星历求值）；木星/土星走 VSOP87 级数，比开普勒那两行贵一个量级，仍在"一天一次"的量级。取这 49 个点的**时刻**也归它自己，其余时间静止 |
| 星空 · 月球轨道 | 同样**每个整数日**重走一圈（120 × 约 3 次 `moon_state()` ≈ 50 ms，见 `计划.md` A32）；交点每天退行 0.05°，一天一次足够 |
| 星空 · 二十八宿 | 赤道环 + 宿度刻 + 28 个宿名：**与恒星同在 SkyRoot 上的静态几何**（宿是 J2000 赤经分划，不随时间步变），一次建好再不动 |
| 星空 · 转向与时辰步进 | 只在**按下转盘钮或 时辰±的那一两秒**里逐帧重绘（`moved` / `changed` → `request_redraw()`，ON_DEMAND 下等于"连续画一秒再回静默"）；`moved` 与 `changed` 不再发就是回到静默的判据 |
| 渲染策略 | 归背景所有：`Background.render_policy()` → `CONTINUOUS`（逐帧）或 `ON_DEMAND`（画一帧后停画，`RenderingServer.viewport_set_update_mode(...VIEWPORT_UPDATE_ONCE)`；时间/视角变化时背景自己 `request_redraw()`）。**代价与验收数字见 `计划.md` 的 A14**；量之前先看整卡与显存，别把"别的进程占着卡"记到本工程头上 |
| 标签 | 只投影 FOV 内且地平以上的对象；五类同在一个 `SkyLabels` 上，按「星点、记号与取舍」那节的优先级摆位，`星座` 开关只关最密的那一层 |

**谁会要一帧**：`ON_DEMAND` 的背景只在收得到"要重画"的理由时才画——时间（`TimeCore.changed`）、视角（`CameraRig.moved`）、
HUD 的按钮、以及**宿主搬动/改尺寸窗口之后**（G36：`_on_screen_selected` / `_on_host_online` 里主动 `request_redraw()`）。
漏掉最后一条的症状是"桌面换屏之后整块不见了"，而且**只在 ON_DEMAND 的背景上**出现。

---

## 踩过的坑（不要重踩）

### Windows 桌面壁纸层（Win11 25H2 · build 26200）

| # | 症状 | 根因 | 处置 |
|---|---|---|---|
| W1 | `SetParent` 成功、`wall=ok`，但桌面纹丝不动 | 挂到了一个**隐藏的** WorkerW。本机 19 个顶层 WorkerW，**全部不可见** | 必须同时要求 `IsWindowVisible(worker)` |
| W2 | 顶层找不到可用的 WorkerW | 本机 `0x052C` **不产生可见的顶层 WorkerW**。真正的壁纸层是 **Progman 的子窗口 WorkerW**（与 `SHELLDLL_DefView` 同级，覆盖 5120×1440） | 先 `FindWindowExA(progman, NULL, "WorkerW", NULL)` 找 Progman 内的 WorkerW；找不到再退回顶层搜索 |
| W3 | 挂进 Progman 后仍然看不到 | 直接把窗口挂成 Progman 的子窗口并 `HWND_BOTTOM` → 被 DefView/Progman 自身绘制盖住 | **必须挂进那个 WorkerW**，不是 Progman |
| W4 | `FindWindowA("Progman", NULL)` 返回 0，但 `EnumWindows` 能枚举到 | `FindWindow` 在本机不可靠 | 统一用 `EnumWindows` + `GetClassNameA` 找窗口 |
| W5 | 重挂后 `GetParent` 返回 0 | 跨进程 `SetParent` 要求目标窗口带 `WS_CHILD`；`WS_POPUP` 窗口会被静默忽略 | 先把 `WS_POPUP` 翻成 `WS_CHILD`，再 `SetParent` |
| W6 | 会话锁屏/桌面重建后进程消失 | 子窗口被 shell 销毁 → Godot 收到 close → 退出 | 已加固：外来 `WM_CLOSE` **不退出**（只认 HUD 退出按钮 / `Ctrl+Alt+Q`）；host 每 5s 复检挂载 |
| W7 | 挂载成功、`check_wallpaper.ps1` = OK、`--shot` 出图正确，**屏幕截图上却只有系统壁纸照片** | 桌面自带的那张壁纸图由 **`SHELLDLL_DefView` 那一层**画，而我们的窗口按 A1 就在它**下面** —— "图标永远在最上"和"系统壁纸照片能盖住我们"是同一件事的两面 | 先排除自己的锅：拿**从没改过的另一个背景**跑同一流程，两者同样不可见 ⇒ 是桌面背景，不是代码。真要用就必须让系统别画那张图：**桌面背景设为纯色**（Lively / Wallpaper Engine 的标准前置条件）。注意 Windows **主题会轮换**壁纸图（`HKCU\Control Panel\Desktop\Wallpaper = …\Themes\TranscodedWallpaper`、`WallpaperStyle=10`），所以症状会"20 分钟前还好好的、现在就盖住了" |

**正确顺序**（`host.c::apply_wallpaper`）：
```
找 Progman(EnumWindows) → 找 Progman 内的可见 WorkerW（无 SHELLDLL_DefView 子窗口）
→ 窗口加 WS_CHILD（去掉 WS_POPUP）→ SetParent → SetWindowPos(HWND_BOTTOM, 无 SWP_FRAMECHANGED)
→ 回读 GetParent 的 class == WorkerW 且 IsWindowVisible 才算成功
```

**独立校验**：`tools/check_wallpaper.ps1` 会打印 `progman kids: DefView@index 0, our WorkerW@index 3`，
即壁纸层排在图标层**之后**（z 序更下）→ `OK`。

### Godot + Vulkan + 重挂父窗口

| # | 症状 | 根因 | 处置 |
|---|---|---|---|
| V1 | Godot 控制台刷屏 `ERROR: Couldn't get Vulkan surface capabilities (VkResult error -1000000000)` at `swap_chain_resize` | `-1000000000` = `VK_ERROR_SURFACE_LOST_KHR`。**`SWP_FRAMECHANGED` 会让窗口重建重定向表面，Godot 的 Vulkan surface 随之失效且永不恢复** | **绝不传 `SWP_FRAMECHANGED`**。只做 `WS_CHILD` 翻转 + `SetParent` + `SetWindowPos(HWND_BOTTOM, …)` |
| V2 | 画面永远不出，但进程正常、指标正常 | 同上：surface 丢了就不 present | 同上 |
| V3 | 重挂进 WorkerW 后**画面全空**（能透视看到用户原壁纸），但同一个窗口换另一个背景就正常；`--shot` 出图也正常 | 只含 `Environment`（`BG_SKY`/`BG_COLOR`）**没有几何**的场景在重挂后的窗口里不 present | 背景必须**有真实几何**：星空用内表面天球网格（`SkyRoot/Dome` + `dome.gdshader`）而不是 `BG_SKY` |

> 这条是本项目最贵的坑：挂了父窗口却什么都看不见，而所有 API 都返回"成功"。

### Godot 4.7 API 陷阱

| # | 症状/陷阱 | 处置 |
|---|---|---|
| G1 | `Invalid call. Nonexistent function 'poll' in base 'TCPServer'` | `TCPServer` 没有 `poll()`；用 `is_connection_available()` / `take_connection()`。`StreamPeerTCP` 才有 `poll()`/`get_status()`/`get_available_bytes()` |
| G2 | shader 里 `Unknown identifier: INSTANCE_CUSTOM`（fragment 阶段） | `INSTANCE_CUSTOM` **只在 vertex 阶段可用**；要传到 fragment 必须自己声明 `varying vec4 inst` 并在 vertex 里赋值 |
| G3 | `Condition "!first && !(format & Mesh::ARRAY_FORMAT_NORMAL)" is true` | `SurfaceTool` 的顶点格式在第一个顶点处锁定。要么**每个顶点都** `set_normal`，要么**都不设**再 `generate_normals()`；混用必炸 |
| G4 | 顶点色明明是深蓝，渲染出来一片白 | **shader 里的顶点色是线性空间**。调色板按 sRGB 写 → 必须 `.srgb_to_linear()`（alpha 不受影响） |
| G5 | 换了着色器还是纯白 | `MultiMeshInstance3D` **必须显式给 `material_override`**，否则用默认白材质。顶点色一直是对的 |
| G6 | `Node not inside tree. Use look_at_from_position() instead.` | 节点入树前不能 `look_at()`；用 `Basis.looking_at(dir, up)` 或先 `add_child` |
| G7 | 窗口标题对不上，host 找不到窗口 | ① `Window` 节点的 `title` 属性会覆盖 `DisplayServer.window_set_title()`；② Godot 在 debug 构建里会给标题追加 `" (DEBUG)"` | **按「进程 PID + 标题前缀」匹配**，不要比全等 |
| G8 | HUD 窗口 `IsWindowVisible = false`，屏幕上看不见 | Godot 可能创建 subwindow 而不置 `WS_VISIBLE` | host.exe 启动后一次性 `ShowWindow(SW_SHOWNOACTIVATE)`（只做一次，不然后续"隐藏"按钮会被顶回来） |
| G9 | 隐藏再显示 HUD 后置顶/穿透样式丢失 | Godot 隐藏 `Window` 节点会**销毁原生窗口**，再显示时是**新 HWND** | 不缓存 HWND；host 每 5s 复检并重新套样式 |
| G10 | 截图拿到的是上一帧/黑图 | 一定要 `await RenderingServer.frame_post_draw` 再 `get_texture().get_image()` | 已封装在 `--shot` 路径；主视口与 `Window` 的视口都可用 |
| G11 | 新克隆/新目录下报 `Could not find type "X"` | 全局类缓存 `.godot/global_script_class_cache.cfg` 只在导入时生成 | 跑一次 `--headless --path . --import` |
| G12 | `.godot/imported/` 里堆满运行时截图 | Godot 会导入 `res://` 下的 png | 给纯运行时目录放 `.gdignore`（`shots/.gdignore` 已在用） |
| G13 | HUD 工具条的菜单被内容盖住（半透明暗块，点得到但看不见） | Control 子节点**按树序绘制**：内容 `set_content()` 是后加的，画在工具条（先加的）之上 | 给工具条显式 `z_index = 1`（`shell/hud_window.gd`）。**这条随旧工具条一起退休**：菜单已搬进自己的 OS 窗口，见 G30 |
| G14 | 非激活窗口（`WS_EX_NOACTIVATE`）里 `OptionButton` 的原生弹窗**不出现** | Godot 的 popup 是独立 OS 窗口，依赖激活/焦点 | HUD 里**不要用原生弹窗**：菜单自绘在同一窗口内（`HudWindow._menu`），悬于 picker 上方 |
| G15 | `Window.render_target_update_mode` 报 "Invalid assignment ... on a base object of type 'Window'" | 该属性只在 **`SubViewport`** 上；根窗口/`Window` 不暴露 | 按需渲染用 `RenderingServer.viewport_set_update_mode(get_viewport().get_viewport_rid(), VIEWPORT_UPDATE_ONCE / _ALWAYS)`（见 `shell/main.gd::_apply_render_policy`） |
| G16 | **星点/银河之外的透明物完全不渲染**，但换成不透明材质就正常；`--shot` 出图、无任何报错 | 天球用了 `depth_draw_never` → 它被归入**透明队列**；透明物按 AABB 距离从远到近画，而天球的 AABB 以相机为中心（距离 0）→ **最后一个画**，把先前画的 `blend_add` 星点整片盖掉。不透明物因为写了深度，反而"穿过"了这层 | 不透明几何**不要**用 `depth_draw_never`（天球写深度即可：星点在 r=480、天球 r=500，深度天然正确）。排查手法：把可疑材质换成 `StandardMaterial3D` 对比 |
| G17 | `--headless` 下跑 `--script` 探针，`MultiMesh.get_instance_transform()` 读回全是 0 | headless 用 `RendererDummy`，`multimesh_instance_set_transform` 是空实现 | 需要读回顶点/实例数据的探针**不要**加 `--headless`（用真渲染器跑，脚本自己 `quit()`） |
| G18 | 星座边界（VI/49）：按 `bound_20.dat` 文件顺序连线 → 满屏竖条纹；按"等赤经/等赤纬分组" → 只剩 20% 的线；按"邻近重建" → 串到隔壁边界上（总长 6000–8800°，来回乱走） | ① J2000 文件按**赤经排序**；② 岁差把弧线从 1930 的等赤经/等赤纬网格上挪开，几何上再也分不出"同一条腿" | **拓扑用 `constbnd.dat`**（每星座的第一行是原点，其后按逆时针列出边界折点 = 显式拓扑）+ `Precession` 把折点从 B1875 岁差到 J2000。自证：岁差结果与 `bound_20.dat` 的 J2000 折点中位偏差 0.0000° |
| G19 | `--script` 探针"卡死"几分钟不动，也没有任何输出 | GDScript **解析错误**会让 `_init()` 根本没跑起来，`quit()` 自然永不执行 —— 看起来像死循环 | 探针一律配 `timeout`；看不到输出时**先看有没有 `SCRIPT ERROR: Parse Error`**，别急着找死循环 |
| G20 | `PlaneMesh` 建出来的"圆面"**完全不出现**，没有报错、没有警告，`--shot` 里也找不到 | `PlaneMesh` 默认 `orientation = FACE_Y`，即**水平**面片：拿它当"面向相机的圆盘"，四边形与视线共面 → 侧看一条线（面积~0） | 建面向相机的四边形必须显式 `mesh.orientation = PlaneMesh.FACE_Z`（或自己填 UV） |
| G21 | 缩放星空后星点变成一团团大光斑、星座细带变成宽带 | 星点四边形（0.8–2.8 世界单位）与细带（0.42/0.26）是**按固定视场 60° 建的天球几何**，视场一变，同样的世界尺寸在屏幕上的角径就变了 | 顶点着色器里以"该顶点所在天球半径方向"为不动点缩放：`vec3 base = normalize(VERTEX) * sphere_radius; VERTEX = base + (VERTEX - base) * size_scale;`，`sky.gd` 在相机 `moved` 时把 `size_scale = fov / CameraRig.BASE_FOV` 喂进去（亮度不变，只变尺寸） |
| G23 | HUD 圆盘上的标签**全挤在左上角**，字都在、位置全错；`draw_circle` 画在同一"半径"上却完全正确 | 把"极坐标 → 屏幕点"写成 `dir * R`（`dir` 是单位方向向量）。那样得到的是**以控件原点为圆心**的半径 R 上的点，不是以盘心为圆心的 | 一律 `CENTRE + dir * R`。**排查手法**：把同一个 `at` 再用 `draw_rect` 画一个 2×2 红点——红点和字一起跑偏，就说明错在坐标、不在文本绘制 |
| G24 | 探针"盘上缺一个刻"、"多出一个刻"，但图上看得好好的 | 角度跨 0°/360° 缝时**算术平均**是无意义的：`(359.9 + 0.1)/2 = 180` | 角度平均一律用**圆均值**（对单位向量求和再 `atan2`）。折线/方位/表盘角度都适用 |
| G25 | 只读"跑刻位置"的探针**在任意 15° 整数倍的方位上都通过**（0 与 180 的图都 pass），负对照也 pass | 24 个 **等距**的刻在 15° 旋转下不变（5° 环在 5° 下同理）——这组特征里根本没有"哪边朝上"的信息 | 盘卡要留**一个唯一标记**（本项目是"子/北"那根青色刻），探针读它而不是读等距环；并把"换个方位声明同一张图"作为**负对照**跑一遍，它必须 FAIL |
| G26 | 银河画成**一条烧到纯白的发丝线**外加几十像素的糊光；白天特别刺眼 | `milky_way(local_pos)` 传进去的是**顶点位置**（天球半径 500），而函数里 `asin(clamp(dot(dir, pole)))` 与 `pow(dot(dir, centre), 2.5)` 都假定 `dir` 是**单位向量**：前者把 `lat` 顶到 ±π/2 → `band` 塌成 0.07° 宽的发丝线；后者把 500 抬到 2.5 次方 = **5590** → `bulge` 爆掉，细线被 bloom 糊成一片白 | 传 `normalize(local_pos)`。**判据**：凡是"点积 + asin/pow"的向量函数，先归一再用 |
| G27 | 改完 `.gdshader` 画面**整体变黑**，但进程正常跑完、`--shot` 照样报 `err=0`、退出码 0 | Godot 的着色器编译错误**只往 stderr 打一行**，材质静默退化成 fallback（黑），整条流水线不受影响——和 G19（探针解析错误）同族："会报错，但不拦人" | 改 shader 后一律 `grep -i "shader error"`（典型如新加的 uniform 撞了 `fragment()` 里的局部变量：`Redefinition of 'night'`） |
| G28 | **`z_index` 只管画，不管点**：picker 的菜单明明画在内容之上，点它却触发**内容里同一位置的按钮**（用户报告："下拉菜单会优先触发时辰−"） | Godot 的鼠标拾取是**按树序**从最后一个子节点往回走（`gui_find_control_at_pos`），`z_index` 不参与 | 工具条在**树序上也要排在内容之后**（`move_child(_toolbar, -1)`）。**这条随旧工具条一起退休**：菜单搬到了自己的 OS 窗口（G30），窗口之间的拾取由系统决定 |
| G29 | `--shot` 的整条命令**跑完了、退出码 0、`err=0` 都没有**——就是没有图，也没有图那条打印；换哪个背景都一样 | 用户参数必须写在 **`--` 之后**：`OS.get_cmdline_user_args()` 在没有 `--` 时返回**空数组**，`Args.parse()` 拿到空字典 → `--shot` / `--sky-time` / `--background` 全部落空，应用照默认值跑，`_shot` 因此是 false、`_capture()` 根本不进。G19/G27 的同族：**不报错的失败** | 出图（或任何带参运行）一律 `"$G" --path . -- <参数…>`；`--script` 探针那条同理。**判据**：先让应用把 `OS.get_cmdline_user_args()` 打出来，别猜 |
| G30 | HUD 的**菜单窗口**一整套坑：面板点了没反应/看不见、点了"像在 HUD 底下" | ① **嵌套 Window 只画第一帧**：`Window` 套 `Window` 时子窗口首帧之后再不重绘（`--menu=1` 开机就展开能看见、之后任何变化都不上屏）→ 菜单必须是**壳自己的**窗口（与 HUD 平级），不是 HUD 的子节点；② **`unfocusable = true` 会连点击一起丢掉**：Godot 的 NO_FOCUS 文档自相矛盾（标志说"除鼠标点击外都忽略"，成员说"不能交互"）→ 非激活交给 host 的 `WS_EX_NOACTIVATE`；③ 两个 overlay 窗口的**标题前缀不能互相包含**（host 按前缀匹配，`XuanDesk.HUD` 会同时匹到 `XuanDesk.HUDMenu`）→ 菜单叫 `XuanDesk.Menu`；④ 两个都是 topmost 时**谁在前看谁最后升起**，Godot 重绘 HUD 会把面板埋掉 → host 把菜单 window 设成 HUD 的 **owned window**（被拥有者永远在拥有者之上）；⑤ 该窗口的视口按需重绘：不设的话它只画创建那一帧 | 菜单 = 壳的窗口 + `always_on_top` + host 的 `WS_EX_TOPMOST/TOOLWINDOW/NOACTIVATE` + `GWLP_HWNDPARENT=HUD` + 每次变化 `VIEWPORT_UPDATE_ONCE`（指针在窗口里时 `ALWAYS`，见 `shell/hud_menu.gd`）。**判据**：`--menu=1` 能看见而点击后看不见 ⇒ 先怀疑"嵌套窗口/视口不重绘"，别去调 z-order |
| G31 | 用户报告"**天龙座的连线都穿小熊座了，好多星座的连线都有交叉**"——但星点、星座名、每段线都在，初看"什么都不缺" | 88 条连线是**手写的拜耳字母对**，错在连接关系而非数据：旧表里两百多段越出自己的星座、几十处自交（最长的那几段横穿隔壁星座，天龙座一条甚至**跨过北天极**，自然压在小熊座身上；小熊座的斗被写成两条对角线）。这类错**不报错、不缺文件**，肉眼在 100° 视场里也很难逐条判 | 判据必须**几何化**：① 用 `data/constbnd.dat` 的显式折点（岁差到 J2000）建**球面多边形**，"点在多边形内"用正交投影 + 射线法——注意正交投影是**二对一**的，对跖点会落到同一点，必须再判 `dot(dir, 质心) > 0`；② 沿每段大圆按 0.25° 采样，统计"落在别家多边形里 ≥2° 且深度 ≥0.8°"的段；③ 两段大圆求交判自交。修法：按**传统图形**重排（公开星图只作对照、不进仓库，见「数据源与许可」），本星座命不了名的星（旧 Argo 的跨座星、巨蛇座尾穿蛇夫那几颗）**删点成弦** |
| G32 | `--sky-time` 给的是**本地**时间，出图却"整片天转了半圈"（北天极的高度 = 纬度、不随恒星时变，只把天球绕极转了一个大角） | `time_from_text()` 走的是 `Time.get_unix_time_from_datetime_string()`，Godot 这条**按 UTC 解析**；而 HUD 的时辰/四柱是北京的本地时间（`Observer.utc_offset = 8`）。写 `2026-12-15T23:00:00` 得到的是**北京 12-16 07:00**，恒星时差 8 h ≈ 120° | 出图/探针里的 `--sky-time` 一律按 **UTC** 写（本地 23:00 → 写 `T15:00:00`），或直接给 unix 秒；`--sky-view` 的方位/高度要用**同一个瞬刻**（UTC 的 JD）算。**判据**：星图对不上先查这一条，别怀疑投影 |
| G33 | **JPL 的两版近似根数，为 1800–2050 做的那版反而更准**——照"长时间跨度的那版更强"的直觉选，天王星会差到 1018″ | Standish 的两张表：Table 1 拟合 1800–2050（只给六根数 + 直线速率），Table 2a 拟合 3000BC–3000AD（外加 Table 2b 的四个 `b,c,s,f` 项，跟着木土 5:2 共振走）。两版都实现过、都拿 Horizons 的 astrometric RA/Dec 在 1801–2050 抽 20 日逐点比：**Table 1 每一项都不差于 Table 2**（木星 425″ vs 705″、土星 631″ vs 1276″、天王星 81″ vs 1018″、水星 21″ vs 30″） | 用哪张表 **由使用窗口决定，不由跨度决定**：`planets.gd::ELEMENTS` 用的是 Table 1，表头的注释里钉着这一整张对照表。**判据**：任何"再加一组更高阶项就更准"的想法，先在本窗口里量一遍再说 |
| G34 | `--shot=shots/x.png` 报 `Can't save PNG at path … (err=7)`，`err=0` 的那条打印也不出现 | `shots/` 目录**本身不在**时，`Image.save_png()` 与 `FileAccess.open()` 都是 `ERR_FILE_NOT_FOUND`——写盘**不会**替你建目录（`shots/` 曾被整个删掉过，连 `.gdignore` 一起） | 出图前 `mkdir -p shots`。顺带：`shots/.gdignore`（挡 importer 用）**不影响**写盘，删不删与这条无关；`res://` 下被删掉的目录一样不会自动出现，探针 dump 建议写 `user://` |
| G35 | `菜单` 的 `星座` 开关一按，**廿八宿的名字和七个行星名一起消失了** | 那三个名字层（星座名 / 宿名 / 行星名）画在**同一个** `SkyLabels` 上，而开关原来是 `_labels.visible = on`——按的是"整层"，不是"星座" | 开关只关它自己说的那件事：`SkyLabels.set_figures()` 只跳过 88 个星座名，宿名与行星名照画（`sky.gd::set_menu_switch` 调它，不再动 `visible`）。**判据**：往一个已有开关的层里加东西时，先问"这个开关的名字还成立吗" |
| G36 | 把 3D 桌面**换到另一块屏**（或宿主机重启后重新贴合窗口）之后，星空**整块不见了**——窗口在那儿、几何也对，就是不画 | 窗口被外部 `SetWindowPos` 搬走/改尺寸 = 一次 `WM_SIZE`，而星空的渲染策略是 `ON_DEMAND`（G15 那套 `VIEWPORT_UPDATE_ONCE`）：**画一帧的钱已经花完**，改尺寸不会让谁再要一帧。水族箱是 `CONTINUOUS`，所以同一个动作在水族箱上**完全看不出问题** | 任何让宿主搬窗口的动作之后**主动请求一帧**：`_on_screen_selected` / `_on_host_online` 里 `_background.request_redraw()`（与 `桌面` 显隐那条路一模一样）。**判据**：ON_DEMAND 的背景上做"窗口被外力改尺寸"的验证，必须**用这个背景自己**跑，换一个 CONTINUOUS 的背景会假通过 |
| G37 | 给新的一层加了几行代码，**那一层整层不见**（名字/环/十字一个都不画），但进程照跑、`--shot` 照出图、退出码 0、也没有"缺文件"之类的话 | `for axis in [Vector2.RIGHT, Vector2.DOWN]:` 里 `axis` 是**无类型 Variant**，紧接着 `var way := axis if … else -axis` 推不出类型 → `Parse Error: Cannot infer the type of "way"`。这一条错误**不在被改的那一层报**：`sky_labels.gd` 编不过 → `sky.gd`/`backgrounds.gd`/`main.gd` 一串 `Failed to compile depended scripts`，而 `_switch()` 拿着编不过的 GDScript 调 `.new()` → `Invalid call. Nonexistent function 'new' in base 'GDScript'`，背景**照样 build 完**（星点、黄道、宿都在，唯独那一层没有） | 数组字面量取出来的元素一律**显式打类型**（`for axis: Vector2 in […]`、`var way: Vector2 = …`）；排查走完整 stderr（`2>&1 | head -40`），**别只看 `| grep error`**——这条错误的第一行是 `Parse Error`、第二行才是它拖垮的一串（G19 的同族） |
| G38 | 探针里七个行星的位置全是 `nan`，还刷了一屏 `Vector3 cannot be normalized…`；同一条探针里 `direction_of()` 却好好的 | 探针把**Unix 秒**当成儒略日喂给了 `Astro.tt_from_ut(jd)`：`tt_from_ut(1786555800.0)` 得到的是"JD 17.8 亿"→ `T ≈ 4.9 万年`：VSOP87 的级数在 `T¹…T⁵` 上炸成天文数字、开普勒解在 `e>1` 上发散（`.length()` 先变 inf 再变 nan）。`Astro` 里两套时间戳并存：`julian_day_from_unix(unix)` 才是那一侧的入口 | 喂 `jd` 的地方一律问一句"这是儒略日还是 Unix 秒"：unix → `Astro.julian_day_from_unix()` → `tt_from_ut()`。**判据**：`JD` 打印出来应该在 2.4e6 附近，看到 1.7e9 就别往下算了 |

### 本机工具链与脚本环境

| # | 陷阱 | 处置 |
|---|---|---|
| T1 | bash 工具跑的是 **WSL**：脚本里 `/c/...` 不存在，是 `/mnt/c/...` | 脚本内用 `/mnt/c/...`；或干脆别在脚本里调 Windows 程序 |
| T2 | WSL **无法执行** Windows 二进制（`Exec format error`，无 binfmt） | 构建命令直接交给工具调度（`C:/mingw64/bin/gcc.exe …`），**不要写进 bash 脚本** |
| T3 | 隐藏目录 `.tools/` 下的 exe 无法被调度执行 | 运行时放可见目录 `tools/` |
| T4 | `-mwindows` 链接报 `undefined reference to WinMain` | 用 `-mwindows` 就得定义 `WinMain`（本工程就是），好处是**永不弹控制台** |
| T5 | PowerShell 里 `Add-Type` 需要 `System.Drawing` | 加 `-ReferencedAssemblies System.Drawing` |
| T6 | PowerShell 的**函数在 Win32 回调委托里解析不到**（表现为 `GetClassName` 返回空串） | 回调内**内联**所有代码，不要在委托里调 PS 函数 |
| T7 | `Screen.MinimizeAll()` 后截图是锁屏界面 | `LogonUI` 在跑 = 会话已锁 | 截图前先查 `Get-Process LogonUI` |
| T8 | `gcc` 在脚本里 `command not found` | PATH 里的 `C:\mingw64\bin` 在 WSL 侧不生效；用绝对路径 |
| T9 | 合成点击落点乱飞（一次点击打到别的按钮，甚至点到"退出"） | **本机有程序持续扰动鼠标**：`SetCursorPos` 之后几百毫秒光标就能跑掉上百 px，而 Godot 的按钮事件取的是**当时的实时光标位置** | ① 驱动 HUD 用 `tools/click.ps1`（向窗口 `PostMessage` WM_MOUSEMOVE/LBUTTONDOWN/UP，**完全不碰光标**）；② 能不用点击就不用：截图/校验走 `--shot` + `--background=<id>` |
| T10 | 按进程量 GPU 时量错了对象（旧的控制台壳 `godot_console.exe` 只是壳，真身是它拉起来的子进程） | 按进程量 GPU（`\GPU Engine(*)\Utilization Percentage`）时用**错 PID 会一直读到 0** | 真 PID 看 `%LOCALAPPDATA%\XuanDesk\host.log` 里的 `host start: ... pid=NNNN`（那是 Godot 自己报的 `OS.get_process_id()`）；计数器要 `-MaxSamples` 取样，一次性的 `Get-Counter` 常返回 0 |
| T11 | 判断"星点到底画出来没有"：肉眼看不见、按亮度阈值统计也会被天光/银河梯度淹没 | 星点是小而亮、梯度是大而暗，量纲不同 | 用两招：①**点状极大值**（某像素比 ±3px 邻域亮 30 以上）；②与"无星版本"截图**逐像素差分** |
| T15 | 在**开着的壁纸进程还用着日志文件**时重跑工具脚本，`Remove-Item host.log` 报"正由另一进程使用"，`$ErrorActionPreference="Stop"` 下整段脚本直接终止（采样/退出步骤全没跑，留下一份挂在桌面上的壁纸进程） | 脚本不要删别人的日志（读最后一行即可）；跑完先确认 `Get-Process godot,godot_console,host` 为 0 再开下一轮；每轮都有 `Ctrl+Alt+Q` + 计数收尾 |
| T16 | 按 PID 取 GPU 计数器，读回 **14,314,909 %** 这种数字 | `Get-Counter -ListSet 'GPU Engine'` 的 `PathsWithInstances` 里**不止一个计数器**：除了 `Utilization Percentage` 还有原始计数型的 `Running Time`，按 PID 过滤后一路 `-Maximum` 混在一起 | 路径要**同时**按 PID 与计数器名过滤（`-like "*pid_NNN*" -and -like "*utilization percentage"`）；逐实例直接 `Get-Counter -Counter $paths` 轮询并自己求均值，别用 `-MaxSamples` |
| T17 | `curl` 拉 CDS（`cdsarc.cds.unistra.fr`）直接失败：`schannel: … CRYPT_E_REVOCATION_OFFLINE (0x80092013)`，连接都没建起来 | 本机 Windows 侧 schannel **连不上吊销服务器**，而默认策略要查吊销 | `curl --ssl-no-revoke`（VSOP87B 与 BSC5 都是这么拉下来的：**半截文件不会报错**，续传用 `-C -`，落地后按字节数核对，别只看 HTTP 200） |
| T18 | 按名字杀进程后，桌面上还剩一个**还在渲染的**实例：新开的那个与它抢同一个 WorkerW，于是"截图与日志对不上""点了菜单没反应" | 进程名带点（真身是 `godot.windows.opt.tools.64.exe`，tasklist 会截断成 `godot.windows.opt.tools.6`），按 `godot.exe` 这种名字杀**杀不完全** | 用 `tools/xuankill.ps1`（`Get-Process | Where-Object { $_.ProcessName -like '*godot*' -or $_.ProcessName -eq 'host' } | Stop-Process -Force`，跑完自己复检并打印 `clean`）；**每轮开跑前先跑它** |
| T19 | 手摆的 chip 尺寸不对：要 `60×24` 的按钮量出来是 **`60×31`**，换字号也不动（13/16/20 全是 31） | ① **Button 永远不会小于自己的最小尺寸**，而**进树之前**那套最小尺寸来自**默认主题**（不是我们 override 的样式盒）——先用默认值把尺寸夹到 31，之后最小尺寸降下来**它也不会自己缩回**；② 样式盒的内容边距默认还会再加十几 px | 两半都要治：`StyleBoxFlat.set_content_margin_all(0)`（`SkyCompassHud._box`）让 24 px 高的 chip **合法**，**`add_child` 之后再设 `position`/`size`** 让它**不被夹**。判据：探针读回每颗按钮的矩形，与设计值逐颗比对 |
| T20 | 盘**右上角**的 `↘` 箭头 chip 看不见、点了没反应 | 壳的 `菜单` 是**独立 OS 窗口**，glue 在 HUD 内容右上角——窗口在 HUD **之上**，压在 `↘` 的字形上：字被盖住、点击也归它 | `MENU_TOP = -28`：菜单**悬在内容上方**（还是右上角那个位置、还是那个按钮），让开盘角；HUD 是逐像素透明的，看起来只是高 28 px。以后谁把控件放进右上角，同样要挪菜单 |

---

## 验证

改完必须**跑起来看**：判据是"屏幕上/数字上真的变了"，不是"代码看起来对"。

| 手法 | 用在哪 | 判据 |
|---|---|---|
| **出图** `--shot=<png> --shot-frames=N --wallpaper=0 --hud=0 --sky-time=<UTC> --sky-rate=0 --sky-view=<方位>,<高度>` | 星空的任何一层 | 主视口存 **2560×1440**；`--shot-target=hud` 存 HUD 窗（**300×340**）；`shots/` 要先存在（G34） |
| **减图**（同机位两张逐像素差） | 隔离一个开关/一层的贡献 | 差值只落在想量的那块；配一张**把改动退回去**的图当负对照 |
| **点状极大值**（某像素比 ±3px 邻域亮 30 以上） | "星点到底画出来没有" | 点光与小而亮的量纲和梯度（天光/银河）不同，纯阈值法会被淹没（T11） |
| **headless 探针** `--script res://<现写的>.gd` | 数值与状态（历法、排盘、相机、时钟、按钮几何） | 探针**写文件**（`user://`）再读——编辑器版 Godot 的 stdout 进不了管道；配 `timeout`，看不到输出先看有没有 `SCRIPT ERROR: Parse Error`（G19） |
| **引擎驱动** `--fixed-fps 60` + `await process_frame` | 动画类（转向、时辰步进） | 每帧打印状态，与 `1−e^(−k·t)` 逐帧对；结束后**不再发信号**才算回到静默 |
| **对权威** | 日月行星 | JPL Horizons `QUANTITIES='1'`（astrometric RA/Dec，geocentric：`CENTER='500@399'`），`TLIST` 传一组 JD，逐点算角距 |
| **负对照** | 每一条断言 | 探针自己也要被怀疑：等距刻在 15° 旋转下不变（G25），所以盘上留了一个唯一标记（"子/北"那根青刻）来读数 |

碎图与探针**用完即删**（探针里那些"临时改一个常数再减图"的开关同理）；跑完整套前先确认没有遗留进程
（`tools/xuankill.ps1` 打印 `clean`，即 `Get-Process | Where ProcessName -like '*godot*' -or -eq 'host'` 为 0）。
