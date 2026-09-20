# Go/ezgo 后端初始化架构基线

这是可选的设计参考，不是自动执行脚本。目标是让业务调用链直接可读，复用已有框架，减少初始化时重复造轮子。

## 1. 启用条件与边界

| 已确认条件 | 本参考的处理方式 |
|---|---|
| 尚未选择语言，或只选择业务单体 | 不推断Go，不加载Go初始化约束 |
| 已选择Go，框架未定 | 可推荐ezgo作为候选，说明取舍，不能视为已确认 |
| 已选择Go且确认采用ezgo脚手架 | 加载本参考，核对当前源码与版本后按需采用 |
| 已选择Go及其他框架 | 保留已确认框架，采用通用架构流程，不强行改为ezgo |
| 已采用ezgo，但数据库未定 | 先整理通用分层；Mongo专属内容不启用 |

用户本轮明确决定与现行已批准技术设计均可作为确认依据，不重复询问已有确认。单体、BFF、网关是职责或部署边界，不是编程语言。三入口不是强制要求，多入口也不等于微服务。

本参考不授权创建工程、安装依赖、运行外部脚手架、迁移数据库、提交Git或发布。架构Skill保持assess/review只读、design只写授权文档的边界；进入实施需要相应用户授权。已有项目不得因采用参考而被重新生成或覆盖。

## 2. 先核对来源，再选择保留项

记录实际读取的脚手架来源、提交或文件指纹、Go工具链、ezgo、Gin、CLI及数据库驱动版本。维护者提供的外部脚手架优先用于启动和公共模块，已有业务项目用于理解分层及阅读习惯，不复制其客户数据、地址、密钥或权限特例。

经验来源已验证过Go业务单体、ezgo HTTP和Mongo DAO、真实会话、事务、契约及隔离集成；这不证明所有新版本或其他项目已兼容。精确版本从目标go.mod/go.sum及实际依赖源码核验，不使用latest，不把某次验证版本永久冻结为全局要求。无法取得依赖时列出准确未知项，不猜测方法签名或默认行为。

逐项输出四种信息：当前源码事实、候选约定、已确认规则、需整改差异。新项目按批准规则实施；存量项目另列兼容与迁移范围，不能批量覆盖旧合同。

## 3. 应用结构与职责

业务应用放在项目既定的`development/backend/apps`中，各应用独立module、依赖、配置、构建与测试。名称和module由项目确认，已有路径不因本参考重命名。应用间通过API、RPC或消息协议协作，不创建shared-code等共享应用容器。

以下是应用内部可用目录及职责，不是一次性预建清单：

| 位置 | 职责 |
|---|---|
| main.go、internal/bootstrap | 框架启动与必要配置检查，bootstrap只在确有适配时存在 |
| command/commands.go | CLI命令注册、读取参数、调用任务 |
| command/logic/业务.go | 命令的实际维护任务 |
| controller/route/入口 | InitRoute显式注册路由和中间件 |
| controller/v1 | HTTP参数绑定、调用Service、统一响应 |
| service/业务.go | 权限、业务校验、事务编排、DTO转换 |
| dao/http、dao/mongo | 已选外部服务和数据库的具体访问 |
| model/mreq、model/mresp | 请求与响应DTO |
| model/mmongo | 选用Mongo时的持久实体 |
| common/pconst | 业务枚举、集合或连接标识、错误码等实际常量 |
| internal/extbase | 必要的绑定、错误、上下文、鉴权薄适配，不复制框架 |
| configs | 框架与应用实际读取的配置，秘密通过批准渠道注入 |
| cmd、internal/verification、docs | 独立契约／验收工具和接口文档，按需求建立 |
| tests | 跨包与集成测试；包内单元测试可就近放置 |

同一业务名贯穿路由模块段、Controller、Service、DAO和Model文件；文件使用snake_case，导出方法使用PascalCase。不另起领域目录，不为了层数预建空壳DAO。禁止无业务收益的泛型Repository、Scope、工厂、Manager和重复注册表。

## 4. 启动、命令与配置

- main优先复用`serv.NewApp()`、`HTTP(name, address, InitRoute)`与`WithCLI`。HTTP引擎走框架`NewGin`，不绕过框架另写生产`gin.New()`和HTTP生命周期。
- 核验当前版本`Run`、`Start`的真实行为；监听、停止信号、关闭回调和连接池交给框架。不要从方法名字推断三入口是否同时启动，也不要复制某项目的Start实参。
- CLI只读命令参数，再调用`command/logic`同名业务任务；无业务命令时使用空列表，不保留demo命令。`cmd/verify`不替代正式CLI接入。
- 日志使用ezgo日志；框架提供Trace时接通初始化与context传递，是否开启由环境配置决定。request_id是一次请求编号，不等于分布式Trace。
- 配置中的监听地址、超时、数据库名、HTTP路径、日志及Trace开关必须有真实消费者。缺少必要配置明确报错，不能静默连接示例环境。
- 健康检查按实际依赖设计：存活不代表数据库就绪。启动失败、未知命令、端口冲突和SIGTERM关闭均要实测。
- 不记录密码、会话令牌、完整敏感请求；不复制统一默认密码。公共框架修复先提供复现、范围、版本与tag／推送范围，取得明确授权后进行；旧tag不可覆盖。

