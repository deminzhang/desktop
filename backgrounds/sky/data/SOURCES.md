# 星空数据来源与许可

## `data/catalog.txt` — Yale Bright Star Catalogue, 5th Revised Ed.（BSC5）

| 项 | 值 |
|---|---|
| 下载地址 | `https://cdsarc.cds.unistra.fr/ftp/V/50/catalog.gz` |
| 取得日期 | 2026-09-29（`curl -sSL`，573,921 字节 `.gz` → 解压 1,704,879 字节） |
| 记录数 | 9110 条定宽记录（每行 197 字节），其中 **9096 条**有位置与 V 星等；其余是星表自身置空的撤档条目，解析时跳过 |
| 读取字段 | 字节（1 起）：HR 1-4、Name 5-14、赤经 J2000 76-83、赤纬 J2000 84-90、Vmag 103-107、B−V 110-114 —— 取自该目录 `ReadMe` 的字节表 |
| 许可 | **公有领域**。Hoffleit D., Warren Jr W.H. (1991)，Astronomical Data Center / NSSDC / ADC 发布；NASA/ADC 机读数据不主张版权 |
| 再分发 | 原样保留在本仓库（星表是事实数据）。引用出处即可，ADC 无附加条款 |

## 未采用的数据源

`d3-celestial` 的 `stars.6.json` / `constellations.lines.json` / `constellations.bounds.json`：
仓库 LICENSE 为 BSD-3-Clause（可用），但 README **未声明数据溯源**。按计划 §6.3 的红线，这些文件**只作对照、不进仓库**——
S2 的星座连线改为由本目录的 BSC5 自行构建（Bayer 名 + 亮星位置）。

## `data/constbnd.dat` + `data/bound_20.dat` — 星座边界（Davenhall & Leggett 1989）

| 项 | 值 |
|---|---|
| 来源 | `https://cdsarc.cds.unistra.fr/ftp/VI/49/`（`constbnd.dat` 45K / `bound_20.dat` 121K（原 .gz 已解压，不留重复副本）） |
| 取得日期 | 2026-09-29 |
| `constbnd.dat` | Delporte (1930) 边界的**折点表**：赤经（**小时**）、赤纬（度）、星座缩写、相邻星座。每个星座的第一行是"原点"（没有相邻星座），其后按**逆时针顺序**列出边界折点 —— 即拓扑是显式给的。共 1651 行 = 1651 条腿 |
| `bound_20.dat` | 同一套边界**已岁差到 J2000** 的点云（12,948 行，含 `O` 折点 1533 个与 `I` 插值点），但**按赤经排序** |
| 许可 | **公有领域**（ADC/CDS 机读目录；ReadMe 引用 Delporte 1930、Davenhall & Leggett 1989，无附加限制） |
| 为何不用 d3-celestial 的边界文件 | 同 §6.3 红线：来源不明的副本。这里用一手来源 |

### 怎么用（以及为什么）

1. **拓扑只能取自 `constbnd.dat`**。J2000 文件按赤经排序，且岁差把弧线从 1930 年的"等赤经/等赤纬"网格上挪开，所以
   按文件顺序连线会画成满屏竖条纹，按坐标分组只剩 20%，按"邻近重建"则会串到隔壁边界上（实测总长 6000–8800°，来回乱走）。
2. **折点要岁差到 J2000**（`Precession`，IAU 1976 / Meeus 21）。校验：把 `constbnd.dat` 的折点岁差过去，与
   `bound_20.dat` 的 J2000 折点比对，**中位偏差 0.0000°**。
3. **拓扑本身可自证**：Delporte 的边界每条腿都是等赤经或等赤纬的，实测 **1651/1651 条腿都在 0.02° 内轴向对齐**。

> 边界总长（各星座周长之和）实测 **9077°** —— 这是 IAU 划法的真实长度（不是"约 600°"，早先这个估计是错的）。

## 天文常数（本文件所载，供 S3+ 引用）

| 量 | 值（J2000 赤道坐标） |
|---|---|
| 银河北极 | RA 192.85948°，Dec +27.12825° |
| 银河中心 | RA 266.40499°，Dec −28.93617° |

`backgrounds/sky/sky.gd` 用这两个方向点亮 `shaders/dome.gdshader` 里的银河带，与恒星共用
`StarCat.direction()` 的同一套坐标约定，因此 `SkyRoot` 一转，银河与星空同步转。

> 注：`data/` **不放 `.gdignore`**。Godot 对 `.txt` 没有 importer（不会被导入，G12 的场景不适用），
> 而 `.gdignore` 会让该目录被导出器忽略——导出包会漏掉星表。见计划 §8 S8 待办。
