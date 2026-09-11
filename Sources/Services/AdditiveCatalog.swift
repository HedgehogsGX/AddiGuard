import Foundation

enum AdditiveCatalog {
    static let all: [Additive] = merge(
        curated: curated,
        supplemental: categoryEntries + GB2760Catalog.all
    )

    private static let curated: [Additive] = [
        Additive(
            id: "sodium-nitrite",
            name: "亚硝酸钠",
            englishName: "Sodium nitrite",
            code: "E250",
            aliases: ["亚硝酸钠", "亚硝酸盐", "sodium nitrite", "e250"],
            function: "护色剂、防腐剂",
            risk: .high,
            summary: "常用于腌制肉制品。摄入量与使用场景需要严格控制。",
            healthEffects: ["在特定条件下可能形成亚硝胺", "婴幼儿和部分敏感人群需格外谨慎"],
            recommendation: "核对食品类别、标示用量或营养成分表、适用人群及实际摄入量；有具体健康顾虑时咨询专业人员。",
            sources: ["GB 2760-2024", "WHO/JECFA", "EFSA"]
        ),
        Additive(
            id: "bha",
            name: "丁基羟基茴香醚",
            englishName: "Butylated hydroxyanisole",
            code: "E320",
            aliases: ["丁基羟基茴香醚", "butylated hydroxyanisole", "bha", "e320"],
            function: "抗氧化剂",
            risk: .high,
            summary: "用于延缓油脂氧化，不同地区对使用范围和限量有明确规定。",
            healthEffects: ["动物研究中出现争议性结果", "长期高暴露值得关注"],
            recommendation: "核对食品类别、标示用量或营养成分表、适用人群及实际摄入量；有具体健康顾虑时咨询专业人员。",
            sources: ["EFSA", "FDA", "IARC"]
        ),
        Additive(
            id: "bht",
            name: "二丁基羟基甲苯",
            englishName: "Butylated hydroxytoluene",
            code: "E321",
            aliases: ["二丁基羟基甲苯", "butylated hydroxytoluene", "bht", "e321"],
            function: "抗氧化剂",
            risk: .high,
            summary: "常见油脂抗氧化剂，应在法规规定的食品类别和限量内使用。",
            healthEffects: ["长期高剂量暴露存在研究争议", "可能与其他抗氧化剂形成叠加暴露"],
            recommendation: "核对食品类别、标示用量或营养成分表、适用人群及实际摄入量；有具体健康顾虑时咨询专业人员。",
            sources: ["GB 2760-2024", "JECFA", "EFSA"]
        ),
        Additive(
            id: "sodium-benzoate",
            name: "苯甲酸钠",
            englishName: "Sodium benzoate",
            code: "E211",
            aliases: ["苯甲酸钠", "sodium benzoate", "e211"],
            function: "防腐剂",
            risk: .moderate,
            summary: "常用于饮料、酱料等酸性食品，合规限量下可使用。",
            healthEffects: ["部分人群可能出现不耐受反应", "儿童高频摄入含防腐剂饮料需谨慎"],
            recommendation: "核对食品类别、标示用量或营养成分表、适用人群及实际摄入量；有具体健康顾虑时咨询专业人员。",
            sources: ["GB 2760-2024", "WHO/JECFA", "FDA"]
        ),
        Additive(
            id: "potassium-sorbate",
            name: "山梨酸钾",
            englishName: "Potassium sorbate",
            code: "E202",
            aliases: ["山梨酸钾", "potassium sorbate", "e202"],
            function: "防腐剂",
            risk: .moderate,
            summary: "广泛使用的防腐剂，其适用食品类别和最大使用量由标准规定。",
            healthEffects: ["少数敏感人群可能出现刺激或不耐受", "注意多种加工食品的累计摄入"],
            recommendation: "核对食品类别、标示用量或营养成分表、适用人群及实际摄入量；有具体健康顾虑时咨询专业人员。",
            sources: ["GB 2760-2024", "EFSA", "FDA"]
        ),
        Additive(
            id: "sodium-metabisulfite",
            name: "焦亚硫酸钠",
            englishName: "Sodium metabisulfite",
            code: "E223",
            aliases: ["焦亚硫酸钠", "亚硫酸盐", "sodium metabisulfite", "e223"],
            function: "漂白剂、防腐剂、抗氧化剂",
            risk: .moderate,
            summary: "亚硫酸盐类可能引发部分敏感人群的不耐受反应。",
            healthEffects: ["哮喘和亚硫酸盐敏感人群需特别留意", "过量可能引起胃肠不适"],
            recommendation: "核对食品类别、标示用量或营养成分表、适用人群及实际摄入量；有具体健康顾虑时咨询专业人员。",
            sources: ["GB 2760-2024", "FDA", "EFSA"]
        ),
        Additive(
            id: "monosodium-glutamate",
            name: "谷氨酸钠",
            englishName: "Monosodium glutamate",
            code: "E621",
            aliases: ["谷氨酸钠", "味精", "monosodium glutamate", "msg", "e621"],
            function: "增味剂",
            risk: .low,
            summary: "在法规允许范围内广泛使用的增味剂。",
            healthEffects: ["主要关注膳食钠的总摄入", "个别人报告短暂不适，但证据并不一致"],
            recommendation: "核对食品类别、标示用量或营养成分表、适用人群及实际摄入量；有具体健康顾虑时咨询专业人员。",
            sources: ["GB 2760-2024", "FDA", "JECFA"]
        ),
        Additive(
            id: "disodium-ribonucleotides",
            name: "5′-呈味核苷酸二钠",
            englishName: "Disodium 5′-ribonucleotides",
            code: "E635",
            aliases: [
                "5′-呈味核苷酸二钠",
                "5’-呈味核苷酸二钠",
                "5'-呈味核苷酸二钠",
                "呈味核苷酸二钠",
                "disodium 5'-ribonucleotides",
                "disodium ribonucleotides",
                "e635"
            ],
            function: "增味剂",
            risk: .low,
            summary: "由呈味核苷酸盐组成的增味剂，常与谷氨酸钠协同使用。",
            healthEffects: ["JECFA 对该成分的 ADI 结论为“不作具体规定”", "仍应结合食品整体钠含量评估"],
            recommendation: "核对食品类别、标示用量或营养成分表、适用人群及实际摄入量；有具体健康顾虑时咨询专业人员。",
            sources: ["GB 2760-2024", "WHO/JECFA"]
        ),
        Additive(
            id: "paprika-extract",
            name: "辣椒红",
            englishName: "Paprika extract",
            code: "E160c",
            aliases: ["辣椒红", "辣椒红色素", "paprika extract", "paprika oleoresin", "e160c", "ins160c"],
            function: "着色剂",
            risk: .low,
            summary: "从辣椒中获得的红色类胡萝卜素着色剂。",
            healthEffects: ["JECFA 的膳食暴露评估涉及可接受每日摄入量", "作为香辛料提取物使用时仍需结合具体用量和个人情况"],
            recommendation: "核对食品类别、标示用量或营养成分表、适用人群及实际摄入量；有具体健康顾虑时咨询专业人员。",
            sources: ["GB 2760-2024", "WHO/JECFA"]
        ),
        Additive(
            id: "caramel-colour",
            name: "焦糖色",
            englishName: "Caramel colour",
            code: "E150",
            aliases: ["焦糖色", "焦糖色素", "caramel colour", "caramel color", "e150"],
            function: "着色剂",
            risk: .moderate,
            summary: "焦糖色包含多种生产工艺类别；仅凭“焦糖色”标签无法判断具体类别。",
            healthEffects: ["不同 E150 类别的生产副产物与摄入限值存在差异", "EFSA 为四类焦糖色建立了分组 ADI，并对部分类型设置更严格建议"],
            recommendation: "核对食品类别、标示用量或营养成分表、适用人群及实际摄入量；有具体健康顾虑时咨询专业人员。",
            sources: ["GB 2760-2024", "EFSA", "WHO/JECFA"]
        ),
        Additive(
            id: "food-flavouring",
            name: "食用香精",
            englishName: "Food flavouring",
            code: nil,
            aliases: [
                "食用香精", "食品用香精", "香精", "食品用香料", "食用香料",
                "天然香料", "合成香料", "food flavouring", "food flavoring", "flavouring", "flavoring"
            ],
            function: "增香剂（复配成分）",
            risk: .moderate,
            summary: "“食用香精”是成分类别名称，照片无法提供其中每一种香料的具体组成和用量。",
            healthEffects: ["安全性取决于具体香料组成、用量和适用食品类别", "仅凭类别名称不能判断单一化学成分风险"],
            recommendation: "核对食品类别、具体香料组成、适用人群及实际摄入量；有具体健康顾虑时咨询专业人员。",
            sources: ["GB 2760-2024", "WHO/JECFA"]
        ),
        Additive(
            id: "ascorbic-acid",
            name: "抗坏血酸（维生素C）",
            englishName: "Ascorbic acid",
            code: "E300",
            aliases: ["抗坏血酸", "维生素c", "vitamin c", "ascorbic acid", "e300"],
            function: "抗氧化剂",
            risk: .low,
            summary: "常见抗氧化剂，也就是维生素 C。",
            healthEffects: ["食品添加剂用途需结合食品类别和实际用量", "补充剂剂量与食品中的添加剂暴露并非同一情境"],
            recommendation: "核对食品类别、标示用量或营养成分表、适用人群及实际摄入量；有具体健康顾虑时咨询专业人员。",
            sources: ["GB 2760-2024", "FDA", "EFSA"]
        ),
        Additive(
            id: "citric-acid",
            name: "柠檬酸",
            englishName: "Citric acid",
            code: "E330",
            aliases: ["柠檬酸", "citric acid", "e330"],
            function: "酸度调节剂",
            risk: .low,
            summary: "广泛存在于食品和天然水果中的有机酸。",
            healthEffects: ["具体评估需结合食品酸度和实际摄入量", "高酸饮料暴露与牙釉质健康相关"],
            recommendation: "核对食品类别、标示用量或营养成分表、适用人群及实际摄入量；有具体健康顾虑时咨询专业人员。",
            sources: ["GB 2760-2024", "FDA", "EFSA"]
        ),
        Additive(
            id: "acesulfame-potassium",
            name: "安赛蜜（乙酰磺胺酸钾）",
            englishName: "Acesulfame potassium",
            code: "E950",
            aliases: [
                "安赛蜜", "乙酰磺胺酸钾",
                "安赛蜜(又名乙酰磺胺酸钾)", "安赛蜜（又名乙酰磺胺酸钾）",
                "乙酰磺胺酸钾(又名安赛蜜)", "乙酰磺胺酸钾（又名安赛蜜）",
                "acesulfame potassium", "potassium acesulfame", "acesulfame k", "ace-k", "ace k"
            ],
            function: "甜味剂",
            risk: .moderate,
            summary: "高甜度非营养性甜味剂。JECFA 与 EFSA 的每日允许摄入量（ADI）均为 0–15 mg/kg 体重/天；仅凭配料表名称无法判断实际添加量或累计暴露。",
            healthEffects: [
                "EFSA 2025 年复评将 ADI 设为 15 mg/kg 体重/天，并认为其最高膳食暴露估计通常低于该值",
                "ADI 是可终生每日摄入而不产生明显健康风险的估计量，不是单次食用的中毒界线"
            ],
            recommendation: "合规使用不等于可以忽略摄入量。经常食用多种无糖或低糖食品时，可留意同类甜味剂的累计摄入；产品是否符合 GB 2760 仍需结合食品类别和实际用量核对。",
            sources: ["GB 2760-2024", "WHO/JECFA", "EFSA", "FDA"]
        ),
        Additive(
            id: "sucralose",
            name: "三氯蔗糖（蔗糖素）",
            englishName: "Sucralose",
            code: "E955",
            aliases: [
                "三氯蔗糖", "蔗糖素",
                "三氯蔗糖(又名蔗糖素)", "三氯蔗糖（又名蔗糖素）",
                "sucralose"
            ],
            function: "甜味剂",
            risk: .moderate,
            summary: "高甜度非营养性甜味剂。JECFA 与 EFSA 的 ADI 均为 0–15 mg/kg 体重/天；EFSA 2026 年复评认为当前获准用途的估计暴露低于该值。",
            healthEffects: [
                "EFSA 2026 年确认当前获准用途可接受，但没有确认新增高温烘焙用途的安全性",
                "长时间高温处理可能形成何种含氯降解产物仍有不确定性；这不等同于常温饮料中的三氯蔗糖已被判定有害"
            ],
            recommendation: "配料表通常不提供具体添加量；经常食用多种含甜味剂食品时，应结合频率和总摄入量。若用于长时间高温煎炸或烘焙，应留意 EFSA 2026 年指出的降解产物不确定性，并按产品说明使用。",
            sources: ["GB 2760-2024", "WHO/JECFA", "EFSA", "FDA"]
        ),
        Additive(
            id: "carbon-dioxide",
            name: "二氧化碳",
            englishName: "Carbon dioxide",
            code: "E290",
            aliases: ["二氧化碳", "carbon dioxide", "co2", "CO₂"],
            function: "碳酸化剂、防腐剂、推进剂及加工助剂",
            risk: .low,
            summary: "在碳酸饮料中主要形成气泡和碳酸感，也可用于食品加工。JECFA 对二氧化碳的 ADI 结论为“不作具体规定”。",
            healthEffects: [
                "JECFA 未设数值型 ADI，表示按食品添加剂预期用途使用时无需用数值 ADI 管理",
                "“ADI 不作具体规定”不代表无限量使用，也不能单独证明某款产品的具体用途或用量合规"
            ],
            recommendation: "作为碳酸饮料配料时通常为较低关注；仍应结合食品类别、加工用途和 GB 2760 的使用要求判断。",
            sources: ["GB 2760-2024", "WHO/JECFA"]
        ),
        Additive(
            id: "sodium-citrate",
            name: "柠檬酸钠",
            englishName: "Trisodium citrate",
            code: "E331(iii)",
            aliases: [
                "柠檬酸钠", "柠檬酸三钠", "枸橼酸钠",
                "trisodium citrate", "sodium citrate", "citric acid trisodium salt",
                "E331(iii)", "E 331(iii)", "E号331(iii)",
                "INS331(iii)", "INS 331(iii)", "INS号331(iii)"
            ],
            function: "酸度调节剂、螯合剂、稳定剂",
            risk: .low,
            summary: "柠檬酸的钠盐，可调节酸度、结合金属离子并帮助食品保持稳定。JECFA 对柠檬酸及其钙、钾、钠盐采用组别 ADI“不作具体规定”。",
            healthEffects: [
                "JECFA 认为柠檬酸及其钙、钾、钠盐不构成显著毒理学危害，因此未设数值型 ADI",
                "该成分含钠，但配料表名称不能显示它对总钠的具体贡献；控钠人群应查看营养成分表"
            ],
            recommendation: "通常为较低关注。需要控钠时以营养成分表的总钠为主要依据；产品合规性仍需结合食品类别和实际使用量核对。",
            sources: ["GB 2760-2024", "WHO/JECFA"]
        ),
        Additive(
            id: "lecithin",
            name: "卵磷脂",
            englishName: "Lecithin",
            code: "E322",
            aliases: ["卵磷脂", "lecithin", "e322"],
            function: "乳化剂",
            risk: .low,
            summary: "来源广泛的乳化剂，常见于巧克力和烘焙食品。",
            healthEffects: ["具体评估需结合食品类别和实际用量", "大豆或蛋来源需要结合过敏原标签判断"],
            recommendation: "核对食品类别、标示用量、过敏原来源、适用人群及实际摄入量；有具体健康顾虑时咨询专业人员。",
            sources: ["GB 2760-2024", "FDA", "EFSA"]
        )
    ]

