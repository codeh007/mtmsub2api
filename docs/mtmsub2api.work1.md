# 痛点

1. https://github.com/codeh007/mtmwiki/issues/47 这个完整的开发和部署,周期比较长, 目前还不能完全实现.
2. 当前最紧急的任务是: https://sub2api.yuepa8.com/ 目前不具备`训练数据收集指引`功能, 需要尽快完成这个功能的开发和尽快部署.



## 难点

1. 已有的生产中的 https://sub2api.yuepa8.com/ 切换可能有风险. 毕竟用户正在使用. 我最终希望完成一键切换.
    1.1 用户无需修改 base_url 和 api_key, 依然可以完整 sub2api.yuepa8.com 提供的大模型api服务.
    1.2 sub2api 版本有更新,新版的功能升级风险, 建议升级为最新版, 但是应当先确认是否可以顺利升级而不会产生以为.至少确保用户依然可以正常使用服务而不会中断.(升级过程可以接受几分钟左右的中断, 一次性).


## 我建议的过程和步骤

1. 完成数据库的独立备份. 这是最终的兜底方案,也就是说万一出现意外,这是进行重建的前提.


## 使用 golang 完成基于反代的方式完成 大语言api调用的数据采集功能.

[相关参考文档]

- [训练数据收集指引](/workspace/mtmwiki/wiki/raw/训练数据收集指引.md) 必读

## 基于golang 反代收集大语言模型数据的可行性分析

[初步构想] 基于golang 实现`mtmllmapi` 命令. 使用方式:
```
mtmllmapi --upstream-server=https://sub2api.yuepa8.com/
```
功能是:
截获模型调用的api端点,将模型调用轨迹完整收集,并异步提交到 cloudflare worker 中的收集端点, 后续数据处理由 cloudfalre worker 端点进行处理, 例如使用 R2 存储原始数据,和脱敏数据.

...(待补充)

## 关于数据训练采集端点

在 /workspace/mtmnewapi 实现并确认数据采集端点的功能的正确性. 端点接受由 