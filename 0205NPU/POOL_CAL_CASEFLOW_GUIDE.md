# POOL_cal Case 生成与仿真使用说明

本文档说明以下文件如何协同使用：

- `0205NPU/scripts/gen_pool_cal_cases.py`
- `0205NPU/tb/testbench_POOL_cal.sv`
- `Pool.sim/sim_1/behav/xsim/testbench_POOL_cal.tcl`

目标：自动生成 POOL_cal 的定向/随机测试 case，运行仿真，并基于 golden 期望值检查 PASS/FAIL。

## 1. 文件职责

### 1.1 `gen_pool_cal_cases.py`
- 角色：测试用例生成器。
- 输入：Python 中手工配置的约束参数与定向 case 列表。
- 输出：自动生成 include 文件 `0205NPU/tb/generated/pool_cal_cases_auto.vh`。
- 生成内容：`task automatic run_auto_cases; ... endtask`，内部包含大量 `drive_beat(...)` + `check_last(...)` 语句。

### 1.2 `testbench_POOL_cal.sv`
- 角色：DUT 测试平台与结果检查器。
- 通过以下语句导入自动生成的 case：
  - `` `include "generated/pool_cal_cases_auto.vh" ``
- 在 `initial` 流程中调用 `run_auto_cases();`。
- 关键任务：
  - `drive_beat(...)`：发送一个输入 beat。
  - `check_last(...)`：比较 DUT 实际输出与期望输出。
- 日志输出：
  - `[PASS] case_name ...`
  - `[FAIL] case_name ...`
  - 汇总 `TOTAL/PASS/FAIL`。

### 1.3 `testbench_POOL_cal.tcl`
- 角色：xsim 仿真运行控制脚本。
- 关键语句：
  - `run all`
- 含义：仿真持续运行，直到 testbench 执行 `$finish`。
- 若改成固定短时长（例如 `run 1000ns`），会导致 case 未跑完。

## 2. 端到端流程

### 2.1 修改约束或 case
- 编辑 `0205NPU/scripts/gen_pool_cal_cases.py`。
- 可选修改：
  - `CONSTRAINTS` 中的随机参数。
  - `make_directed_cases()` 中的定向场景。

### 2.2 重新生成 SV include 文件
在仓库根目录（`g:/0_Vivado_prj_learn/Pool_0305`）执行：

```powershell
C:/Users/LENOVO/AppData/Local/Programs/Python/Python313/python.exe 0205NPU/scripts/gen_pool_cal_cases.py
```

期望输出：

```text
Generated: .../0205NPU/tb/generated/pool_cal_cases_auto.vh
Total cases: <N>
```

### 2.3 在 Vivado 启动仿真
- 确认仿真顶层模块为 `testbench_POOL_cal`。
- 在 `sources` 模块右键点击 `Refresh Hierachy` 确保新生成的 `pool_cal_cases_auto.vh` 被调用。
- 确认 `testbench_POOL_cal.tcl` 使用 `run all`。
- 执行 `launch_simulation`。

### 2.4 检查日志结果
- 在 Tcl Console 或 `simulate.log` 中确认：
  - 所有 case 都输出 `[PASS]` 或 `[FAIL]`。
  - 最终有汇总行：`TOTAL=... PASS=... FAIL=...`。

## 3. `gen_pool_cal_cases.py` 参数与影响

当前参数位于 `CONSTRAINTS`：

```python
CONSTRAINTS = {
    "random_seed": 20260305,
    "random_cases": 200,
    "win_len_min": 1,
    "win_len_max": 12,
    "valid_probability": 0.70,
}
```

### 3.1 `random_seed`
- 类型：整数。
- 影响：
  - 控制随机 case 的可复现性。
  - 相同 seed + 相同约束 -> 生成完全一致的随机 case。
  - seed 改变 -> 数据序列与 case 组合随之改变。
- 使用场景：
  - 需要回归稳定时固定 seed。
  - 需要探索更多场景时切换 seed。

### 3.2 `random_cases`
- 类型：整数（>= 0）。
- 影响：
  - `make_random_cases()` 生成的随机 case 数量。
  - 总 case 数 = `len(make_directed_cases()) + random_cases`。
  - 数值越大，仿真时间越长，覆盖率通常越高。
- 例子：
  - directed=8，`random_cases=200` -> 总计 208 个 case。

### 3.3 `win_len_min`
- 类型：整数（>= 1）。
- 影响：
  - 随机 case 中单个窗口的最小 beat 数。
  - 值越小，出现超短窗口（1 beat）的概率越高。
- 注意：
  - 必须满足 `win_len_min <= win_len_max`。

### 3.4 `win_len_max`
- 类型：整数（>= `win_len_min`）。
- 影响：
  - 随机 case 中单个窗口的最大 beat 数。
  - 值越大，窗口更长，仿真运行时间通常更长。

### 3.5 `valid_probability`
- 类型：浮点数（[0.0, 1.0]）。
- 影响：
  - 每个 beat 的 `vld=1` 概率。
  - 值越低：无效 beat 越多，期望值为 `MIN_SIGNED` 的 case 越多。
  - 值越高：有效比较更多，数据通路覆盖更充分。
- 常用设置：
  - `0.3`：重点压测 invalid 路径。
  - `0.7`：较均衡。
  - `0.9`：主要覆盖 valid 数据路径。

## 4. 定向 Case 维护（`make_directed_cases`）

`make_directed_cases()` 用于放置可确定复现的功能/边界测试。

每个 case 包含：
- `name`：case 名称（会打印在日志中）。
- `beats`：`Beat(vld, dat, first, last)` 序列。
- `expected`：`check_last` 用于比对的期望输出。

建议覆盖的定向类别：
- 单拍窗口。
- 全负数输入。
- 首拍无效。
- 全无效输入（期望 `MIN_SIGNED`）。
- 相等值 tie 行为。
- `vld` 为 X 态鲁棒性（`"1'bx"`）。

## 5. 生成文件使用约定

`pool_cal_cases_auto.vh` 是自动生成代码。

- 不建议手工编辑该文件。
- 手改内容会在下次生成时被覆盖。
- 正确修改入口：
  - `gen_pool_cal_cases.py` 的约束参数。
  - `make_directed_cases()`。

## 6. 常见问题与处理

### 6.1 case 没有全部打印
- 现象：只看到前几个 PASS。
- 原因：仿真时长固定且过短（例如 `run 1000ns`）。
- 处理：将 `testbench_POOL_cal.tcl` 设置为 `run all`。
- 目前设定的默认值为run all

### 6.2 `Total cases` 与预期不一致
- 检查：
  - `random_cases` 数值。
  - `make_directed_cases()` 中 case 数。
- 公式：
  - `Total = directed_count + random_cases`。

### 6.3 include 文件未更新
- 原因：改了约束但未重新执行生成脚本。
- 处理：重新运行 Python 命令，并检查 `.vh` 文件头部时间戳。

### 6.4 没有最终 summary
- 原因：仿真在 `$finish` 之前被终止。
- 处理：
  - 使用 `run all`。
  - 确认无外部超时设置提前结束仿真。

## 7. 常用命令速查

生成 case：

```powershell
C:/Users/LENOVO/AppData/Local/Programs/Python/Python313/python.exe 0205NPU/scripts/gen_pool_cal_cases.py
```

Vivado Tcl（启动后）：

```tcl
run all
```

在日志中检索 PASS/FAIL：

```powershell
Select-String -Path "g:/0_Vivado_prj_learn/Pool_0305/Pool.sim/sim_1/behav/xsim/simulate.log" -Pattern "\[PASS\]|\[FAIL\]|POOL_cal SUMMARY|TOTAL="
```
