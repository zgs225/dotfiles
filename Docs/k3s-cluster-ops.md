# k3s 集群运维经验手册

> 2026-10 起沉淀。运行事实为主的理论都可能变化，每次事故后增补。
> 相关仓库：`~/Workspace/Misc/k3s-nodes`（Ansible）· Trilium「Kubernetes」分类（体检/运维通道笔记）

## 0. 工具链拓扑

```
GitOps 两层:
  节点层  Gitea k3s-nodes repo → Ansible（工作站 CLI 或 Semaphore 执行）→ 5 台节点
  K8s 层  Gitea k3s-admin repo → ArgoCD → 工作负载
通知: 节点层 audit 结果直接 curl ntfy（basic auth 同 alertmanager-ntfy 账号）
```

## 1. 变更执行 SOP（每次节点变更必走）

1. 改模板 → commit → push。
2. `ansible-playbook playbooks/site.yml --limit <node> --check --diff`（**必做，首跑判定 changed 的谜团靠它兜底**）。
3. `--limit` 单台灰度，顺序 agent03 → 01 → 04 → 02 → server01（server 一定留专属窗口）。
4. 每台后 configz 断言（`tools/verify_configz.py`）+ 无驱逐检查。
5. 回滚 = 恢复 `<file>.NNNN~` 备份 + 重启 k3s 服务。

## 2. k3s 服务生命周期（KillMode=process 的坑）

| 操作 | containerd | 运行中容器 |
|---|---|---|
| `systemctl restart k3s-agent` | **存活** | 不死（coredns uptime 实测无变化） |
| `systemctl stop k3s-agent` | **退出**（socket 拒连） | 变**孤儿进程继续跑**（crictl 不可用） |

* 孤儿容器的清理：crictl 不可用，只能按进程树 kill（见 §4）。
* server 重启 = API + etcd 中断 1–2 分钟；务必备 etcd 快照后执行。

## 3. kubelet 配置要点

* 唯一入口 `kubelet-arg: config=/etc/rancher/k3s/kubelet.config`；config.yaml 同目录 `config.yaml.d/*.yaml` 可做 drop-in（按字母序合并）。
* configz 验证：`kubectl get --raw /api/v1/nodes/<n>/proxy/configz`。**durations 的序列化**：90s→`1m30s`、720h→`720h0m0s`，断言要按实测值写。
* `enforceNodeAllocatable` 加 kube/system-reserved 前必须先配对应 cgroup，否则 kubelet 拒绝启动。只设 `[pods]` 最安全（预留照常生效为 Allocatable）。
* 新 evapoation 阈值生效前先看 MemAvailable：soft(1.5Gi) 要 < 当前值，否则即刻开始软驱逐。

## 4. 磁盘操作：三层 umount 障碍 + DS 行为

缩 `/var/lib/kubelet`（含 LV 缩容）时：

1. **业务 Pod 嵌挂**：drain 后消失。
2. **DaemonSet hostPath**（linstor-csi-node、promtail、metallb 等）：drain 不管 DS；`/etc/metallb` 这类挂载会挡 fsadm。
3. **容器 mount ns 持有**：`host /proc/mounts` 看不到；**fsadm 不可靠**（本环境误报过 /etc/metallb、/run）。
   唯一可靠排查法：
   ```bash
   MM=$(lsblk -n -o MAJ:MIN /dev/<device>)
   grep -l " $MM " /proc/[0-9]*/mountinfo     # 逐个看 cmdline，kill -9 孤儿持有者
   ```
* **DaemonSet 无视 cordon**（秒级重建）。正确顺序：
  `drain → systemctl stop k3s → force 删 DS Pod 对象(--force --grace-period=0 --wait=false) → umount(嵌套→父) → kill 孤儿 → 缩容 → start k3s → uncordon`
* 缩 ext4 用手工序列不经 fsadm：`e2fsck -f -y（rc=1=修复成功）→ resize2fs <size> → lvreduce --force`（fs 小于 LV 安全）。
* **在线扩容**（agent04 类，kubelet 在根分区）：纯增不减，全程零中断：
  `qm resize <vmid> <disk> +N → sgdisk -e → parted -s <dev> -a optimal resizepart 1 100% → partprobe → pvresize → lvextend -l +100%FREE → resize2fs`
  幂等陷阱：lvextend 无剩余时 rc=5 报错（非失败），pg 脚本要包 skip。

## 5. LINSTOR / DRBD

* place-count 2 + `quorum=majority` = 2/2 全票，任一台节点故障 → 14 卷 suspend-io 业务冻结。**决定性手段：tiebreaker / place-count 3**（big-change 前必补保护）。
* **QuorumSetBy=user 陷阱**：手工设过 `DrbdOptions/Resource/quorum` 的 RD 不会走 auto-tiebreaker（LINBIT 官方行为，1.31.1 修复）。`linstor rd list-properties` 可以看。
* `drbd.linbit.com/lost-quorum` taint 会在节点故障时打上（GPU 亲和 Pod 会 scheduling failure），**恢复后可能残留，手工 `kubectl taint node ... key-`**。
* linstor-csi-node / ha-controller 等容器会挂在 thin pool 配置上；删除 DS Pod 后 satellite 的 java、drbd-setup 等可以一并被 kill（back 引起 proxy 反应）。

## 6. 杂项（踩过的坑）

| 坑 | 教训 |
|---|---|
| `kubectl delete pod -n A x -n B y` | 多个 `-n` 只有最后一个生效——全删用 `-A --field-selector` |
| ansible 跨 host fact | 会被字符串化：flat fact / 比较按字符串做 |
| ntfy HTTP header | latin-1 编码限制，中文只能进 body；Title 用 ASCII |
| http-body 树挂 | structured container fsadm 检查尽信书 |
| `parted ---script --align` | Debian parted 长选项用 `-a`，`---` 双写会解析失败 |
| ArgoCD secret 轮换 | SEMAPHORE_ACCESS_KEY_ENCRYPTION 被 ArgoCD 换掉 → 项目 keys 全砖（克隆方能重建） |
| Gcr 镜像源 | gcr.io / gcr 相关公共镜像网络波动，403 时手动 `crictl pull` 或先降到 node 缓存 |
| 容器日志无间隔 | agent 节点 `/etc/logrotate.d/k3s` 缺失会无限长（已修） |

## 7. Semaphore / API 备忘

* 触发任务：`POST /api/project/{pid}/tasks {"template_id":…}`（不是 /templates/{tid}/tasks 之路径）
* template 建 POST 必带 `app: "ansible"`，否则跑时 `exec: no command`
* PUT 更新常不生效：删重建最省心
* inventory 用 `type=file` 指向仓库文件（static 内联会把 group_vars 游离）
* git 凭据存 `login_password` 类 key；SSH 认 hosts key（注意 known_hosts 自动 accept）
* failure 诊断流程：看任务 `status: error` 后拉 `/api/project/{pid}/tasks/{id}/output`

## 8. 常用命令速查

```bash
# 集群健康巡检
kubectl get nodes && kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl top nodes / kubectl get pods -A -o wide

# 配置审计
cd ~/Workspace/Misc/k3s-nodes && ansible-playbook playbooks/audit.yml -f 5

# 单节点变更
ansible-playbook playbooks/site.yml --limit k3sagent03 --check --diff
ansible-playbook playbooks/site.yml --limit k3sagent03

# LINSTOR 状态
kubectl -n piraeus-datastore exec deploy/linstor-controller -- linstor resource list

# k3s 日志（config.yaml 的 log=/var/log/k3s.log，journal 是空）
sudo tail -f /var/log/k3s.log
```
