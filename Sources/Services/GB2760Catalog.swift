import Foundation

/// Additives indexed in Appendix F of GB 2760-2024 (the index for Appendix A).
///
/// These records intentionally provide recognition coverage and regulatory provenance only.
/// The curated records in `AdditiveCatalog` override them when a reviewed health summary exists.
/// Official release: https://www.nhc.gov.cn/sps/c100088/202403/bda120e678df4a49a8beb90852559d7c.shtml
enum GB2760Catalog {
    static let all: [Additive] = rows
        .split(separator: "\n")
        .enumerated()
        .compactMap { makeAdditive(index: $0.offset, row: $0.element) }

    private static func makeAdditive(index: Int, row: Substring) -> Additive? {
        let fields = row.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard let rawName = fields.first.map(String.init), !rawName.isEmpty else { return nil }

        let codes = fields.count > 1
            ? fields[1]
                .split(separator: ",")
                .map(String.init)
                .filter { $0 != "—" && !$0.isEmpty }
            : []
        let displayName = displayName(from: rawName)
        // A row with several names and several INS numbers does not define a reliable
        // positional mapping. Do not attach every number to one grouped entity.
        let unambiguousCode = codes.count == 1 ? codes.first : nil
        let aliases = aliases(
            from: rawName,
            displayName: displayName,
            codes: unambiguousCode.map { [$0] } ?? []
        )

        return Additive(
            id: "gb2760-\(index + 1)",
            name: displayName,
            englishName: "GB 2760-2024 listed food additive",
            code: unambiguousCode.map { "E\($0)" },
            aliases: aliases,
            function: "食品添加剂（具体功能及使用范围见国家标准）",
            risk: .unrated,
            summary: "该名称收录于 GB 2760-2024 附录 A。识别到名称不代表其在当前食品类别中的使用范围或用量一定合规。",
            healthEffects: [
                "本地扩展目录用于名称识别，尚未为该条目提供独立健康风险分级",
                "具体安全性与食品类别、添加量、累计暴露及个人情况有关"
            ],
            recommendation: "请结合食品类别和实际添加量查询 GB 2760-2024；如有过敏、慢性病、孕期或儿童饮食方面的顾虑，请咨询专业人员。",
            sources: ["GB 2760-2024"]
        )
    }

