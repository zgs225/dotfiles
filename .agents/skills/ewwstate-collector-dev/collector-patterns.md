# Collector 编写模式

## 两条铁律

1. **topic 名 == eww 变量名**。`common.yuck` 里 `(defpoll volume ...)` → collector 的 `topics = ("volume",)`。
2. **采集器产出的值 == 旧脚本打印的字符串**（标量/JSON/yuck-literal 原样），yuck 渲染逻辑零改动。

## PollCollector 模板

```python
from framework import PollCollector, collector
from util import run, shell, read_sysfs, sysfs_glob, running

@collector
class Foo(PollCollector):
    name = "foo"                       # 日志/refresh 用唯一 id
    topics = ("foo_var",)              # == eww 变量名
    interval = 3.0                     # 秒；保持与旧 defpoll :interval 一致
    async def collect(self):
        return {"foo_var": "value"}    # 值 == 旧脚本字符串
```

## EventCollector 模板

```python
@collector
class Bar(EventCollector):
    name = "bar"
    topics = ("bar_var",)
    async def run(self):
        while True:
            # await 事件源（i3 IPC / inotifywait / D-Bus / socket …）
            value = await self._wait_for_event()
            await self.store.set("bar_var", value)
```

## 非阻塞铁律

collector **必须非阻塞**：
- ✅ `util.run(["cmd"])` / `util.shell("pipeline")` — async 子进程
- ✅ `read_sysfs(path)` — 同步但瞬时（读 /sys /proc）
- ❌ `subprocess.run()` / `os.popen()` — 阻塞 event loop，会卡住所有其他 collector

## 并发采集模式

一个 collector 管多个 topic 时，用 `asyncio.gather` 并发取数据：

```python
import asyncio
async def collect(self):
    count_raw, hist_raw, dnd_raw = await asyncio.gather(
        run(["dunstctl", "count", "history"], timeout=3.0),
        run(["dunstctl", "history"], timeout=5.0),
        run(["dunstctl", "is-paused"], timeout=3.0),
    )
    # 从 raw 派生各 topic
    return {"notif_count": ..., "notifications": ..., "dnd": ...}
```

## sysfs 直读模式

当旧脚本只是 `cat /sys/...` + 简单算术时，直接读 sysfs 零 fork：

```python
async def collect(self):
    for dev in sysfs_glob("/sys/class/backlight/*"):
        cur = read_sysfs(f"{dev}/brightness")
        max_ = read_sysfs(f"{dev}/max_brightness")
        if cur.isdigit() and max_.isdigit() and int(max_) > 0:
            return {"brightness": str(int(cur) * 100 // int(max_))}
    return {"brightness": "0"}
```

## i3 IPC 事件驱动模式

替代高频 defpoll（如 500ms workspaces）。用 raw i3 IPC 协议（不依赖 i3ipc 库）：

```python
_MAGIC = b"i3-ipc"
_HEADER = struct.Struct("<6sII")
_MSG_GET_WORKSPACES = 1
_MSG_SUBSCRIBE = 2
_EVENT_BIT = 0x80000000

# 关键：正确的消息泵
# i3 可能在 get_workspaces 回复前插入事件消息（payload 是 dict 而非 list）。
# 必须用 high-bit 区分事件/回复 + pending 跟踪，否则消息对齐错乱。
pending = False
async def _request():
    nonlocal pending
    if not pending:
        await _i3_send(writer, _MSG_GET_WORKSPACES)
        pending = True
await _request()
while True:
    msg_type, payload = await _i3_recv(reader)
    if msg_type & _EVENT_BIT:
        await _request()           # 合并去重
    elif msg_type == _MSG_GET_WORKSPACES and pending:
        pending = False
        ws_list = json.loads(payload)
        await self.store.set("workspaces", _build_yuck(ws_list))
```

## inotifywait 事件驱动模式

替代 deflisten 脚本（如 updates 三合一）：

```python
async def run(self):
    # 初始发布
    await self._publish_all()
    while True:
        proc = await asyncio.create_subprocess_exec(
            "inotifywait", "-mq", "-e", "create,delete,modify,move,attrib",
            _CACHE_DIR, stdout=asyncio.subprocess.PIPE, ...)
        async for raw_line in proc.stdout:
            filename = raw_line.decode().rstrip().split()[-1]
            if "updates.checking" in filename:
                await self._publish_checking()
            if "updates.json" in filename:
                await self._publish_updates()
                await self._publish_update_list()
```

## 交叉读 eww 变量

旧脚本里 `eww get <var>` 读另一个 eww 变量的模式，迁到 daemon 后保留为 async 调用：

```python
filter_val = await run(["eww", "get", "updates_filter"], timeout=2.0)
```

## 防御性编程

- `_build_yuck(data)` 里先检查 `isinstance(data, list)`，防 i3/dunst 返回意外格式
- JSON 解析包 `try/except`，失败返回 fallback 而非 crash
- `read_sysfs` 返回空字符串而非抛异常
- `util.run` 超时/找不到命令返回 `""` 而非抛异常

## bash `$(...)` 尾部换行差异

bash 的 `$(cmd)` 会 strip 尾部 `\n`，Python `json.loads` 不会。如果旧脚本用 `$(dunstctl history)` 再传给 jq，而你的 collector 直接 `json.loads(raw)`，body 文本可能多一个 `\n`。修复：`.rstrip("\n")`。

## JSON 紧凑格式

旧脚本用 `jq -c .` 输出紧凑 JSON。Python 的 `json.dumps` 默认带空格。匹配时用 `separators=(",", ":")`：

```python
json.dumps(data, ensure_ascii=False, separators=(",", ":"))
```

## yuck-literal 拼写

采集器拼 yuck-literal 时，结构必须与旧脚本**逐字节一致**（eww `literal` widget 对格式敏感）。关键：
- 属性间空格数、括号位置要精确复制
- 转义函数 `esc()` 与旧脚本一致：`s.replace("\\", "\\\\").replace('"', '\\"')`
