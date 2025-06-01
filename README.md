# AutoLogin4HENU - 河大校园网自动登录脚本

**AutoLogin4HENU** 是一个针对河大（以及类似学校）校园网自动登录的脚本，适用于 OpenWrt 的BusyBox，你也可以在任何其他的 Linux 发行版使用它（需要有 curl、grep、sed、awk 等工具）。该脚本通过自动化操作，检测并处理校园网认证过程，让用户无需手动登录，轻松连接校园网络。

# **使用前请确保你已经仔细阅读本文档末的免责声明部分**

## 功能

- **自动检测**：检测是否为未登录状态（被重定向到认证页面）。
- **自动认证**：自动提交用户名和密码完成认证
- **日志记录**：所有认证过程都会被记录到日志文件，同时输出到终端（调试模式下）。
- **生产模式与调试模式切换**：可以在 `.env` 文件中设置 `MODE=debug` 或 `MODE=production`，控制输出信息的详细程度。

## 安装

1. **将脚本上传到路由器**

   使用 SCP 或 WinSCP 上传脚本到路由器的 `/usr/bin/campus_auth.sh`。
   可使用 `curl -o /usr/bin/campus_auth.sh https://raw.githubusercontent.com/SnowSwordScholar/AutoLogin4HENU/refs/heads/main/campus_auth.sh`

   ```bash
   chmod +x /usr/bin/campus_auth.sh
   ```

2. **配置环境变量**

   脚本会按照以下顺序查找配置文件：
   1. 命令行参数指定的文件（例如：`campus_auth.sh /path/to/config.env`）
   2. 当前目录下的 `.env` 文件
   3. 系统配置目录下的 `/etc/campus_auth.env`
   4. 脚本所在目录下的 `.env` 文件

   示例配置文件：

   `vi /etc/campus_auth.env`
   ```ini
   USERNAME=2023123456
   PASSWORD=your_password
   OP_SUFFIX=@henuyd     # 如果是校园运营商，默认为 @henuyd （henu移动）
   MODE=debug           # 可选值：debug 或 production
   ```

3. **手动测试脚本**

   在路由器终端运行脚本并查看输出：

   ```bash
   # 使用默认配置文件顺序
   /usr/bin/campus_auth.sh
   
   # 或指定特定的配置文件
   /usr/bin/campus_auth.sh /path/to/custom.env
   
   # 查看日志
   tail -f /tmp/campus_auth.log
   ```

   脚本运行后，会显示认证过程中的信息，并将所有日志保存在 `/tmp/campus_auth.log` 文件中。

4. **设置定时任务**

   如果一切正常，可以将脚本设置为定时任务，每 10 分钟自动执行一次：

   ```bash
   echo '*/10 * * * * /usr/bin/campus_auth.sh >> /tmp/campus_auth.log 2>&1' >> /etc/crontabs/root
   /etc/init.d/cron restart
   ```

## 参数说明

- **USERNAME**：你的校园网账号（学号等）。
- **PASSWORD**：你的校园网密码。
- **OP_SUFFIX**：运营商后缀（默认为 `@henuyd`，如果你是其他运营商，请修改）。
- **MODE**：运行模式，`debug` 模式将输出更多调试信息；`production` 模式仅记录日志。

## 使用说明

1. **调试模式**：在 `.env` 文件中将 `MODE` 设置为 `debug`，该模式下脚本会同时输出日志到终端和文件。
2. **生产模式**：默认模式，日志仅输出到文件，适用于长期运行。

## 示例日志

```bash
[2025-06-01 13:19:55] 捕获门户: 172.29.35.36  ip=10.16.151.31  ac=HD-SuShe-ME60
[2025-06-01 13:20:00] → check-only: http://172.29.35.36:8882/user/check-only
[2025-06-01 13:20:15] → auth: http://172.29.35.27:8088/aaa-auth/api/v1/auth
[2025-06-01 13:20:20] → quickauth: http://172.29.35.36:6060/quickauth.do?userid=2023123456@henuyd&passwd=your_password&wlanuserip=10.16.151.31&wlanacname=HD-SuShe-ME60
[2025-06-01 13:20:25] ✔ 认证成功
```

## 注意事项

- 请确保你的路由器上已安装 `curl`、`grep`、`sed`、`awk` 等工具，它们是脚本运行的必要依赖。
- 如果校园网的认证系统发生更改，只要更新 `.env` 文件中的 IP 或路径，脚本通常会继续正常工作。
- 如果学校每月更换 IP 地址，只需调整 `.env` 文件中的相关参数即可。

## 贡献

欢迎贡献代码和建议！如果你遇到问题或者有改进意见，欢迎通过 GitHub Issues 提交。

## License

此项目使用 [MIT License](LICENSE) 进行授权。

## 免责声明

1. **项目性质声明**
   本开源项目仅为技术学习交流用途，旨在研究网络通信协议原理，不涉及任何商业用途或盈利目的。使用者应遵守所在学校网络管理规定，仅限个人学习研究使用。

2. **合法使用条款**
   使用者必须确保：
   - 已获得校园网服务方的明确授权
   - 不绕过任何付费认证机制
   - 不干扰校园网正常服务运行
   - 不进行高频请求等可能被认定为网络攻击的行为

3. **开发者责任限制**
   开发者不对以下情况负责：
   - 使用者违反《网络安全法》第12条、第27条等规定的行为
   - 因使用脚本导致的账号封禁等后果
   - 被用于网络攻击、数据窃取等违法用途
   - 任何间接损失或连带责任

4. **使用者义务**
   使用者承诺：
   - 遵守《网络安全法》第12条关于网络行为规范的规定
   - 不将脚本用于破坏计算机信息系统（刑法第286条）
   - 若用于教学机构，需事先获得网络管理部门书面许可

5. **免责条款**
   根据《网络安全法》第10条、第22条规定：
   - 本项目不提供任何形式的使用担保
   - 使用者需自行承担所有风险
   - 发现安全漏洞应及时通过正规渠道向校方报告

6. **终止使用条款**
   如学校网络管理部门提出书面要求，开发者有权立即停止项目维护，使用者应无条件停止使用。

7. **法律适用**
   本声明依据《中华人民共和国网络安全法》《民法典》等法律法规制定，争议解决适用中国法律。
