import Foundation

struct ReferenceLink: Identifiable, Hashable {
    let title: String
    let url: URL

    var id: URL { url }
}

struct ReferenceSource: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let overview: String
    let answers: [String]
    let limitations: [String]
    let officialLinks: [ReferenceLink]

    static let gb2760 = ReferenceSource(
        id: "gb2760",
        title: "GB 2760-2024",
        subtitle: "中国食品安全国家标准：食品添加剂使用标准",
        symbol: "doc.text.magnifyingglass",
        overview: "由国家卫生健康委员会发布，规定食品添加剂在不同食品类别中的允许使用范围、使用量和相关条件。",
        answers: [
            "某种添加剂是否被标准收录。",
            "标准允许它用于哪些食品类别，以及适用的使用条件。",
            "标准规定的最大使用量，或是否按生产需要适量使用。"
        ],
        limitations: [
            "被标准收录不等于可以用于任意食品或任意用量。",
            "仅凭配料名称无法核对产品中的实际添加量、生产过程或最终合规性。",
            "国家标准不是针对个人健康状况的诊断或饮食建议。"
        ],
        officialLinks: [
            ReferenceLink(
                title: "国家卫健委：GB 2760-2024 公告",
                url: URL(string: "https://www.nhc.gov.cn/sps/c100088/202403/bda120e678df4a49a8beb90852559d7c.shtml")!
            )
        ]
    )

    static let whoJecfa = ReferenceSource(
        id: "whoJecfa",
        title: "WHO/JECFA",
        subtitle: "联合国粮农组织/世界卫生组织食品添加剂联合专家委员会",
        symbol: "globe.asia.australia.fill",
        overview: "JECFA 汇总对食品添加剂、污染物和部分其他物质的国际科学评估，包括化学信息、每日允许摄入量及评估报告。",
        answers: [
            "某种物质是否接受过 JECFA 评估，以及评估历史。",
            "是否制定了每日允许摄入量等健康指导值。",
            "相关报告、专论和规格文件中讨论了哪些科学证据。"
        ],
        limitations: [
            "JECFA 的科学评估不能替代中国、美国或欧盟的具体使用法规。",
            "每日允许摄入量是基于特定证据和长期人群暴露的参考值，不是单件产品的安全保证或个人医疗结论。",
            "结论对应评估时可获得的数据和使用情境，后续资料可能促使重新评估。"
        ],
        officialLinks: [
            ReferenceLink(
                title: "WHO：JECFA 评估数据库",
                url: URL(string: "https://apps.who.int/food-additives-contaminants-jecfa-database/")!
            )
        ]
    )

    static let fda = ReferenceSource(
        id: "fda",
        title: "FDA",
        subtitle: "美国食品药品监督管理局",
        symbol: "cross.case.fill",
        overview: "FDA 负责美国食品配料的监管框架，包括食品添加剂审批、使用条件以及公认安全（GRAS）等不同监管路径。",
        answers: [
            "美国如何区分和监管食品添加剂与 GRAS 配料。",
            "获准用途可能涉及哪些食品类别、使用水平和标签条件。",
            "可到哪些法规、清单或申请资料中继续核对具体物质。"
        ],
        limitations: [
            "FDA 信息适用于美国监管体系，不能代替 GB 2760 或欧盟规定。",
            "概览页面不等于某种成分当前全部授权条件，应继续核对具体法规和公开清单。",
            "某项用途获准不代表其他用法、其他司法辖区或特定个人情境也得到相同结论。"
        ],
        officialLinks: [
            ReferenceLink(
                title: "FDA：食品添加剂与 GRAS 的监管方式",
                url: URL(string: "https://www.fda.gov/food/food-additives-and-gras-ingredients-information-consumers/understanding-how-fda-regulates-food-additives-and-gras-ingredients")!
            )
        ]
    )

    static let efsa = ReferenceSource(
        id: "efsa",
        title: "EFSA",
        subtitle: "欧洲食品安全局",
        symbol: "building.columns.fill",
        overview: "EFSA 为欧盟食品添加剂决策提供科学风险评估，综合物质性质、毒理资料和膳食暴露估算；授权决定由欧盟委员会和成员国负责。",
        answers: [
            "某种添加剂是否有 EFSA 科学意见或重新评估。",
            "评估采用了哪些毒理资料、膳食暴露估算和每日允许摄入量。",
            "评估是否指出资料缺口或特定人群暴露方面的关注。"
        ],
        limitations: [
            "EFSA 提供科学评估，本身不负责最终授权或设定全部使用条件。",
            "欧盟评估和使用条件不能替代中国食品类别下的 GB 2760 核对。",
            "结论依赖评估的数据和暴露情境，仅凭成分名称无法判断一件具体产品。"
        ],
        officialLinks: [
            ReferenceLink(
                title: "EFSA：食品添加剂专题",
                url: URL(string: "https://www.efsa.europa.eu/en/topics/topic/food-additives")!
            )
        ]
    )

    static let iarc = ReferenceSource(
        id: "iarc",
        title: "IARC",
        subtitle: "国际癌症研究机构致癌物专论计划",
        symbol: "scope",
        overview: "IARC 专论由独立专家审查公开证据，用于识别某种因素在至少部分情境下是否具有致癌危害，并评价证据强度。",
        answers: [
            "某种因素是否接受过 IARC 专论评估。",
            "现有证据支持哪一类致癌危害分组。",
            "人群、动物和作用机制证据的强度如何。"
        ],
        limitations: [
            "IARC 分级是危害识别，不是对某一具体暴露水平、食品用量或个人情境的风险评估。",
            "同一分组中的因素，现实风险可能因暴露剂量、途径和情境而有很大差异。",
            "分级不能单独证明某件产品在实际使用中会致癌，也不提供法规合规或个人饮食建议。"
        ],
        officialLinks: [
            ReferenceLink(
                title: "IARC：致癌物专论计划",
                url: URL(string: "https://www.iarc.who.int/featured-news/iarc-monographs-programme")!
            )
        ]
    )

    static let profileSources: [ReferenceSource] = [
        gb2760,
        whoJecfa,
        fda,
        efsa,
        iarc
    ]

    static func matching(_ raw: String) -> ReferenceSource? {
        let key = raw
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .filter { $0.isLetter || $0.isNumber }
            .lowercased()

        switch key {
        case "gb2760", "gb27602024": return gb2760
        case "who", "jecfa", "whojecfa": return whoJecfa
        case "fda": return fda
        case "efsa": return efsa
        case "iarc": return iarc
        default: return nil
        }
    }
}
