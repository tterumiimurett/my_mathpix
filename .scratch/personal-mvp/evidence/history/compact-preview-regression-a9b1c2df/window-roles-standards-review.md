# Window roles — Standards review

结论：**最终 tip Standards 认可：无明确仓库规范违规，0 项 open。初始 1 项非阻断 P3 已修复。**

审查范围为固定 `22bf0fdc7f7d523f370cd6b05177243506e0c012...f12d2711cb3038e326b22e04ea4fced5539d5dbc` 的全部 15 个文件。只读审查；未运行构建、App、CUA 或读取私人容器。

随后只读核验 `f12d2711cb3038e326b22e04ea4fced5539d5dbc...01dffed1f9cd653c8c296c3dc6083863c7d04f1f` 的全部 3 文件小 diff；已确认当前 HEAD 为完整最终 SHA。此次只改测试等待复用和两份记录，生产代码未变。

依据：根 `AGENTS.md`、`CONTEXT.md`、`docs/agents/{domain,issue-tracker,triage-labels}.md` 和 ADR 0001–0006。ADR 0004/0005 仅涉及后续公开分发，本改动不触及；ADR 0006 明确覆盖 ADR 0002 的 Keychain 部分。

## 明确规范

未发现违规。原生 AppKit/SwiftUI 符合 ADR 0001；无沙箱、凭证或远端访问改动（ADR 0002/0003/0006）。Ticket 08 路径、claimed 状态、Comments/Answer 和 map 指针符合 issue-tracker 约定，保留真实桌面验收未完成的状态。新增生产与测试术语使用已有 Result Editor、Snippet、Recognition Attempt 等领域含义。

## 已修复的判断性建议

- **[P3] Duplicated Code — 合并测试中的完成等待。** `Sources/MyMathpix/Ticket04ResultEditorWindowSelfTest.swift:144–148` 新增的 `for _ in 0..<100 { if !model.isProcessing { break } ... }` 加 400 ms settle，与同文件 `77–82` 完全同形。建议抽取一个本文件私有 `waitForRecognitionAndWindowSettlement(model:)`，两场景共用，避免以后修改完成/稳定等待时漏改一处。这是指定 smell 基线下的维护建议，**不是已有仓库硬规则，也不阻断行为验收**。

  **已关闭：** `01dffed` 的成功/失败场景分别在当前第 77、139 行调用同一私有 helper（第 154–160 行）。helper 原样保留最多 100 次、每次 20 ms 轮询和之后 400 ms 稳定等待，没有新行为或新 smell。`green-loop.md:59–61` 记录修复后原 signed-window loop 和 diff 检查再次通过；这是实现者记录，本审查未自行重跑。

其余逐 hunk 检查未见可执行的 Mysterious Name、Feature Envy、Data Clumps、Primitive Obsession、Shotgun Surgery、Divergent Change、Speculative Generality、Message Chains、Middle Man 或 Refused Bequest。Presenter 两个角色 switch 分别负责显示副作用和 opener 选择；当前仅两种角色，未把强行抽象列作 Repeated Switches 问题。

真实桌面与最终签名候选验收仍由父任务完成；现有 signed-window 结果仅是支持性证据，不构成 Standards 违规或本审查的执行证明。
