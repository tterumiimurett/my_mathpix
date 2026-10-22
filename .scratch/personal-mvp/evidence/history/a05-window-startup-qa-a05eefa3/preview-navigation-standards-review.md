# Preview navigation — independent Standards review

**结论：最终 tip `cd826ad8da5df3f0c243897de448be5bf84d5121` Standards 认可，0 open：0 项 documented-standard 违规；0 项 smell finding。**

固定范围：`git diff 01dffed1f9cd653c8c296c3dc6083863c7d04f1f...54135e2f761432585d47e727e5f67faf3ccd2e85`；提交为 `a264f77` RED 和 `54135e2` 修复。已核对完整 tip SHA、全部六文件 diff 及相关实际上下文；不重审此前已清零的源代码。

追加只读核验 `54135e2...cd826ad8da5df3f0c243897de448be5bf84d5121` 的全部三文件小 diff。生产 ContentView 两端 Git blob 同为 `28a722dd7fb2031587c15039ea94c46fb38da440`；该追加仅测试同步握手和记录。

规范依据沿用已读根 AGENTS/CONTEXT、docs/agents 三份规范及相关 ADR；另已读取 code-review SKILL 的完整 smell 基线。新增记录符合本地 Comments/Answer 约定，保留真实新候选验收未完成状态。没有新增凭证、历史持久化、网络或沙箱行为。

- **生产 gate：** `ContentView.swift:213–220` 仍要求 `.other`、main frame 和现存离线 URL policy；仅删除不能表达重叠请求的单次位。`MarkdownRenderer.swift:3–7,34` 的 about/file policy 和 CSP、内容转义/表格净化，以及 WK 禁自动弹窗配置未改。当前生成文档没有新增脚本或导航入口；未发现此次放宽引入的可执行导航问题。
- **竞态前提：** 测试 `Ticket04ResultEditorWindowSelfTest.swift:88–103` 观察真实隐藏 WK 的 `isLoading`，并在前提缺失时明确失败；第 194–213 行读取实际 DOM，要求 fixture、公式和表格同时存在。它不是私有 coordinator 状态镜像。`isLoading` 只证明载入中，不能单独证明某个 policy callback 尚未执行，因此该测试仍依赖实际调度；两次同命令 RED 和单变量 gate 修复 GREEN 是支持证据，不能声称调度已完全确定化。
- **Mock 同步边界已消除：** 追加 diff 的 `complete()` 取得已安装 continuation 才先清空、resume 并返回 true；pending loop 只有同时 `webView.isLoading` 和成功 release 才认可前提，失败继续 poll。没有盲目提前释放，也不再依赖 MainActor FIFO。仍保留上项关于具体 WebKit policy callback 顺序的证据边界，不产生新 finding。
- **恢复边界：** compact credential-error sheet 断言保留（第 159–181 行）；未增加推测性 process-crash 恢复，也未把未改的旧恢复缺口列作新 finding。
- **smells：** 逐 hunk 核对全部十二项：Mysterious Name、Duplicated Code、Feature Envy、Data Clumps、Primitive Obsession、Repeated Switches、Shotgun Surgery、Divergent Change、Speculative Generality、Message Chains、Middle Man、Refused Bequest，均无可执行 finding。

测试限定：本审查只读，未构建/运行 App、测试或 CUA。GREEN 文档记录 signed-window、Ticket 03 和 diff 检查通过，本报告仅核对记录与实现相符。当前 sealed a9 未变；锁屏下的真实桌面、菜单、CmdTab/live 门禁仍未完成。Standards 认可不等于这些门禁通过。

最终追加记录报告同一公共 signed-window 命令再次双屏 pending/fixture/formula/table/roles/sheet GREEN 与 diff 检查通过；未重跑无关套件，本审查也未自行执行。
