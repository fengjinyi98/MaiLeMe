//
//  Constants.swift
//  MaiLeMe
//
//  Created by Codex on 2026/2/28.
//

import Foundation

/// 全局常量集中管理，避免魔法数字和散落文案。
enum AppConstants {
    /// 小组件共享与深链相关常量。
    enum Widget {
        /// 小组件 Kind 标识：用于刷新指定小组件时间线。
        static let rationalDefenseKind = "MaiLeMeRationalDefenseWidget"
        /// 小组件 Kind 标识：今日行动卡。
        static let todayActionKind = "MaiLeMeTodayActionWidget"
        /// 小组件 Kind 标识：吃灰警报卡。
        static let idleAlertKind = "MaiLeMeIdleAlertWidget"
        /// App Group：用于 App 与 Widget 共享快照数据。
        static let appGroupIdentifier = "group.com.fengjinyi.maileme"
        /// 小组件快照在共享 UserDefaults 中的键名。
        static let snapshotDefaultsKey = "widget.rationalDefense.snapshot.v1"
        /// 小组件触发 App 跳转时使用的 URL Scheme。
        static let deepLinkScheme = "maileme"
        /// 小组件跳转小黑屋路由 host。
        static let darkRoomHost = "darkroom"
        /// 小组件跳转榨干机路由 host。
        static let extractorHost = "extractor"
        /// 深链查询参数：聚焦类型。
        static let focusQueryName = "focus"
        /// 深链查询参数：物品 ID。
        static let itemIDQueryName = "itemID"
        /// 深链查询参数：榨干机入口动作（详情/挽救）。
        static let extractorEntryQueryName = "entry"
        /// 榨干机深链入口：详情页。
        static let extractorEntryDetail = "detail"
        /// 榨干机深链入口：吃灰挽救页。
        static let extractorEntryRescue = "rescue"
    }

    /// 本地通知相关常量。
    enum Notification {
        /// 轻提醒阈值：连续未使用天数达到该值时提醒。
        static let lightIdleDays = 7
        /// 强提醒阈值：连续未使用天数达到该值时提醒。
        static let strongIdleDays = 30

        /// 提醒触发时间（本地时区）。
        static let reminderHour = 20
        static let reminderMinute = 30

        /// 通知标题。
        static let title = "买了么提醒"
        /// 冷静期结束后，首次决策提醒延迟（秒）。
        static let cooldownDecisionFollowupDelay: TimeInterval = 24 * 60 * 60
        /// 吃灰处置追提醒天数（用户点击“7天后再提醒我”时使用）。
        static let rescueFollowupDays = 7
    }

    /// UserDefaults 键名集中管理，避免散落硬编码。
    enum UserDefaultsKeys {
        /// 首次引导是否已展示。
        static let hasSeenOnboarding = "onboarding.seen.v1"
        /// 数据迁移当前版本号。
        static let dataMigrationVersion = "data.migration.version"
    }

    /// 毒舌文案池：统一管理通知、仪式页、挽救页、复盘页的“网感文案”。
    enum RoastCopy {
        /// 打卡仪式文案组合。
        struct CheckinBundle {
            let title: String
            let subtitle: String
            let badge: String
        }

        /// 冷静期决策文案组合。
        struct DecisionBundle {
            let title: String
            let subtitle: String
            let actionTitle: String
        }

        /// 新文案引擎解析器：兼容层优先走结构化资源，初始化失败时再保守回退到旧常量池。
        private static let resolver: CopyResolver? = {
            do {
                let library = try CopyLibraryLoader(bundle: .main).load()
                return CopyResolver(
                    library: library,
                    memoryStore: CopyMemoryStore()
                )
            } catch {
                // 兼容层不能因为资源异常直接把旧流程打挂，调试环境先抛断言帮助定位。
                assertionFailure("毒舌文案解析器初始化失败：\(error.localizedDescription)")
                return nil
            }
        }()

        // MARK: - 通知文案
        /// 轻提醒文案模板（第一个参数：物品名；第二个参数：吃灰天数）。
        private static let lightTemplates: [String] = [
            "你的 %@ 已经 %@ 天没碰了，今晚打个卡不过分吧？",
            "%@ 已经静置 %@ 天，再放下去都要进博物馆了。",
            "提醒一下：%@ 已经吃灰 %@ 天，别只会下单不会使用。",
            "%@ 连续 %@ 天未激活，建议今晚安排 20 分钟复活。",
            "你买 %@ 已经过了 %@ 天“冷宫期”，该轮到它上岗了。"
        ]

        /// 强提醒文案模板（第一个参数：物品名；第二个参数：吃灰天数）。
        private static let strongTemplates: [String] = [
            "%@ 已经落灰 %@ 天，建议直奔二手平台回血。",
            "你和 %@ 已经 %@ 天没互动了，这段关系还要继续吗？",
            "%@ 吃灰 %@ 天：当初的“提升效率”计划还在吗？",
            "%@ 已闲置 %@ 天，再拖下去转手价只会继续打折。",
            "%@ 落灰 %@ 天，别让“买来提升自己”变成年度笑话。"
        ]

