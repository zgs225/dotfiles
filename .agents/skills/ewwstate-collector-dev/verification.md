# 7 步验证流程

每个 collector 单元**强制走完 7 步，缺一不可**。一次只做一个单元，做完验证再下一个。

## Step 1: 写采集器

`collectors/<name>.py`，遵循 [collector-patterns.md](collector-patterns.md)。

## Step 2: 离线对等校验（apply 前）

```bash
cd dot_config/eww/ewwstate
PYTHONDONTWRITEBYTECODE=1 python3 -c "
import sys,asyncio; sys.path.insert(0,'.')
from collectors.<X> import <C>; from store import StateStore
print(asyncio.run(<C>(StateStore('/tmp/_eq')).collect()))"
```

与旧脚本/旧命令输出比对。**不一致就改采集器，绝不带病上线。**

### 对等三策略

| 值类型 | 比对方法 | 注意 |
|---|---|---|
| **标量** | 逐字节相等 | `"79" == "79"` |
| **JSON** | `json.loads` 后比 dict | PUA 图标 `\uXXXX` vs 原始 UTF-8 对 eww 等价，逐字节会假阴性 |
| **yuck-literal** | 比结构 + 关键 token | 提取 class 集合、title 列表、onclick 集合做集合比较；实时量（cpu/watts/信号强度）采样窗口不同，瞬时不等**反而证明变量是活的**，不是迁移错误 |

### 实时抖动量

`watts`/`cpu`/`mem`/`temp`/信号强度等，校验时 eww 值与 daemon 值差一点是正常的。对这类字段断言「类型+范围+量级」而非相等。

## Step 3: 改 common.yuck

把对应 `defpoll`/`deflisten` 的命令换成：

```yuck
;; defpoll → get
(defpoll <topic> :interval "<原值>" :initial "<原值>"
  "~/.config/eww/scripts/ewwstate get <topic> '<fallback>'")

;; deflisten → listen
(deflisten <topic> :initial "<原值>"
  "~/.config/eww/scripts/ewwstate listen <topic>")
```

**含括号/`$`/空格的 fallback 必须单引号**（见 [gotchas.md](gotchas.md) #8）。interval 保持原值。

## Step 4: apply + reload

```bash
cd /home/yuez/.local/share/chezmoi
find dot_config/eww/ewwstate -name __pycache__ -exec rm -rf {} + 2>/dev/null
chezmoi apply --force ~/.config/eww          # 只 apply eww 子树！
i3-msg exec ~/.config/eww/scripts/launch.sh  # 绝不直接跑 launch.sh
```

## Step 5: 自动化校验

```bash
# daemon 存活 + 新 collector 出现
~/.config/eww/scripts/ewwstate status
tail -3 /tmp/ewwstated.log   # 看 starting N collector(s) 含新名字

# 无异常
grep -ciE "exception|traceback" /tmp/ewwstated.log   # 应为 0

# topic 值一致
eww get <topic>                          # eww 侧
~/.config/eww/scripts/ewwstate get <topic>  # daemon 侧
# 两者应相等
```

**popup-only 变量必须先打开 popup 再测**（见 [gotchas.md](gotchas.md) #1）。

### 打开 popup 的方法

```bash
# 优先
~/.config/eww/scripts/open-popup.sh <name>

# 兜底（open-popup.sh 因无鼠标坐标偶发失败）
eww open <name> --arg pos_x=1850px --arg pos_y=40px
eww update popup_open="<name>"
```

### 判断 popup 是否打开

```bash
eww get popup_open   # 值==popup 名；none=全关
# 别用 eww list-windows（它列所有定义的窗口，非打开的）
```

## Step 6: 视觉校验

```bash
maim /tmp/eww-screenshots/<tag>-$(date +%H%M%S).png
FULL=$(ls -t /tmp/eww-screenshots/<tag>-*.png | grep -v small | head -1)
convert "$FULL" -resize 1100x -strip /tmp/eww-screenshots/<tag>-view.png
```

**截图 read 前必压缩**（全屏 PNG ~1.5MB 超上下文限制）。

凡组件在某 popup，**必须打开该 popup 再截一张**，肉眼确认 widget 正常。

## Step 7: 清理旧脚本

### 删留判断

```bash
grep -rn "<脚本名>" dot_config/eww   # 全树 grep，含 scripts/！
```

- 仅被 `defpoll`/`deflisten` 引用且**无 onclick** → 可删
- 有 onclick 引用（动作脚本的乐观更新链） → **保留**

### 删除方法

```bash
git rm dot_config/eww/scripts/executable_<name>.sh   # 源
rm -f ~/.config/eww/scripts/<name>.sh                 # 目标
```

`chezmoi apply ~/.config/eww`（子树）**不删**源已移除的孤儿目标，必须手动 `rm`。

### 死脚本扫描

迁移全部完成后，扫一遍所有 `executable_*.sh`，检查是否还有零引用的死脚本：

```bash
cd dot_config/eww/scripts
for f in executable_*.sh; do
  name=$(basename "$f" .sh | sed 's/^executable_//')
  refs=$(grep -rn "$name" ../components/ ../ewwstate/ . 2>/dev/null \
    | grep -v "^./executable_${name}" | grep -v Binary | wc -l)
  [ "$refs" -eq 0 ] && echo "DEAD: $name"
done
```