    private static let categoryEntries: [Additive] = [
        categoryAdditive(
            id: "food-processing-aid",
            name: "食品工业用加工助剂",
            englishName: "Food processing aid",
            aliases: ["食品工业用加工助剂", "食品加工助剂", "加工助剂", "food processing aid", "processing aid"]
        ),
        categoryAdditive(
            id: "food-enzyme-preparation",
            name: "食品用酶制剂",
            englishName: "Food enzyme preparation",
            aliases: ["食品用酶制剂", "酶制剂", "food enzyme", "enzyme preparation"]
        ),
        categoryAdditive(
            id: "nutrient-fortifier",
            name: "食品营养强化剂",
            englishName: "Nutrient fortifier",
            aliases: ["食品营养强化剂", "营养强化剂", "nutrient fortifier", "nutrition fortifier"]
        ),
        categoryAdditive(
            id: "compound-food-additive",
            name: "复配食品添加剂",
            englishName: "Compound food additive",
            aliases: [
                "复配食品添加剂", "复配防腐剂", "复配甜味剂", "复配膨松剂", "复配增稠剂",
                "复配乳化剂", "复配水分保持剂", "compound food additive"
            ]
        )
    ]

    private static func categoryAdditive(
        id: String,
        name: String,
        englishName: String,
        aliases: [String]
    ) -> Additive {
        Additive(
            id: id,
            name: name,
            englishName: englishName,
            code: nil,
            aliases: aliases,
            function: "添加剂类别（具体成分未展开）",
            risk: .unrated,
            summary: "该标签使用的是添加剂类别名称，无法仅凭类别判断其中每一种成分。",
            healthEffects: ["安全性取决于具体组成、用量和适用食品类别"],
            recommendation: "如需精细评估，请查找产品标示的具体成分或联系生产商。",
            sources: ["GB 2760-2024"]
        )
    }