        /// 冷静期结束提醒文案（参数：物品名）。
        private static let cooldownReadyTemplates: [String] = [
            "冷静期已结束：%@，现在请用理性而不是手速做决定。",
            "%@ 已出小黑屋，轮到你决定是省钱还是下单。",
            "提醒：%@ 到期了，今天必须给个说法。",
            "%@ 冷静计时归零，审判席已经就位。",
            "%@ 进入可决策阶段：要么关单，要么认购。"
        ]

        /// 冷静期结束后未决策的追提醒文案（参数：物品名）。
        private static let cooldownFollowupTemplates: [String] = [
            "%@ 到期后你还没决策，是准备拖到下次冲动吗？",
            "24 小时过去了，%@ 仍在等待判决。",
            "还没决定 %@？拖延也是一种消费陷阱。",
            "%@ 已经在审判席坐了一天，法槌等你落下。",
            "你还没给 %@ 定性：刚需，还是情绪消费？"
        ]

        /// 吃灰处置追提醒文案（第一个参数：物品名；第二个参数：吃灰天数）。
        private static let rescueFollowupTemplates: [String] = [
            "%@ 你说 %@ 天后处理，今天该兑现了：要么打卡，要么上闲鱼。",
            "%@ 已经吃灰 %@ 天，再拖就真的只剩情怀了。",
            "提醒：%@ 的处置倒计时到点了，不挂闲鱼留着当展品吗？",
            "%@ 处置提醒触发：已闲置 %@ 天，给它一个命运结局。",
            "%@ 还在家里占位 %@ 天，今天请做出处理动作。"
        ]

        // MARK: - 冷静期仪式文案
        private static let decisionSavedBundles: [DecisionBundle] = [
            DecisionBundle(
                title: "理性胜利，冲动当场下线",
                subtitle: "你把“想买”变成了“省下”，这波自控力可以发朋友圈。",
                actionTitle: "继续克制"
            ),
            DecisionBundle(
                title: "手刹拉满，钱包续命成功",
                subtitle: "这一单你没下，但未来几次焦虑你提前化解了。",
                actionTitle: "继续守住"
            ),
            DecisionBundle(
                title: "审判通过：消费冲动败诉",
                subtitle: "你不是买不起，而是这次终于没被情绪牵着走。",
                actionTitle: "下一件也稳住"
            )
        ]

        private static let decisionPurchasedBundles: [DecisionBundle] = [
            DecisionBundle(
                title: "决策已落地，接下来拼回本",
                subtitle: "既然买了就狠狠干活，别让它有机会继续吃灰。",
                actionTitle: "去榨干机打卡"
            ),
            DecisionBundle(
                title: "单已确认，后续只看利用率",
                subtitle: "钱已经花了，现在目标很明确：尽快打到低单次成本。",
                actionTitle: "立刻去打卡"
            ),
            DecisionBundle(
                title: "购买生效，进入回本赛道",
                subtitle: "从现在开始，它的每次使用都在替你挽回冲动成本。",
                actionTitle: "开始榨干"
            )
        ]

        private static let decisionSavedRoastTemplates: [String] = [
            "你的理性刚刚全票通过，冲动消费被请出群聊。",
            "这次你赢得很体面，钱包也终于有了发言权。",
            "你没买，但你把未来的后悔也一起删单了。"
        ]

        private static let decisionPurchasedRoastTemplates: [String] = [
            "既然买了就狠狠干活，下次见面只接受“已回本”。",
            "钱已经付出，接下来用行动把这笔账掰正。",
            "不评价买不买，先把“买后吃灰”这条路彻底封死。"
        ]

        private static let decisionSavedOutcomeTemplates: [String] = [
            "冷静期成功忍住没买，直接省下一笔。",
            "冷静期到期后选择不买，这次理性胜出。",
            "你把冲动按住了，这笔预算成功留在账户里。"
        ]

        private static let decisionPurchasedOutcomeTemplates: [String] = [
            "冷静期结束后理性买入，已进入榨干机计划。",
            "最终选择购买，后续将通过打卡拉低单次成本。",
            "决策为购买，下一阶段目标是快速回本。"
        ]

        // MARK: - 打卡仪式文案
        private static let checkinFirstUseImmediateTitles: [String] = [
            "上手即开张，这波很会买",
            "到手就开工，效率人设稳住了",
            "刚买就用上，这单算你下对了"
        ]

        private static let checkinFirstUseImmediateSubtitles: [String] = [
            "买完马上用，钱包看了都想给你点赞。",
            "你没有给它落灰机会，这种执行力很值钱。",
            "这波不是冲动消费，是即买即用的高效兑现。"
        ]

        private static let checkinFirstUseLateTitles: [String] = [
            "吃灰一个月，终于被你救活",
            "晚到总比不到好，今天算正式开张",
            "这件资产总算结束“摆件生涯”"
        ]

