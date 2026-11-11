# SPSS 32 私密备份 · 2026-11-11

本机 IBM SPSS Statistics 32 安装文件、注册表与环境配置的私密备份。原安装位置为 `G:\SPSS`。

- 源文件：**35,428 个 / 4,905,802,156 字节**。
- 注册表：**2,003 个键 + 17 个按值筛选的设置**。
- 完整 ZIP：**3,720,584,813 字节（3.47 GiB）**。
- ZIP CRC、全部源文件 SHA-256 及注册表导出 SHA-256：**通过**。

## 下载完整备份

进入 [backup-20261111 Release](https://github.com/brandhills286-collab/spss32-private-backup-20261111/releases/tag/backup-20261111)，下载全部 **4 个 `.partNNN` 分卷**、`release-parts.json` 和 `Join-Backup.ps1` 到同一文件夹。

在该文件夹打开 PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Join-Backup.ps1
```

脚本会先逐卷核对 SHA-256，再生成 **SPSS32_Backup_20261111.zip** 并核对完整包 SHA-256。它只合并文件，不安装软件、不导入注册表、不改系统配置，且拒绝覆盖已有输出。

GitHub 普通提交限制大文件，Release 单附件小于 2 GiB，因此完整 ZIP 以二进制分卷保存于此私密 Release。分卷不是多个独立 ZIP，须先合并。GitHub 自动生成的 Source code ZIP 仅包含本仓库说明文件，**不是 SPSS 完整备份**。

## 包含范围

SPSS 完整安装目录（含 Python/R/Java、许可文件及原有压缩文件）、原始安装程序、MSI/MST 安装缓存、用户配置/扩展/日志/恢复文件、共享 COM、快捷方式、已识别临时缓存、相关 Sentinel 许可状态、SPSS 引用的共享 VC++ DLL、专用 SPSS MCP 源码/venv/依赖及配置。

包内 `metadata/file-manifest.json` 提供所有源文件的原路径、包内路径、大小和 SHA-256；`metadata/registry-exports.json` 将 `.reg` 文件映射到原始键。

## 恢复范围与限制

先阅读 [RESTORE.txt](RESTORE.txt)。这是已识别文件/配置的实时备份，未经实际重装或换机恢复验证，不是整机镜像。许可文件已保留，不保证跨机器沿用激活；共享 MSI、VC++、许可数据与注册表不能无差别批量覆盖。MCP 的共享基础 Python 未复制，路径变化时需要重建 venv。未包含无关课程数据、其他账户/软件配置、NTFS 附加流或逐文件完整 ACL。

## 校验

完整 ZIP SHA-256：`a56afebea0404d8ca29214cba8019dbcd8c462ae93a79d3869f087299287e95a`。

参见 [SHA256SUMS.txt](SHA256SUMS.txt)、[verification.json](verification.json)、[backup-summary.json](backup-summary.json)。

GitHub 限制依据：[大文件文档](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)、[Release 附件文档](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)。
