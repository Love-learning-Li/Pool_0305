# 0205NPU POOL 模块实现说明

## 1. 目标与整体架构

本工程的 POOL 路径采用“三段式”结构：

- `POOL_rd_SRAM_ctrl`：读侧调度与地址生成（主控制器，下面称“管家”）
- `POOL_cal`：池化计算（当前是 `max pooling`）
- `POOL_wr_SRAM_ctrl`：写侧控制与写完成统计

`POOL_TOP` 只做例化和连线，不放控制逻辑。

---

## 2. 顶层接口信号说明（`POOL_TOP` 对外）

### 2.1 时钟与任务控制

| 信号 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| `clk` | input | 1 | 模块时钟 |
| `rst_n` | input | 1 | 低有效复位 |
| `start` | input | 1 | 启动脉冲（建议拉高 1 拍） |
| `working` | output | 1 | 管家模块处于运行态 |
| `done` | output | 1 | 管家模块完成所有窗口遍历的完成脉冲 |

### 2.2 配置接口

| 信号 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| `i_cfg_Kx` / `i_cfg_Ky` | input | `log2_K` | 池化窗口尺寸 |
| `i_cfg_Sx` / `i_cfg_Sy` | input | `log2_S` | 步长 |
| `i_cfg_Px` / `i_cfg_Py` | input | `log2_P` | padding |
| `i_cfg_CHin` / `i_cfg_Hin` / `i_cfg_Win` | input | `log2_CH/H/W` | 输入特征图尺寸 |
| `i_cfg_CHout` / `i_cfg_Hout` / `i_cfg_Wout` | input | `log2_CH/H/W` | 输出特征图尺寸 |

### 2.3 SRAM 读接口

| 信号 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| `o_rd_en` | output | 1 | 读请求有效 |
| `o_rd_addr` | output | `log2_ADDR` | 读地址 |
| `i_rd_dat_vld` | input | 1 | 读数据有效（来自 SRAM） |
| `i_rd_dat_out` | input | `MAX_DAT_DW` signed | 读数据 |

### 2.4 SRAM 写接口

| 信号 | 方向 | 位宽 | 说明 |
|---|---|---:|---|
| `o_wr_en` | output | 1 | 写请求有效 |
| `o_wr_addr` | output | `log2_ADDR` | 写地址 |
| `o_wr_dat` | output | `MAX_DAT_DW` | 写数据 |

---

## 3. 子模块接口信号说明（内部连线）

### 3.1 `POOL_rd_SRAM_ctrl` 输出给其他模块

| 信号 | 去向 | 说明 |
|---|---|---|
| `o_win_first` | `POOL_cal.i_win_first` | 标记窗口首元素（用于重置 max） |
| `o_win_last` | `POOL_cal.i_win_last` | 标记窗口末元素（用于输出结果） |
| `o_wr_addr` | `POOL_wr_SRAM_ctrl.i_wr_addr` | 对应输出像素写回地址（已做 1 拍对齐） |

### 3.2 `POOL_cal` 输出给写控制

| 信号 | 去向 | 说明 |
|---|---|---|
| `o_dat_out_vld` | `POOL_wr_SRAM_ctrl.i_wr_vld` | 当前窗口结果有效 |
| `o_dat_out_pkt` | `POOL_wr_SRAM_ctrl.i_wr_dat` | 当前窗口 max 结果 |

---

## 4. “管家”逻辑是什么

这里“管家”指 `POOL_rd_SRAM_ctrl`。它负责整个池化任务的调度。

### 4.1 管家的核心职责

1. 维护任务状态  
`running` 控制任务是否在执行，`start` 触发开始，`done` 在全部窗口遍历结束时输出。

2. 驱动五层嵌套遍历  
遍历顺序是 `kx -> ky -> ow -> oh -> ch`，等价于软件中的 5 层循环。