        private static let checkinFirstUseLateSubtitles: [String] = [
            "拖了 %@ 天才开封，但今天这下算是把面子挣回来了。",
            "沉默 %@ 天后终于开工，你这波算是及时止损。",
            "%@ 天后才首刷，不过现在开始连击还来得及。"
        ]

        private static let checkinFirstUseNormalTitles: [String] = [
            "首次打卡到账",
            "开封成功，这单开始回血",
            "第一滴使用记录已入账"
        ]

        private static let checkinFirstUseNormalSubtitles: [String] = [
            "比继续落灰强太多，今天这一用很争气。",
            "终于不是“买来收藏”，从今天开始算价值。",
            "第一下很关键，后面继续打卡才是王道。"
        ]

        private static let checkinHeavyRevivalTitles: [String] = [
            "重度吃灰逆转成功",
            "长期闲置回坑，今天算翻盘",
            "你把老库存硬生生拉回战场"
        ]

        private static let checkinHeavyRevivalSubtitles: [String] = [
            "沉寂 %@ 天后终于复活，资产没有白买。",
            "断更 %@ 天后恢复使用，这波是实打实的自救。",
            "闲置 %@ 天的东西被你重新激活，血赚一次后悔值回收。"
        ]

        private static let checkinMidRevivalTitles: [String] = [
            "拖延症被你反杀",
            "中场回归，这波连击重启",
            "停更期结束，进度条继续往前"
        ]

        private static let checkinMidRevivalSubtitles: [String] = [
            "停摆 %@ 天后重启使用，这次继续连击别断。",
            "空窗 %@ 天后重新上手，今天这一刷很关键。",
            "你把 %@ 天的空档补上了，继续用才能真正回本。"
        ]

        private static let checkinSteadyTitles: [String] = [
            "节奏在线，成本在掉",
            "稳定输出，回本在路上",
            "保持连击，单次成本继续塌缩"
        ]

        private static let checkinSteadySubtitles: [String] = [
            "你在稳定输出，单次成本正在被你按着打。",
            "今天继续 +1，离“买值了”又近一步。",
            "节奏保持住，这件东西会越来越像刚需。"
        ]

        private static let checkinNormalTitles: [String] = [
            "今日打卡，继续回血",
            "这波打卡有效，进度继续推进",
            "又一笔使用记录到账"
        ]

        private static let checkinNormalSubtitles: [String] = [
            "这波使用很关键，你又把冲动消费扳回一城。",
            "只要持续打卡，后悔值就会被一点点摊薄。",
            "今天这次使用不惊艳，但对回本非常关键。"
        ]

        private static let checkinFirstRoastTemplates: [String] = [
            "首刷到账，这件东西终于不是家里最贵摆件了。",
            "第一刷落地，买它这件事总算有了证据链。",
            "开张成功，冲动消费风险值立刻下调。"
        ]

        private static let checkinBigMomentRoastTemplates: [String] = [
            "你把吃灰库存救回来了，这波比捡钱还狠。",
            "这件旧库存被你硬核复活，操作含金量很高。",
            "高危吃灰资产成功回坑，今天这下很涨士气。"
        ]

        private static let checkinHighUsageRoastTemplates: [String] = [
            "打卡强度离谱，物品都怕你不给它下班。",
            "你这使用频率，不回本都说不过去。",
            "持续高频输出，单次成本已经在地板上摩擦。"
        ]

        private static let checkinDefaultRoastTemplates: [String] = [
            "继续连击，别让它回到“买前刚需、买后装饰”的老路。",
            "打卡别断更，断一次就给吃灰留了口子。",
            "每一次使用都在给过去的冲动消费还债。"
        ]

        private static let checkinShareClosingTemplates: [String] = [
            "你也来试试，别让买过的东西继续吃灰。",
            "欢迎加入“买了就用”的反吃灰行动。",
            "今天开始，把冲动消费改造成高利用资产。"
        ]

        // MARK: - 吃灰挽救文案
        private static let idlePrimaryLightTemplates: [String] = [
            "关系还没凉透，今晚用一次就能续命。",
            "还在可救窗口期，打一针“使用记录”马上回温。",
            "这会儿拉回来最划算，再拖就进重症区。"
        ]

        private static let idlePrimaryWarmTemplates: [String] = [
            "你俩还不算陌生，赶紧打卡别让它转正成摆件。",
            "还处在回坑黄金期，今天动一下就能翻盘。",
            "这段关系还有救，别让“再等等”变成永久冷战。"
        ]

        private static let idlePrimaryMidTemplates: [String] = [
            "它不是装饰品，你也不是样板间策展人。",
            "再放下去就要被归档成“年度冲动纪念品”。",
            "进入中度吃灰区了，再拖只会越来越难回坑。"
        ]

        private static let idlePrimaryHeavyTemplates: [String] = [
            "吃灰一个月了，不放闲鱼是准备传家吗？",
            "现在不处理，后面只会在“后悔”和“折价”里二选一。",
            "已经到重度阶段，今晚不打卡就该考虑转手了。"
        ]

