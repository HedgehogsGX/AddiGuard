import SwiftUI

enum RiskLevel: String, Codable, CaseIterable, Hashable {
    case unrated
    case high
    case moderate
    case low

    var title: String {
        switch self {
        case .unrated: "无法判断"
        case .high: "高关注"
        case .moderate: "需核对"
        case .low: "较低关注"
        }
    }

    var shortTitle: String {
        switch self {
        case .unrated: "无法判断"
        case .high: "高关注"
        case .moderate: "需核对"
        case .low: "较低关注"
        }
    }

    var color: Color {
        switch self {
        case .unrated: .riskUnrated
        case .high: .riskHigh
        case .moderate: .riskModerate
        case .low: .riskLow
        }
    }

    var prominentColor: Color {
        switch self {
        case .unrated: .riskUnratedProminent
        case .high: .riskHighProminent
        case .moderate: .riskModerateProminent
        case .low: .riskLowProminent
        }
    }

    var symbol: String {
        switch self {
        case .unrated: "questionmark.circle.fill"
        case .high: "exclamationmark.triangle.fill"
        case .moderate: "exclamationmark.circle.fill"
        case .low: "checkmark.circle.fill"
        }
    }

    var severity: Int {
        switch self {
        case .unrated: 1
        case .high: 3
        case .moderate: 2
        case .low: 0
        }
    }
}

struct Additive: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let englishName: String
    let code: String?
    let aliases: [String]
    let function: String
    let risk: RiskLevel
    let summary: String
    let healthEffects: [String]
    let recommendation: String
    let sources: [String]

    /// A label-friendly explanation that complements the more technical `summary`.
    /// This is computed so adding it does not change the persisted Codable schema.
    var plainLanguageSummary: String {
        switch id {
        case "sodium-nitrite":
            "它常用于腌制肉制品，帮助保持颜色并抑制部分微生物。是否符合标准要看食品类别和实际添加量，名称本身不能代替判断。"
        case "bha":
            "它是一种帮助油脂延缓氧化、减少变味的抗氧化剂，常见于含油食品。需要按具体食品类别和标示用量核对。"
        case "bht":
            "它是一种用于延缓油脂氧化的抗氧化剂，常见于含油食品。具体判断需要结合食品类别、使用量和实际摄入量。"
        case "sodium-benzoate":
            "它是一种防腐剂，常在酸性饮料、酱料等食品中帮助抑制酵母和霉菌。需要结合食品类别和用量核对标准。"
        case "potassium-sorbate":
            "它是一种防腐剂，主要帮助抑制霉菌和酵母。标签出现这个名字只说明使用了该成分，仍需核对食品类别和用量。"
        case "sodium-metabisulfite":
            "它属于亚硫酸盐，可用于防腐、抗氧化或漂白。对亚硫酸盐敏感的人还应查看标签上的过敏或人群提示。"
        case "monosodium-glutamate":
            "它就是味精的主要成分，用来增强鲜味。它含钠，需要控钠时应同时查看营养成分表和总摄入量。"
        case "disodium-ribonucleotides":
            "它是一类增强鲜味的核苷酸盐，常和谷氨酸钠一起使用。它也含钠，判断时要结合营养成分表和摄入量。"
        case "paprika-extract":
            "它是从辣椒获得的红色着色成分，用来给食品上色。它和辣味强弱不是同一个概念，具体使用仍需按食品类别和用量核对。"
        case "caramel-colour":
            "它是一组通过糖类受热等工艺制得的棕色着色剂，不等同于家里熬制的焦糖。标签只写“焦糖色”时，通常看不出具体工艺类别。"
        case "food-flavouring":
            "“食用香精”通常是多种香味物质的类别或混合物，用来调整食品气味和风味。只看到这个总称时，无法知道其中每一种成分和用量。"
        case "ascorbic-acid":
            "它就是维生素 C，在这里通常用来延缓氧化、保护颜色或品质。作为食品添加剂使用和服用维生素补充剂是不同情境。"
        case "citric-acid":
            "它是水果中也常见的一种有机酸，食品中主要用来调节酸度和提供酸味。具体影响要结合食品整体酸度和摄入量。"
        case "acesulfame-potassium":
            "它是一种高甜度、非营养性甜味剂，标签上也可能写作“乙酰磺胺酸钾”或 Ace-K。权威机构为它设有每日允许摄入量，但仅凭配料表名称无法算出实际摄入量。"
        case "sucralose":
            "它是一种高甜度、非营养性甜味剂，也叫蔗糖素。现有批准用途经权威机构评估可接受；配料表通常不写添加量，若经常摄入多种含甜味剂食品，还要结合总摄入量判断。"
        case "carbon-dioxide":
            "它就是让碳酸饮料产生气泡的二氧化碳，也可用于食品加工或包装。JECFA 未为它设定数值型每日允许摄入量，这不等于可以不受工艺和法规要求限制。"
        case "sodium-citrate":
            "它是柠檬酸的钠盐，常用来调节酸度、稳定食品或结合金属离子。需要控钠时，应以营养成分表中的总钠为准，不能只靠配料名称估算。"
        case "lecithin":
            "它是一种乳化剂，帮助油和水更均匀地混合，常见于巧克力和烘焙食品。来源可能是大豆或蛋，相关过敏人群应查看来源标示。"
        case "food-processing-aid":
            "这是生产过程中帮助完成加工的一类物质，不是某一种具体成分。标签没有给出具体名称时，无法进一步核对其用途和残留情况。"
        case "food-enzyme-preparation":
            "这是用于食品加工反应的酶类总称，不是某一种具体酶。需要知道具体酶名、来源和用途才能进一步核对。"
        case "nutrient-fortifier":
            "这是补充维生素、矿物质等营养成分的类别名，不代表某一种具体成分。需要查看具体强化剂名称和含量。"
        case "compound-food-additive":
            "这是由两种或更多添加剂配成的产品类别。只看到这个总称时，无法知道具体组成和各成分用量。"
        case let value where value.hasPrefix("gb2760-"):
            "这是国家食品添加剂标准目录中收录的名称。本地目录目前只确认其名称或编号，不能仅凭被收录就判断在这款食品中的用途、用量或合规性。"
        default:
            "这是标签中识别到的“\(name)”。当前没有更具体的通俗说明，需要结合食品类别、具体用途和标示用量进一步核对。"
        }
    }
}

struct DetectedAdditive: Identifiable, Codable, Hashable {
    let additive: Additive
    let matchedTerm: String
    let personalizedNote: String?

    var id: String { additive.id }
}