    private static func displayName(from rawName: String) -> String {
        let markers = ["(又名", "（又名", "(包括", "（包括", "(简称", "（简称", "[包括", "【包括"]
        let markerIndices = markers.compactMap { rawName.range(of: $0)?.lowerBound }
        guard let firstMarker = markerIndices.min() else { return rawName }
        return String(rawName[..<firstMarker])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func aliases(from rawName: String, displayName: String, codes: [String]) -> [String] {
        var expanded = rawName
        for marker in ["(又名", "（又名", "(包括", "（包括", "(简称", "（简称", "[包括", "【包括"] {
            expanded = expanded.replacingOccurrences(of: marker, with: ",")
        }

        var candidates = [rawName, displayName]
        candidates.append(contentsOf: expanded.components(separatedBy: CharacterSet(charactersIn: ",，、;；")))

        for code in codes {
            let baseCode = code.split(separator: "(", maxSplits: 1).first.map(String.init) ?? code
            for value in Set([code, baseCode]) where !value.isEmpty {
                candidates.append(contentsOf: [
                    "E\(value)",
                    "E \(value)",
                    "E号\(value)",
                    "INS\(value)",
                    "INS \(value)",
                    "INS号\(value)"
                ])
            }
        }

        let trimSet = CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: "()（）[]【】\"“”'‘’")
        )
        var seen = Set<String>()
        return candidates.compactMap { candidate in
            let value = candidate
                .replacingOccurrences(of: "又名", with: "")
                .replacingOccurrences(of: "包括", with: "")
                .replacingOccurrences(of: "简称", with: "")
                .trimmingCharacters(in: trimSet)
            guard value.count >= 2 else { return nil }
            let key = value
                .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "zh_CN"))
                .replacingOccurrences(of: " ", with: "")
                .lowercased()
            guard seen.insert(key).inserted else { return nil }
            return value
        }
    }

    private static let rows = """
4-己基间苯二酚|586
5'-呈味核苷酸二钠(又名呈味核苷酸二钠)|635
5'-肌苷酸二钠|631
5'-鸟苷酸二钠|627
D-甘露糖醇|421
D-异抗坏血酸及其钠盐(包括D-异抗坏血酸,D-异抗坏血酸钠)|315,316
DL-苹果酸|296
DL-苹果酸钠|350(ii)
L-半胱氨酸盐酸盐|920
L-丙氨酸|—
L(+)-酒石酸,dl-酒石酸|334,—
L-苹果酸|—
L-苹果酸钠|—
α-环状糊精|457
β-阿朴-8'-胡萝卜素醛|160e
β-胡萝卜素|160a(i),160a(iii),160a(iv)
β-环状糊精|459
γ-环状糊精|458
ε-聚赖氨酸|—
ε-聚赖氨酸盐酸盐|—
阿拉伯胶|414
阿力甜(又名L-α-天冬氨酰-N-(2,2,4,4-四甲基-3-硫化三亚甲基)-D-丙氨酰胺)|956
阿斯巴甜(又名天门冬酰苯丙氨酸甲酯)|951
爱德万甜(又名N-{N-[3-(3-羟基-4-甲氧基苯基)丙基]-L-α-天冬氨酰}-L-苯丙氨酸-1-甲酯)|969
安赛蜜(又名乙酰磺胺酸钾)|950
氨基乙酸(又名甘氨酸)|640
铵磷脂|442
巴西棕榈蜡|903
白油(又名液体石蜡)|905a
半乳甘露聚糖|—
苯甲酸及其钠盐(包括苯甲酸,苯甲酸钠)|210,211
冰结构蛋白|—
冰乙酸(低压羰基化法)|—
冰乙酸(又名冰醋酸)|260
丙二醇|1520
丙二醇脂肪酸酯|477
丙酸及其钠盐、钙盐(包括丙酸,丙酸钠,丙酸钙)|280,281,282
茶多酚(又名维多酚,简称“TP”)|—
茶多酚棕榈酸酯|—
茶黄素|—
赤藓红及其铝色淀(包括赤藓红,赤藓红铝色淀)|127
赤藓糖醇|968
刺梧桐胶|416
刺云实胶|417
醋酸酯淀粉|1420
达瓦树胶|419
单,双甘油脂肪酸酯|471
单辛酸甘油酯|—
氮气(液氮)|—
淀粉磷酸酯钠(又名淀粉磷酸酯,磷酸酯淀粉,单淀粉磷酸酯)|1410
靛蓝及其铝色淀(包括靛蓝,靛蓝铝色淀)|132
丁基羟基茴香醚(简称“BHA”)|320
对羟基苯甲酸酯类及其钠盐(包括对羟基苯甲酸甲酯钠,对羟基苯甲酸乙酯,对羟基苯甲酸乙酯钠)|219,214,215
二丁基羟基甲苯(简称“BHT”)|321
二甲基二碳酸盐(又名维果灵)|242
二氧化硅|551
二氧化硫及亚硫酸盐(包括二氧化硫,焦亚硫酸钾,焦亚硫酸钠,亚硫酸钠,亚硫酸氢钠,低亚硫酸钠)|220,224,223,221,222,—
二氧化钛|171
二氧化碳|290
番茄红|—
番茄红素|160d(i),160d(iii)
蜂蜡|901
富马酸|297
富马酸一钠|365
改性大豆磷脂|—
甘草抗氧化物|—
甘草酸盐(包括甘草酸铵,甘草酸一钾,甘草酸三钾)|958
甘油(又名丙三醇)|422
柑橘黄|—
高粱红|—
高锰酸钾|—
谷氨酸钠|621
谷氨酰胺转氨酶|—
瓜尔胶|412
硅酸钙|552
果胶|440
海藻酸丙二醇酯|405
海藻酸钙(又名褐藻酸钙)|404
海藻酸钾(又名褐藻酸钾)|402
海藻酸钠(又名褐藻酸钠)|401
核黄素|101(i),101(iii)
黑豆红|—
黑加仑红|163(iii)
红花黄|—
红米红|—
红曲黄色素|—
红曲米,红曲红|—
琥珀酸单甘油酯|472g
琥珀酸二钠|364(ii)
花生衣红|—
槐豆胶(又名刺槐豆胶)|410
黄原胶(又名汉生胶)|415
己二酸|355
甲基纤维素|461
甲壳素(又名几丁质)|—
姜黄|100(ii)
姜黄素|100(i)
焦糖色(加氨生产)|150c
焦糖色(苛性硫酸盐法)|150b
焦糖色(普通法)|150a
焦糖色(亚硫酸铵法)|150d
结冷胶|418
金樱子棕|—
酒石酸氢钾|336
酒石酸铁|—
菊花黄浸膏|—
聚丙烯酸钠|—
聚二甲基硅氧烷及其乳液(包括聚二甲基硅氧烷,聚二甲基硅氧烷乳液)|900a
聚甘油蓖麻醇酸酯(简称“PGPR”)|476
聚甘油脂肪酸酯|475
聚葡萄糖|1200
聚天冬氨酸钾|456
聚乙二醇|1521
聚乙烯醇|1203
决明胶|427
咖啡因|—
卡拉胶|407
抗坏血酸(又名维生素C)|300
抗坏血酸钙|302
抗坏血酸钠|301
抗坏血酸棕榈酸酯|304
抗坏血酸棕榈酸酯(酶法)|304
可得然胶|424
可可壳色|—
可溶性大豆多糖|—
喹啉黄及其铝色淀(包括喹啉黄,喹啉黄铝色淀)|104
辣椒橙|—
辣椒红|—
辣椒油树脂|160c(i)
蓝锭果红|—
酪蛋白酸钠(又名酪朊酸钠)|—
联苯醚(又名二苯醚)|—
亮蓝及其铝色淀(包括亮蓝,亮蓝铝色淀)|133
磷酸化二淀粉磷酸酯|1413
磷酸及磷酸盐[包括磷酸,焦磷酸二氢二钠,焦磷酸钠,磷酸二氢钙,磷酸二氢钾,磷酸氢二铵,磷酸氢二钾,磷酸氢钙,磷酸三钙,磷酸三钾,磷酸三钠,多聚磷酸钠(包括六偏磷酸钠),三聚磷酸钠,磷酸二氢钠,磷酸氢二钠,焦磷酸四钾,焦磷酸一氢三钠,聚偏磷酸钾,酸式焦磷酸钙]|338,450(i),450(iii),341(i),340(i),342(ii),340(ii),341(ii),341(iii),340(iii),339(iii),452(i),451(i),339(i),339(ii),450(v),450(ii),452(ii),450(vii)
磷酸酯双淀粉|1412
磷脂|322
硫代二丙酸二月桂酯|389
硫磺|—
硫酸钙(又名石膏)|516
硫酸铝钾(又名钾明矾),硫酸铝铵(又名铵明矾)|522,523
硫酸镁|518
硫酸锌|—
硫酸亚铁|—
罗汉果甜苷|—
罗望子多糖胶|—
萝卜红|—
氯化钙|509
氯化钾|508
氯化镁|511
吗啉脂肪酸盐果蜡|—
麦芽糖醇,麦芽糖醇液|965(i),965(ii)
没食子酸丙酯(简称“PG”)|310
玫瑰茄红|—
酶解大豆磷脂|—
迷迭香提取物|392
明胶|428
木松香甘油酯|445(iii)
木糖醇|967
木糖醇酐单硬脂酸酯|—
纳他霉素|235
柠檬黄及其铝色淀(包括柠檬黄,柠檬黄铝色淀)|102
柠檬酸|330
柠檬酸钾|332(ii)
柠檬酸钠|331(iii)
柠檬酸铁铵|381
柠檬酸亚锡二钠|—
柠檬酸一钠|331(i)
柠檬酸脂肪酸甘油酯|472c
纽甜(又名N-[N-(3,3-二甲基丁基)]-L-α-天门冬氨-L-苯丙氨酸1-甲酯)|961
偏酒石酸|353
葡萄皮红|163(ii)
葡萄糖酸-δ-内酯|575
葡萄糖酸钠|576
葡萄糖酸亚铁|579
普鲁兰多糖|1204
羟丙基淀粉|1440
羟丙基二淀粉磷酸酯|1442
羟丙基甲基纤维素(简称“HPMC”)|464
羟基硬脂精(又名氧化硬脂精)|387
氢化松香甘油酯|—
氢氧化钙|526
氢氧化钾|525
琼脂|406
日落黄及其铝色淀(包括日落黄,日落黄铝色淀)|110
溶菌酶|1105
肉桂醛|—
乳酸|270
乳酸钙|327
乳酸钾|326
乳酸链球菌素|234
乳酸钠|325
乳酸脂肪酸甘油酯|472b
乳糖醇(又名4-β-D吡喃半乳糖-D-山梨醇)|966
乳糖酶|—
三氯蔗糖(又名蔗糖素)|955
三赞胶|—
桑椹红|—
沙蒿胶|—
沙棘黄|—
山梨酸及其钾盐(包括山梨酸,山梨酸钾)|200,202
山梨糖醇,山梨糖醇液|420(i),420(ii)
双乙酸钠(又名二醋酸钠)|262(ii)
双乙酰酒石酸单双甘油酯(简称“DATEM”)|472e
司盘类[包括山梨醇酐单月桂酸酯(又名司盘20),山梨醇酐单棕榈酸酯(又名司盘40),山梨醇酐单硬脂酸酯(又名司盘60),山梨醇酐三硬脂酸酯(又名司盘65),山梨醇酐单油酸酯(又名司盘80)]|493,495,491,492,494
松香季戊四醇酯|—
酸处理淀粉|1401
酸性红(又名偶氮玉红)|122
羧甲基淀粉钠|—
羧甲基纤维素钠|466
索马甜|957
碳酸铵|503(i)
碳酸钙(包括轻质碳酸钙,重质碳酸钙)|170(i)
碳酸钾|501(i)
碳酸镁(包括轻质碳酸镁,重质碳酸镁)|504(i)
碳酸钠|500(i)
碳酸氢铵|503(ii)
碳酸氢钾|501(ii)
碳酸氢钠|500(ii)
碳酸氢三钠(又名倍半碳酸钠)|500(iii)
糖精钠|954(iv)
特丁基对苯二酚(简称“TBHQ”)|319
天门冬酰苯丙氨酸甲酯乙酰磺胺酸|962
天然胡萝卜素|160a(ii)
天然苋菜红|—
田菁胶|—
甜菜红|162
甜菊糖苷|960
甜蜜素(又名环己基氨基磺酸钠),环己基氨基磺酸钙|952(iv),952(ii)
吐温类[聚氧乙烯(20)山梨醇酐单月桂酸酯(又名吐温20),聚氧乙烯(20)山梨醇酐单棕榈酸酯(又名吐温40),聚氧乙烯(20)山梨醇酐单硬脂酸酯(又名吐温60),聚氧乙烯(20)山梨醇酐单油酸酯(又名吐温80)]|432,434,435,433
脱氢乙酸及其钠盐(包括脱氢乙酸,脱氢乙酸钠)|265,266
脱乙酰甲壳素(又名壳聚糖)|—
微晶纤维素|460(i)
维生素E(包括dl-α-生育酚,d-α-生育酚,混合生育酚浓缩物)|307
稳定态二氧化氯|926
纤维素|460
苋菜红及其铝色淀(包括苋菜红,苋菜红铝色淀)|123
橡子壳棕|—
硝酸钠,硝酸钾|251,252
辛,癸酸甘油酯|—
辛烯基琥珀酸淀粉钠|1450
新红及其铝色淀(包括新红,新红铝色淀)|—
亚麻籽胶(又名富兰克胶)|—
亚铁氰化钾,亚铁氰化钠|536,535
亚硝酸钠,亚硝酸钾|250,249
胭脂虫红及其铝色淀(包括胭脂虫红,胭脂虫红铝色淀)|120
胭脂红及其铝色淀(包括胭脂红,胭脂红铝色淀)|124
胭脂树橙(又名红木素,降红木素)|160b
盐酸|507
杨梅红|—
氧化淀粉|1404
氧化羟丙基淀粉|—
氧化铁黑,氧化铁红|172(i),172(ii)
叶黄素|161b(i)
叶绿素铜|141(i)
叶绿素铜钠盐,叶绿素铜钾盐|141(ii)
液体二氧化碳(煤气化法)|—
乙二胺四乙酸二钠|386
乙二胺四乙酸二钠钙|385
乙酸钠(又名醋酸钠)|262(i)
乙酰化单,双甘油脂肪酸酯|472a
乙酰化二淀粉磷酸酯|1414
乙酰化双淀粉己二酸酯|1422
乙氧基喹|324
异构化乳糖|—
异麦芽酮糖|—
硬脂酸(又名十八烷酸)|570
硬脂酸钙|—
硬脂酸钾|—
硬脂酸镁|470(iii)
硬脂酰乳酸钠,硬脂酰乳酸钙|481(i),482(i)
诱惑红及其铝色淀(包括诱惑红,诱惑红铝色淀)|129
玉米黄|—
越橘红|—
藻蓝|—
皂荚糖胶|—
皂树皮提取物|999
蔗糖脂肪酸酯|473
栀子黄|164
栀子蓝|165
植酸(又名肌醇六磷酸),植酸钠|391,—
植物炭黑|153
竹叶抗氧化物|—
紫草红|—
紫甘薯色素|—
紫胶(又名虫胶)|904
紫胶红(又名虫胶红)|—
"""
}