        private static let idlePrimarySevereTemplates: [String] = [
            "这件物品目前唯一作用：提醒你当时下单很快。",
            "它现在最稳定的功能，是占地方。",
            "继续吃灰下去，这笔消费会彻底转化为情绪税。"
        ]

        private static let idlePrimaryExtremeTemplates: [String] = [
            "吃灰超百天了，再不处置就只能当冲动消费纪念碑。",
            "百天闲置还不处理，这件东西基本进入“历史文物”状态。",
            "都超百天了，再不动手只能接受大幅折价现实。"
        ]

        private static let idleSecondaryNeverUsedTemplates: [String] = [
            "买来从未开张，属于“理想中的自己在用，现实中的你在看”。",
            "你买的是想象中的生活方式，它买回家后只学会了落灰。",
            "一次都没用过，这单属于典型“情绪先下单，理性后到场”。"
        ]

        private static let idleSecondaryHeavyTemplates: [String] = [
            "给你两个选项：今晚打卡，或者今晚挂闲鱼。",
            "别再观望了，处理路径就两条：用起来，或卖出去。",
            "继续拖延只会让转手价更难看。"
        ]

        private static let idleSecondaryDefaultTemplates: [String] = [
            "继续拖延只会让转手价继续打折。",
            "今天不处理，明天会更不想处理。",
            "每多拖一天，都是在和折价站一边。"
        ]

        private static let resaleReasonLightTemplates: [String] = [
            "功能正常，但使用场景变少，闲置转出。",
            "近期使用需求下降，决定转给更合适的人。",
            "状态良好，但频率不高，转手让它继续发光。"
        ]

        private static let resaleReasonMidTemplates: [String] = [
            "最近使用频率很低，转给更需要的人。",
            "进入低频阶段，转出回血更理性。",
            "长期低利用，准备腾空间并回收预算。"
        ]

        private static let resaleReasonHeavyTemplates: [String] = [
            "长期闲置，决定回血腾空间。",
            "闲置周期过长，继续留着性价比太低。",
            "吃灰时间已超预期，转手是更理性的收尾。"
        ]

        private static let resaleNegotiationReplyTemplates: [String] = [
            "可以小刀，但请直接给到心理价位；离谱砍价就当你在做慈善。",
            "支持小刀，别上来脚踝斩；真诚出价成交更快。",
            "能谈，但别把议价当闯关游戏；合适就秒出。"
        ]

        // MARK: - 省钱复盘文案
        private static let savedHeadlineLowTemplates: [String] = [
            "手刹及时拉住，冲动消费当场熄火。",
            "这次没下单，你给钱包争了口气。",
            "小额也值得守住，习惯就是这么练出来的。"
        ]

        private static let savedHeadlineMidTemplates: [String] = [
            "你把剁手预算，硬生生扳成了存款。",
            "中等金额都能忍住，这次理性纯度很高。",
            "这笔钱没花掉，等于你给未来的自己发了补贴。"
        ]

        private static let savedHeadlineHighTemplates: [String] = [
            "这波不是省钱，是把未来的焦虑提前清仓。",
            "高客单还忍住，这一手直接拉高财务安全感。",
            "你不是克制一次，你是在给冲动消费立规矩。"
        ]

        private static let savedHeadlineHugeTemplates: [String] = [
            "一念之间省下大件，你的理性配得上热搜。",
            "这不是省小钱，是直接守住一笔关键预算。",
            "这种级别都稳住了，消费系统算是升级成功。"
        ]

        private static let savedBodyLongCooldownTemplates: [String] = [
            "冷静期拉满还忍住了，这不是拖延，这是成熟。",
            "长冷静期后依然不买，你的判断力很硬。",
            "挺过长周期诱惑，说明你这次是真的想清楚了。"
        ]

        private static let savedBodyMidCooldownTemplates: [String] = [
            "挺过一周冲动窗口，你的钱包终于学会拒绝。",
            "中等冷静期扛住了，节奏很稳。",
            "七天左右最容易破防，你这次守住了。"
        ]

        private static let savedBodyShortCooldownTemplates: [String] = [
            "短冷静期也能守住底线，说明你是真想变有钱。",
            "时间不长但心态在线，这波克制有含金量。",
            "窗口期虽短，理性到场速度很快。"
        ]

        // MARK: - 空状态文案
        private static let darkRoomEmptyTemplates: [String] = [
            "小黑屋现在是空的，说明你今天还挺稳。",
            "当前无冲动条目，钱包表示想给你加鸡腿。",
            "还没把新冲动关进来，先保持这份清醒。"
        ]

        private static let extractorEmptyTemplates: [String] = [
            "榨干机还没开张，先把想买清单里的条目做完决策。",
            "这里暂时没有可榨干资产，去小黑屋先处理一单。",
            "你还没把物品送进榨干机，今天就让第一件开始回血。"
        ]

        // MARK: - 通知生成入口
        /// 生成轻提醒文案。
        static func light(itemName: String, idleDays: Int) -> String {
            format(templateFrom: lightTemplates, itemName: itemName, idleDays: idleDays)
        }

