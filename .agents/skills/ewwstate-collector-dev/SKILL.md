---
name: ewwstate-collector-dev
description: Use when writing, debugging, or migrating ewwstate daemon collectors (dot_config/eww/ewwstate/collectors/). Covers the asyncio daemon backend that replaces defpoll/deflisten shell scripts.
---

# ewwstate Collector 开发与调试

## 何时使用

- 新增/修改 `collectors/*.py`
- 把 `common.yuck` 里的 `defpoll`/`deflisten` 迁移到 daemon
- 调试 daemon 异常（crash、topic 不更新、值不对）
- 删除旧脚本前的删留判断

## 架构一句话

```
collectors/*.py ──(独立 asyncio task，crash 由 supervisor 指数退避重启)──▶ StateStore
   PollCollector  定时 collect() → {topic: value}      内存 dict + 变更时原子写 tmpfs
   EventCollector 常驻 run()，await 事件源后 store.set()  ewwstate get = cat tmpfs（瞬时）
                                                          ewwstate listen = cat + inotifywait
```

## 文件清单

| 文件 | 作用 |
|---|---|
| `framework.py` | `PollCollector`/`EventCollector` 基类 + `@collector` 装饰器 |
| `store.py` | `StateStore`：`set()` 去重+原子写；`get()` 纯读永不阻塞 |
| `util.py` | `run(cmd)`/`shell(cmd)` 异步子进程；`read_sysfs`/`sysfs_glob`；`running(*names)` |
| `daemon.py` | `discover_collectors()` 自动 import 全包 + `_supervised` 独立 task |
| `main.py` | CLI：`daemon`/`get`/`listen`/`dump`/`status` |
| `collectors/<name>.py` | 一个采集器一文件，`@collector` 注册 |

## 快速命令

```bash
# daemon 状态
~/.config/eww/scripts/ewwstate status
~/.config/eww/scripts/ewwstate dump          # 所有 topic 当前值
tail -f /tmp/ewwstated.log                   # 采集日志

# 离线对等校验（apply 前）
cd dot_config/eww/ewwstate
PYTHONDONTWRITEBYTECODE=1 python3 -c "
import sys,asyncio; sys.path.insert(0,'.')
from collectors.<X> import <C>; from store import StateStore
print(asyncio.run(<C>(StateStore('/tmp/_eq')).collect()))"

# 重载（铁律顺序）
find dot_config/eww/ewwstate -name __pycache__ -exec rm -rf {} +
chezmoi apply --force ~/.config/eww
i3-msg exec ~/.config/eww/scripts/launch.sh

# 打开 popup 验证
eww open <name> --arg pos_x=1850px --arg pos_y=40px
eww update popup_open="<name>"

# 截图+压缩
maim /tmp/eww-screenshots/<tag>-$(date +%H%M%S).png
convert <full> -resize 1100x -strip <small>   # read 前必压缩
```

## 详细指南

- **写 collector 的模式与模板** → [collector-patterns.md](collector-patterns.md)
- **7 步验证流程** → [verification.md](verification.md)
- **踩坑铁律** → [gotchas.md](gotchas.md)