## 5. 请求流转与接口契约

调用链保持`Route → Controller → Service → DAO → Model`。Controller绑定具体Req，使用保留取消与追踪信息的context调用Service。Service首参是`context.Context`，业务入参为明确DTO指针，返回明确Resp和error；不要把Gin Context传入DAO。

业务方法X对应`mreq.XReq`与`mresp.XResp`。独立类型直接命名，共享字段可用同名类型别名，不复制整套字段；只有error的动作不造空Resp。Mongo内部查询条件和持久实体按职责复用，不机械套公开HTTP DTO名称。

新接口按`/应用标识/范围/版本/模块/行为`组织，模块、行为及JSON字段使用snake_case。api、web、admin只是按职责选择的范围示例；相同Service合同在不同范围保持版本后路径一致。对象ID放GET查询或POST JSON，不从任意header推断内部通道。

GET不产生业务写入；写动作使用显式POST命令。升级V2时新增对应Controller、路由、Service V2方法和必要DTO，不能覆盖旧版本合同。兼容性可选字段扩展也须明确评审、记录旧客户端行为，不把所有变化都当作安全兼容。

请求校验由binding及Validate维护，区分缺失、空值、false、零值及非法枚举。鉴权在实际路由组和业务范围执行，绑定函数不能混入认证或事务。公开入口和内部入口的认证、网络及数据范围按项目批准规则定义，禁止照搬内部api免鉴权。

业务状态与错误码集中在common/pconst。若采用“三位系统＋两位功能＋两位错误点”，系统码由新项目确认，不能沿用来源项目编号。HTTP状态、成功码、字段错误、分页空数组和无对象语义须有明确合同，不把外部原始错误码未经设计直接暴露。

operation_id表示稳定业务操作，request_id表示一次HTTP请求。两者不能互相替代。文件导出显式返回下载流，失败不能包装为成功文件。

实际路由只在controller/route注册；不增加common/pconst/route.go或手写Req/Resp名单。OpenAPI从实际源码提取并做契约校验，运行代码不读取文档来决定鉴权、参数或业务分发；文档工具不进入生产执行链。

## 6. 最小纵向示例：查询公告

这是脱敏的设计示例，不是可直接运行的工程。只有项目确有公告模块时才使用；示例中的notice不构成新增业务要求。具体框架签名、导入路径、主体和响应封装以目标版本为准。

| 调用位置 | 方法与参数 | 处理与结果 |
|---|---|---|
| controller/route/web/route.go | groupWebV1.GET("notice/list", v1.GetNoticeList) | 组前缀、登录中间件来自已确认入口配置 |
| controller/v1/notice.go | GetNoticeList(c *gin.Context) | BindQueryParams绑定GetNoticeListReq，再调用Service |
| model/mreq/notice.go | GetNoticeListReq：Page、PageSize、Keyword | 显式json/form/binding标签，边界由合同确定 |
| service/notice.go | GetNoticeList(ctx context.Context, req *mreq.GetNoticeListReq) (*mresp.GetNoticeListResp, error) | 从可信上下文取得可见范围，校验并构造FindNoticeReq |
| dao/mongo/notice.go | GetNoticeList(ctx context.Context, req *mreq.FindNoticeReq) ([]mmongo.Notice, int64, error) | 同一筛选条件查列表及计数，保留context |
| model/mresp/notice.go | GetNoticeListResp：List、Total | Service映射持久模型，排除内部或敏感字段 |
| Controller返回 | bcontroller.Json(c, err, response) | 按应用合同处理HTTP状态、业务码和请求编号 |

这个查询不新建事务、审计集合或消息任务。若具体业务要求记录阅读，另设显式阅读写命令，不在列表查询中悄悄更新已读。

Mongo DAO的阅读布局示例，前提是已确认当前ezgo具有这些字段，且pconst标识和配置键已在目标项目定义：

```go
type Notice struct {
    mongo.Mongo
}

// NewNotice 创建公告集合访问对象。
func NewNotice() *Notice {
    r := &Notice{
        mongo.Mongo{
            Key:        pconst.MongoKey,
            Database:   config.AppGetString("mongo_database"),
            Collection: pconst.CollectionNotice,
        },
    }
    return r
}
```