        /// 生成强提醒文案。
        static func strong(itemName: String, idleDays: Int) -> String {
            format(templateFrom: strongTemplates, itemName: itemName, idleDays: idleDays)
        }

        /// 生成冷静期结束提醒文案。
        static func cooldownReady(itemName: String) -> String {
            format(templateFrom: cooldownReadyTemplates, itemName: itemName)
        }

        /// 生成冷静期结束追提醒文案。
        static func cooldownFollowup(itemName: String) -> String {
            format(templateFrom: cooldownFollowupTemplates, itemName: itemName)
        }

        /// 生成吃灰处置追提醒文案。
        static func idleRescueFollowup(itemName: String, idleDays: Int) -> String {
            format(templateFrom: rescueFollowupTemplates, itemName: itemName, idleDays: idleDays)
        }

        // MARK: - 仪式文案生成入口
        /// 决策成功（忍住没买）的仪式文案。
        static func decisionSavedBundle() -> DecisionBundle {
            decisionSavedBundle(
                itemName: "",
                itemID: nil,
                primaryCategory: .other,
                secondaryCategory: .other,
                behaviorTags: []
            )
        }

        /// 决策成功（忍住没买）的仪式文案：支持向新引擎透传条目语义，供兼容层渐进迁移。
        static func decisionSavedBundle(
            itemName: String,
            itemID: UUID?,
            primaryCategory: ItemPrimaryCategory,
            secondaryCategory: ItemSecondaryCategory,
            behaviorTags: [ItemBehaviorTag]
        ) -> DecisionBundle {
            let fallback = pickRandom(
                from: decisionSavedBundles,
                fallback: DecisionBundle(
                    title: "理性胜利，冲动当场下线",
                    subtitle: "你把“想买”变成了“省下”，这波自控力可以发朋友圈。",
                    actionTitle: "继续克制"
                )
            )

            return resolveDecisionBundle(
                scene: "decision_saved",
                fallback: fallback,
                itemName: itemName,
                itemID: itemID,
                primaryCategory: primaryCategory,
                secondaryCategory: secondaryCategory,
                behaviorTags: behaviorTags
            )
        }

        /// 决策成功（还是买了）的仪式文案。
        static func decisionPurchasedBundle() -> DecisionBundle {
            decisionPurchasedBundle(
                itemName: "",
                itemID: nil,
                primaryCategory: .other,
                secondaryCategory: .other,
                behaviorTags: []
            )
        }

        /// 决策成功（还是买了）的仪式文案：兼容层先走 resolver，旧无参调用点通过默认语义继续可用。
        static func decisionPurchasedBundle(
            itemName: String,
            itemID: UUID?,
            primaryCategory: ItemPrimaryCategory,
            secondaryCategory: ItemSecondaryCategory,
            behaviorTags: [ItemBehaviorTag]
        ) -> DecisionBundle {
            let fallback = pickRandom(
                from: decisionPurchasedBundles,
                fallback: DecisionBundle(
                    title: "决策已落地，接下来拼回本",
                    subtitle: "既然买了就狠狠干活，别让它有机会继续吃灰。",
                    actionTitle: "去榨干机打卡"
                )
            )

            return resolveDecisionBundle(
                scene: "decision_purchased",
                fallback: fallback,
                itemName: itemName,
                itemID: itemID,
                primaryCategory: primaryCategory,
                secondaryCategory: secondaryCategory,
                behaviorTags: behaviorTags
            )
        }

        /// 冷静期决策仪式页毒舌点评。
        static func decisionCelebrationRoastLine(isSaved: Bool) -> String {
            if isSaved {
                return pickRandom(
                    from: decisionSavedRoastTemplates,
                    fallback: "你的理性刚刚全票通过，冲动消费被请出群聊。"
                )
            }
            return pickRandom(
                from: decisionPurchasedRoastTemplates,
                fallback: "既然买了就狠狠干活，下次见面只接受“已回本”。"
            )
        }

        /// 冷静期决策分享结果文案。
        static func decisionShareOutcome(isSaved: Bool, seedKey: String) -> String {
            if isSaved {
                return pickStable(
                    from: decisionSavedOutcomeTemplates,
                    fallback: "冷静期成功忍住没买，直接省下一笔。",
                    seedKey: seedKey
                )
            }
            return pickStable(
                from: decisionPurchasedOutcomeTemplates,
                fallback: "冷静期结束后理性买入，已进入榨干机计划。",
                seedKey: seedKey
            )
        }

        /// 冷静期决策分享文本。
        static func decisionShareText(
            itemName: String,
            isSaved: Bool,
            metricTitle: String,
            metricValue: String,
            roastLine: String
        ) -> String {
            let outcome = decisionShareOutcome(
                isSaved: isSaved,
                seedKey: "\(itemName)-\(metricValue)-\(isSaved)"
            )
            return """
            我在「买了么」完成一次冷静期决策：
            物品：\(itemName)
            结果：\(outcome)
            关键数据：\(metricTitle) \(metricValue)

            毒舌点评：\(roastLine)
            #买了么 #理性消费 #反冲动消费
            """
        }