    private static func merge(curated: [Additive], supplemental: [Additive]) -> [Additive] {
        let enrichedCurated = curated.map(enrichingCodeAliases)
        var result = enrichedCurated
        var usedAliases = Set(enrichedCurated.flatMap(\.aliases).map { aliasKey($0) })

        for additive in supplemental {
            let uniqueAliases = additive.aliases.filter { usedAliases.insert(aliasKey($0)).inserted }
            guard !uniqueAliases.isEmpty else { continue }
            result.append(
                Additive(
                    id: additive.id,
                    name: additive.name,
                    englishName: additive.englishName,
                    code: additive.code,
                    aliases: uniqueAliases,
                    function: additive.function,
                    risk: additive.risk,
                    summary: additive.summary,
                    healthEffects: additive.healthEffects,
                    recommendation: additive.recommendation,
                    sources: additive.sources
                )
            )
        }
        return result
    }

    /// Keep reviewed records authoritative regardless of whether a label uses an E or INS prefix.
    /// Without this enrichment, the supplemental GB entry could claim `INS330` while `E330`
    /// resolved to the reviewed citric-acid record, producing two risk grades for one substance.
    private static func enrichingCodeAliases(_ additive: Additive) -> Additive {
        let combinedAliases = additive.aliases + equivalentCodeAliases(for: additive.code)
        var seen = Set<String>()
        let uniqueAliases = combinedAliases.filter { seen.insert(aliasKey($0)).inserted }
        guard uniqueAliases != additive.aliases else { return additive }

        return Additive(
            id: additive.id,
            name: additive.name,
            englishName: additive.englishName,
            code: additive.code,
            aliases: uniqueAliases,
            function: additive.function,
            risk: additive.risk,
            summary: additive.summary,
            healthEffects: additive.healthEffects,
            recommendation: additive.recommendation,
            sources: additive.sources
        )
    }

    private static func equivalentCodeAliases(for code: String?) -> [String] {
        guard var value = code?.filter({ $0.isLetter || $0.isNumber }), !value.isEmpty else {
            return []
        }

        let foldedValue = value.lowercased()
        if foldedValue.hasPrefix("ins") {
            value.removeFirst(3)
        } else if foldedValue.hasPrefix("e") {
            value.removeFirst()
        }
        guard !value.isEmpty else { return [] }

        return [
            "E\(value)",
            "E \(value)",
            "E号\(value)",
            "INS\(value)",
            "INS \(value)",
            "INS号\(value)"
        ]
    }

    private static func aliasKey(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "zh_CN")
            )
            .filter { $0.isLetter || $0.isNumber }
            .lowercased()
    }
}
