import XCTest
@testable import AddiGuard

final class ReferenceSourceTests: XCTestCase {
    func testProfileSourcesAreCompleteAndWellFormed() {
        XCTAssertEqual(
            ReferenceSource.profileSources.map(\.id),
            ["gb2760", "whoJecfa", "fda", "efsa", "iarc"]
        )
        XCTAssertEqual(Set(ReferenceSource.profileSources.map(\.id)).count, 5)

        for source in ReferenceSource.profileSources {
            XCTAssertFalse(source.title.isEmpty, source.id)
            XCTAssertFalse(source.subtitle.isEmpty, source.id)
            XCTAssertFalse(source.symbol.isEmpty, source.id)
            XCTAssertFalse(source.overview.isEmpty, source.id)
            XCTAssertFalse(source.answers.isEmpty, source.id)
            XCTAssertFalse(source.limitations.isEmpty, source.id)
            XCTAssertFalse(source.officialLinks.isEmpty, source.id)
            XCTAssertTrue(source.officialLinks.allSatisfy { $0.url.scheme == "https" }, source.id)
        }
    }

    func testMatchingCoversEveryExistingCatalogSourceSpelling() {
        let expectedMatches = [
            "GB 2760-2024": "gb2760",
            "WHO": "whoJecfa",
            "WHO/JECFA": "whoJecfa",
            "JECFA": "whoJecfa",
            "FDA": "fda",
            "EFSA": "efsa",
            "IARC": "iarc"
        ]

        for (raw, expectedID) in expectedMatches {
            XCTAssertEqual(ReferenceSource.matching(raw)?.id, expectedID, raw)
            XCTAssertEqual(ReferenceSource.matching("  \(raw.lowercased())  ")?.id, expectedID, raw)
        }

        let catalogSpellings = Set(AdditiveCatalog.all.flatMap(\.sources))
        XCTAssertTrue(catalogSpellings.allSatisfy { ReferenceSource.matching($0) != nil })
        XCTAssertNil(ReferenceSource.matching(""))
        XCTAssertNil(ReferenceSource.matching("unknown source"))
    }

    func testOfficialLinksUseTheReviewedPrimarySources() {
        let linksByID = Dictionary(
            uniqueKeysWithValues: ReferenceSource.profileSources.map {
                ($0.id, $0.officialLinks.map { $0.url.absoluteString })
            }
        )

        XCTAssertEqual(linksByID["gb2760"], [
            "https://www.nhc.gov.cn/sps/c100088/202403/bda120e678df4a49a8beb90852559d7c.shtml"
        ])
        XCTAssertEqual(linksByID["whoJecfa"], [
            "https://apps.who.int/food-additives-contaminants-jecfa-database/"
        ])
        XCTAssertEqual(linksByID["fda"], [
            "https://www.fda.gov/food/food-additives-and-gras-ingredients-information-consumers/understanding-how-fda-regulates-food-additives-and-gras-ingredients"
        ])
        XCTAssertEqual(linksByID["efsa"], [
            "https://www.efsa.europa.eu/en/topics/topic/food-additives"
        ])
        XCTAssertEqual(linksByID["iarc"], [
            "https://www.iarc.who.int/featured-news/iarc-monographs-programme"
        ])
    }

    func testIARCExplicitlySeparatesHazardFromExposureRisk() {
        let limitations = ReferenceSource.iarc.limitations.joined(separator: " ")

        XCTAssertTrue(limitations.contains("危害识别"))
        XCTAssertTrue(limitations.contains("不是"))
        XCTAssertTrue(limitations.contains("具体暴露水平"))
        XCTAssertTrue(limitations.contains("风险评估"))
        XCTAssertTrue(limitations.contains("暴露剂量"))
        XCTAssertTrue(limitations.contains("不能单独证明"))
    }

    func testReferenceLinkIdentityIsItsURL() throws {
        let link = try XCTUnwrap(ReferenceSource.gb2760.officialLinks.first)
        XCTAssertEqual(link.id, link.url)
    }
}