        /// 打卡文案：买后立刻首刷。
        static func checkinFirstUseImmediateBundle() -> CheckinBundle {
            CheckinBundle(
                title: pickRandom(from: checkinFirstUseImmediateTitles, fallback: "上手即开张，这波很会买"),
                subtitle: pickRandom(from: checkinFirstUseImmediateSubtitles, fallback: "买完马上用，钱包看了都想给你点赞。"),
                badge: "首战即用"
            )
        }

        /// 打卡文案：晚到首刷。
        static func checkinFirstUseLateBundle(daysToFirstUse: Int) -> CheckinBundle {
            CheckinBundle(
                title: pickRandom(from: checkinFirstUseLateTitles, fallback: "吃灰一个月，终于被你救活"),
                subtitle: format(
                    templateFrom: checkinFirstUseLateSubtitles,
                    fallback: "拖了 %@ 天才开封，但今天这下算是把面子挣回来了。",
                    arguments: ["\(daysToFirstUse)"]
                ),
                badge: "迟到首刷"
            )
        }

        /// 打卡文案：普通首刷。
        static func checkinFirstUseNormalBundle() -> CheckinBundle {
            CheckinBundle(
                title: pickRandom(from: checkinFirstUseNormalTitles, fallback: "首次打卡到账"),
                subtitle: pickRandom(from: checkinFirstUseNormalSubtitles, fallback: "比继续落灰强太多，今天这一用很争气。"),
                badge: "首次开封"
            )
        }

        /// 打卡文案：重度吃灰后回坑。
        static func checkinRevivalHeavyBundle(idleDays: Int) -> CheckinBundle {
            CheckinBundle(
                title: pickRandom(from: checkinHeavyRevivalTitles, fallback: "重度吃灰逆转成功"),
                subtitle: format(
                    templateFrom: checkinHeavyRevivalSubtitles,
                    fallback: "沉寂 %@ 天后终于复活，资产没有白买。",
                    arguments: ["\(idleDays)"]
                ),
                badge: "回坑成功"
            )
        }

        /// 打卡文案：中度吃灰后回坑。
        static func checkinRevivalMidBundle(idleDays: Int) -> CheckinBundle {
            CheckinBundle(
                title: pickRandom(from: checkinMidRevivalTitles, fallback: "拖延症被你反杀"),
                subtitle: format(
                    templateFrom: checkinMidRevivalSubtitles,
                    fallback: "停摆 %@ 天后重启使用，这次继续连击别断。",
                    arguments: ["\(idleDays)"]
                ),
                badge: "复活连击"
            )
        }

        /// 打卡文案：低空窗连续打卡。
        static func checkinSteadyBundle() -> CheckinBundle {
            CheckinBundle(
                title: pickRandom(from: checkinSteadyTitles, fallback: "节奏在线，成本在掉"),
                subtitle: pickRandom(from: checkinSteadySubtitles, fallback: "你在稳定输出，单次成本正在被你按着打。"),
                badge: "稳定输出"
            )
        }

        /// 打卡文案：普通续打。
        static func checkinNormalBundle() -> CheckinBundle {
            CheckinBundle(
                title: pickRandom(from: checkinNormalTitles, fallback: "今日打卡，继续回血"),
                subtitle: pickRandom(from: checkinNormalSubtitles, fallback: "这波使用很关键，你又把冲动消费扳回一城。"),
                badge: "今日 +1"
            )
        }

        /// 打卡仪式页毒舌点评。
        static func checkinCelebrationRoastLine(usageCount: Int, isBigMoment: Bool) -> String {
            if usageCount == 1 {
                return pickRandom(from: checkinFirstRoastTemplates, fallback: "首刷到账，这件东西终于不是家里最贵摆件了。")
            }
            if isBigMoment {
                return pickRandom(from: checkinBigMomentRoastTemplates, fallback: "你把吃灰库存救回来了，这波比捡钱还狠。")
            }
            if usageCount >= 30 {
                return pickRandom(from: checkinHighUsageRoastTemplates, fallback: "打卡强度离谱，物品都怕你不给它下班。")
            }
            return pickRandom(from: checkinDefaultRoastTemplates, fallback: "继续连击，别让它回到“买前刚需、买后装饰”的老路。")
        }

        /// 打卡分享文本。
        static func checkinShareText(
            itemName: String,
            usageCount: Int,
            currentCostText: String,
            roastLine: String
        ) -> String {
            let closing = pickStable(
                from: checkinShareClosingTemplates,
                fallback: "你也来试试，别让买过的东西继续吃灰。",
                seedKey: "\(itemName)-\(usageCount)"
            )
            return """
            我在「买了么」完成一次榨干机打卡：
            物品：\(itemName)
            累计打卡：\(usageCount) 次
            当前单次成本：\(currentCostText)

            毒舌点评：\(roastLine)
            \(closing)
            #买了么 #反冲动消费 #闲置榨干机
            """
        }