这是局部声明示例，省略导入和标识定义以避免伪造完整可编译能力；实际实施须补齐真实配置并运行gofmt、构建和对应DAO测试。

## 7. DAO与一致性

HTTP DAO嵌入框架HTTP类型，New对象直接设置服务配置名，复用ezgo HTTP请求、地址、路径和超时；公开方法保持同名Req/Resp。检查非成功响应、解码失败、context取消及超时，不能为绕过框架问题偷偷另造客户端。非幂等调用不盲目自动重试。

选用Mongo时才启用以下约定：

- Key是连接配置名、Database是物理库名、Collection是集合名，三者分开；HTTP入参不能选择数据库。DAO直接嵌入框架Mongo，按上面的New风格构造，不增加初始化层。
- 列表与计数共用筛选；FindOne区分不存在与查询失败；条件更新检查实际匹配或修改结果。持久模型显式bson标签，基础模型按真实接口适配，不能由标签推定索引已创建。
- Service编排事务，全部DAO透传同一会话context，不在DAO里新建Background或连接。框架集合会话对象不自动等于已开启事务。
- 存在并发写时按稳定ID、期望版本或状态更新，依业务采用唯一索引、跨记录共同冲突点和幂等键；唯一键存在不等于所有竞争条件已解决。
- 事务回调可能重试，稳定编号在回调外生成；外部HTTP、发送和不可回滚副作用不放入回调。提交结果未知先核对操作结果。
- 需要业务审计或可靠消息时与业务结果在设计的原子边界落库；失败和重复尝试按实际结果记录，敏感字段白名单过滤。不对所有查询强制加审计和队列。
- 索引／Schema初始化单独维护，执行前核对既有数据和授权；历史保留期限与访问范围按业务确定，不照搬永久保留规则。金额／小时等精度、纯日期与时间、未知历史字段均按合同处理。

## 8. 命名、阅读与注释

- 新业务文件和协议字段使用snake_case，Go导出名使用PascalCase，ID等缩写统一；旧基础库标识通过显式适配，不顺手改公共库。
- 时间点使用`*_at`，纯日期使用`*_date`；不伪造未知时间，不因为字段名或原型文案把ObjectID称为UUID。
- 生产文件公开方法在前、私有方法在后，组内保留业务顺序；注释随方法移动，包级变量初始化顺序不变。
- 多字段对象、嵌套结构、CLI命令与Flag逐项分行，多语句函数不挤成一行；按结构而不是按字符长度决定展开。gofmt负责基础格式，另检查阅读布局。
- 方法注释用紧贴声明的`//`，公开方法以方法名开头并写浅显中文。关键权限判断、事务重读／重试、流程推进和消息／审计提交前解释做什么及为什么；不逐行翻译语法，不机械凑注释数量。
- 字段注释解释业务含义、来源、可选性及精度。持久实体不直接返回前端，内部筛选不充当请求绑定对象。

## 9. 分阶段初始化与验收

1. 记录已确认语言、框架、应用标识、入口职责、数据库选择及源码基线；未知项保持未知，划清本轮设计或实施授权。
2. 对照脚手架列保留、裁剪、补齐、待核验；删除范围内无用demo时保护用户文件，不复制凭据。
3. 获得实施授权后先验证最小启动、CLI、框架配置及健康检查；再贯通一个真实业务的Route、Controller、Service、DAO和DTO，不预造未来模块。
4. 按实际风险验证：格式／阅读布局、类型与构建、参数边界、主体与跨范围访问、HTTP超时取消、数据库查询、版本冲突、重复操作、事务重试及审计原子性。
5. 运行支持的启动模式、错误命令、端口冲突和SIGTERM；核对资源释放、配置真实生效、日志脱敏和Trace上下文，不能只测包结构。
6. 使用隔离数据库与测试存储；Mongo事务使用可用副本集实测，不清空用户验收库。包内单元测试就近放置，跨包和集成测试可放tests，不强制全搬到一个目录。
7. 按已选工具运行gofmt、go test、go test -race、go vet、go build以及契约一致性检查。正式依赖验证可用GOWORK=off排除工作区替换影响；明确替换测试与发布模块测试的区别。命令以实际项目脚本为准，不假装所有项目已有cmd/verify。
8. 输出修改范围、配置与契约、实际通过项、未验证项和公共规范影响；文档完成、编译通过、业务测试、人工验收和已部署分别记录。云环境和真实第三方条件不足不阻止已授权的隔离本地开发，也不能因此宣称线上通过。

可复用的是架构与验证方法。客户名称、个人私有路径、样例账号、系统码、固定成功码、端口、密钥、内部api例外、审批角色及历史留存制度都不是本基线默认值。