3. 计算输入访问坐标并做越界过滤  
`ih = oh*Sy + ky - Py`  
`iw = ow*Sx + kx - Px`  
仅在坐标合法时发起读请求。

4. 生成地址和时序对齐信号  
- 读地址：输入特征图线性地址  
- 写地址：输出特征图线性地址（在输入区后）  
- `win_first/win_last` 与写地址都打一拍，和 SRAM 读数据有效对齐。

### 4.2 管家的关键判定

- `win_first = (kx==0 && ky==0)`：窗口开始
- `win_last = (kx==Kx-1 && ky==Ky-1)`：窗口结束
- `last_window`：`ch/oh/ow` 也都到最后且 `win_last=1`
- `done = last_window_d1`：完成脉冲

---

## 5. 各模块怎么运行（时序流程）

1. `start` 拉高一拍，管家进入 `running`。  
2. 管家推进计数器，按窗口坐标生成 `o_rd_en/o_rd_addr`。  
3. SRAM 返回 `i_rd_dat_vld/i_rd_dat_out` 后，`POOL_cal` 更新窗口最大值。  
4. 当 `i_win_last=1` 时，`POOL_cal` 产出 `o_dat_out_vld/o_dat_out_pkt`。  
5. `POOL_wr_SRAM_ctrl` 在 `running && i_wr_vld` 时发写请求到 `o_wr_*`。  
6. 管家遍历完最后一个窗口后输出 `done`，任务结束。  

说明：当前顶层 `working/done` 由读侧管家给出；写侧也有自己的 `working/done`，但在 `POOL_TOP` 里未向外导出。

---

## 6. 地址规则

### 6.1 输入地址

输入特征图按 `CH-H-W` 展平：

`addr_in = (ch * Hin + ih) * Win + iw`

### 6.2 输出地址

输出写到输入数据区之后：

- `out_base = Win * Hin * CHin`
- `addr_out = out_base + (ch * Hout + oh) * Wout + ow`

---

## 7. 写控制器（`POOL_wr_SRAM_ctrl`）当前实现

本次已从“纯直通”升级为有状态逻辑：

- `start` 后置 `running=1`
- `wr_fire = running && i_wr_vld`
- `wr_cnt` 仅在 `wr_fire` 时累加
- 当 `wr_cnt` 达到 `CHout*Hout*Wout-1` 且本拍 `wr_fire` 时，输出 `done` 并退出 `running`
- `o_wr_addr/o_wr_dat` 仍透传输入（地址由管家提前算好）

---

## 8. 当前仿真状态

当前 `testbench_POOL.sv` 已改为小规模参数：

- `CHin=4, Hin=8, Win=8`
- `Kx=3, Ky=3, Sx=1, Sy=1, Px=1, Py=1`

在该参数下运行结果为：

- `result match`

---

## 9. SRAM 读写时序与延时说明

当前工程使用的 SRAM 行为模型见：

- `rtl/02_SRAM/DP_SRAM.v`
- `rtl/02_SRAM/SP_SRAM.v`

### 9.1 读通道（有 1 拍延时）

- 在 `posedge rd_clk`，若 `rd_en=1`，执行 `rd_dat_r <= mem[rd_addr]`
- 同时 `rd_dat_vld <= rd_en`
- 因此可按接口语义理解为：发出 `rd_en/rd_addr` 后，下一拍 `rd_dat_vld` 对应的数据有效（1-cycle latency）

这也是为什么读侧管家把 `win_first/win_last/o_wr_addr` 都打一拍后再给计算/写控制，确保与读数据对齐。

### 9.2 写通道（同步写，当拍生效）

- 在 `posedge wr_clk`，若 `wr_en=1`，执行 `mem[wr_addr] <= wr_dat`
- 写动作发生在该时钟沿（同步写），没有额外写流水级

### 9.3 同拍同地址读写

在该行为模型下，同一拍对同一地址同时读写时，读通常看到旧值（写入的新值在该拍末更新到 `mem`，后续读才稳定可见）。