        // MARK: - 吃灰挽救文案生成入口
        /// 吃灰挽救主点评。
        static func idleRescuePrimary(idleDays: Int, itemID: UUID) -> String {
            let templates: [String]
            let fallback: String
            switch idleDays {
            case ..<7:
                templates = idlePrimaryLightTemplates
                fallback = "关系还没凉透，今晚用一次就能续命。"
            case 7..<14:
                templates = idlePrimaryWarmTemplates
                fallback = "你俩还不算陌生，赶紧打卡别让它转正成摆件。"
            case 14..<30:
                templates = idlePrimaryMidTemplates
                fallback = "它不是装饰品，你也不是样板间策展人。"
            case 30..<60:
                templates = idlePrimaryHeavyTemplates
                fallback = "吃灰一个月了，不放闲鱼是准备传家吗？"
            case 60..<120:
                templates = idlePrimarySevereTemplates
                fallback = "这件物品目前唯一作用：提醒你当时下单很快。"
            default:
                templates = idlePrimaryExtremeTemplates
                fallback = "吃灰超百天了，再不处置就只能当冲动消费纪念碑。"
            }
            return pickStable(
                from: templates,
                fallback: fallback,
                seedKey: itemID.uuidString,
                extraSeed: idleDays
            )
        }

        /// 吃灰挽救副点评。
        static func idleRescueSecondary(idleDays: Int, usageCount: Int, itemID: UUID) -> String {
            if usageCount == 0 {
                return pickStable(
                    from: idleSecondaryNeverUsedTemplates,
                    fallback: "买来从未开张，属于“理想中的自己在用，现实中的你在看”。",
                    seedKey: itemID.uuidString
                )
            }
            if idleDays >= 30 {
                return pickStable(
                    from: idleSecondaryHeavyTemplates,
                    fallback: "给你两个选项：今晚打卡，或者今晚挂闲鱼。",
                    seedKey: itemID.uuidString,
                    extraSeed: usageCount + idleDays
                )
            }
            return pickStable(
                from: idleSecondaryDefaultTemplates,
                fallback: "继续拖延只会让转手价继续打折。",
                seedKey: itemID.uuidString,
                extraSeed: usageCount
            )
        }

        /// 闲鱼转卖品相标签。
        static func resaleCondition(usageCount: Int) -> String {
            if usageCount == 0 {
                return "几乎全新"
            }
            if usageCount <= 5 {
                return "轻度使用"
            }
            return "正常使用"
        }

        /// 闲鱼转卖理由文案。
        static func resaleReason(idleDays: Int, itemID: UUID) -> String {
            let templates: [String]
            let fallback: String
            if idleDays >= 60 {
                templates = resaleReasonHeavyTemplates
                fallback = "长期闲置，决定回血腾空间。"
            } else if idleDays >= 30 {
                templates = resaleReasonMidTemplates
                fallback = "最近使用频率很低，转给更需要的人。"
            } else {
                templates = resaleReasonLightTemplates
                fallback = "功能正常，但使用场景变少，闲置转出。"
            }
            return pickStable(
                from: templates,
                fallback: fallback,
                seedKey: itemID.uuidString,
                extraSeed: idleDays
            )
        }

        /// 闲鱼议价回复文案。
        static func resaleNegotiationReply(itemID: UUID) -> String {
            pickStable(
                from: resaleNegotiationReplyTemplates,
                fallback: "可以小刀，但请直接给到心理价位；离谱砍价就当你在做慈善。",
                seedKey: itemID.uuidString
            )
        }

        // MARK: - 省钱复盘文案生成入口
        /// 省钱复盘主文案。
        static func savedReviewHeadline(savedCents: Int, itemID: UUID) -> String {
            let templates: [String]
            let fallback: String
            switch savedCents {
            case ..<10_000:
                templates = savedHeadlineLowTemplates
                fallback = "手刹及时拉住，冲动消费当场熄火。"
            case 10_000..<50_000:
                templates = savedHeadlineMidTemplates
                fallback = "你把剁手预算，硬生生扳成了存款。"
            case 50_000..<100_000:
                templates = savedHeadlineHighTemplates
                fallback = "这波不是省钱，是把未来的焦虑提前清仓。"
            default:
                templates = savedHeadlineHugeTemplates
                fallback = "一念之间省下大件，你的理性配得上热搜。"
            }
            return pickStable(
                from: templates,
                fallback: fallback,
                seedKey: itemID.uuidString,
                extraSeed: savedCents
            )
        }

        /// 省钱复盘副文案。
        static func savedReviewBody(cooldownDays: Int, itemID: UUID) -> String {
            let templates: [String]
            let fallback: String
            if cooldownDays >= 15 {
                templates = savedBodyLongCooldownTemplates
                fallback = "冷静期拉满还忍住了，这不是拖延，这是成熟。"
            } else if cooldownDays >= 7 {
                templates = savedBodyMidCooldownTemplates
                fallback = "挺过一周冲动窗口，你的钱包终于学会拒绝。"
            } else {
                templates = savedBodyShortCooldownTemplates
                fallback = "短冷静期也能守住底线，说明你是真想变有钱。"
            }
            return pickStable(
                from: templates,
                fallback: fallback,
                seedKey: itemID.uuidString,
                extraSeed: cooldownDays
            )
        }

        /// 小黑屋空状态文案。
        static func darkRoomEmpty() -> String {
            pickRandom(from: darkRoomEmptyTemplates, fallback: "小黑屋现在是空的，说明你今天还挺稳。")
        }

        /// 榨干机空状态文案。
        static func extractorEmpty() -> String {
            pickRandom(from: extractorEmptyTemplates, fallback: "榨干机还没开张，先把想买清单里的条目做完决策。")
        }

        // MARK: - 通用工具
        /// 解析决策场景的标题/副标题/按钮文案；若 resolver 或资源不可用，则整体回退到旧版 bundle。
        private static func resolveDecisionBundle(
            scene: String,
            fallback: DecisionBundle,
            itemName: String,
            itemID: UUID?,
            primaryCategory: ItemPrimaryCategory,
            secondaryCategory: ItemSecondaryCategory,
            behaviorTags: [ItemBehaviorTag]
        ) -> DecisionBundle {
            guard let resolver else {
                assertionFailure("毒舌文案兼容层未能初始化 resolver，已回退到旧版决策文案。")
                return fallback
            }

            do {
                return DecisionBundle(
                    title: try resolveDecisionText(
                        resolver: resolver,
                        scene: scene,
                        slot: .title,
                        itemName: itemName,
                        itemID: itemID,
                        primaryCategory: primaryCategory,
                        secondaryCategory: secondaryCategory,
                        behaviorTags: behaviorTags
                    ),
                    subtitle: try resolveDecisionText(
                        resolver: resolver,
                        scene: scene,
                        slot: .subtitle,
                        itemName: itemName,
                        itemID: itemID,
                        primaryCategory: primaryCategory,
                        secondaryCategory: secondaryCategory,
                        behaviorTags: behaviorTags
                    ),
                    actionTitle: try resolveDecisionText(
                        resolver: resolver,
                        scene: scene,
                        slot: .actionTitle,
                        itemName: itemName,
                        itemID: itemID,
                        primaryCategory: primaryCategory,
                        secondaryCategory: secondaryCategory,
                        behaviorTags: behaviorTags
                    )
                )
            } catch {
                assertionFailure("毒舌文案兼容层解析决策 bundle 失败：\(error.localizedDescription)，已整体回退到旧版决策文案。")
                return fallback
            }
        }

        /// 解析单个决策槽位文案；若任意槽位失败，由上层统一回退整组 bundle，避免新旧文案被混搭。
        private static func resolveDecisionText(
            resolver: CopyResolver,
            scene: String,
            slot: CopySlot,
            itemName: String,
            itemID: UUID?,
            primaryCategory: ItemPrimaryCategory,
            secondaryCategory: ItemSecondaryCategory,
            behaviorTags: [ItemBehaviorTag]
        ) throws -> String {
            let context = CopyContext(
                module: .decision,
                scene: scene,
                slot: slot,
                itemID: itemID,
                itemName: itemName,
                primaryCategory: primaryCategory,
                secondaryCategory: secondaryCategory,
                behaviorTags: behaviorTags,
                intensityCap: .medium,
                allowRandom: true
            )

            return try resolver.resolveSingle(context).text
        }

        /// 从模板池随机抽取一条并格式化（物品名 + 天数）。
        private static func format(templateFrom templates: [String], itemName: String, idleDays: Int) -> String {
            format(
                templateFrom: templates,
                fallback: "%@ 已经 %@ 天未使用。",
                arguments: [itemName, "\(idleDays)"]
            )
        }

        /// 从模板池随机抽取一条并格式化（仅物品名）。
        private static func format(templateFrom templates: [String], itemName: String) -> String {
            format(
                templateFrom: templates,
                fallback: "%@ 需要你做决定。",
                arguments: [itemName]
            )
        }

        /// 通用模板格式化入口。
        private static func format(
            templateFrom templates: [String],
            fallback: String,
            arguments: [CVarArg]
        ) -> String {
            let template = templates.randomElement() ?? fallback
            return String(format: template, arguments: arguments)
        }

        /// 随机选择一条模板数据。
        private static func pickRandom<T>(from source: [T], fallback: T) -> T {
            source.randomElement() ?? fallback
        }

        /// 稳定选择一条模板（同一条目重复进入页面，文案不跳变）。
        private static func pickStable(
            from source: [String],
            fallback: String,
            seedKey: String,
            extraSeed: Int = 0
        ) -> String {
            guard !source.isEmpty else { return fallback }
            let baseSeed = stableSeed(for: seedKey)
            let index = abs(baseSeed + extraSeed) % source.count
            return source[index]
        }

        /// 将字符串转成稳定数值种子（进程重启后也不变）。
        private static func stableSeed(for value: String) -> Int {
            value.unicodeScalars.reduce(0) { partial, scalar in
                (partial &* 31 &+ Int(scalar.value)) & 0x7fffffff
            }
        }
    }
}
