import Foundation

public enum SeededClassification {
    public static let deterministicRules: [ClassificationRule] = [
        rule(
            "air india",
            DefaultBudgetTaxonomy.CategoryID.travel,
            merchantName: "Air India",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "emirates",
            DefaultBudgetTaxonomy.CategoryID.travel,
            merchantName: "Emirates",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "united airlines",
            DefaultBudgetTaxonomy.CategoryID.travel,
            merchantName: "United Airlines",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "turkish airlines",
            DefaultBudgetTaxonomy.CategoryID.travel,
            merchantName: "Turkish Airlines",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "grand hyatt",
            DefaultBudgetTaxonomy.CategoryID.travel,
            merchantName: "Grand Hyatt",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "marriott marquis",
            DefaultBudgetTaxonomy.CategoryID.travel,
            merchantName: "Marriott Marquis",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "westin st francis",
            DefaultBudgetTaxonomy.CategoryID.travel,
            merchantName: "Westin St. Francis",
            matchKind: .prefixNormalizedMerchant
        ),
        rule("costco rx", DefaultBudgetTaxonomy.CategoryID.health, merchantName: "Costco RX"),
        rule("costco annual", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Costco Annual"),
        rule("costco cash reward", DefaultBudgetTaxonomy.CategoryID.income, merchantName: "Costco Cash Reward"),
        rule("costco whse", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "Costco"),
        rule("www costco com", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "Costco"),
        rule("whole foods", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "Whole Foods"),
        rule("trader joe", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "Trader Joe's"),
        rule("safeway", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "Safeway"),
        rule("kroger", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "Kroger"),
        rule("aldi", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "Aldi"),
        rule("chavez supermarket", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "Chavez Supermarket"),
        rule("india cash carry", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "India Cash & Carry"),
        rule("nob hill foods", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "Nob Hill Foods"),
        rule("sprouts farmers mark", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "Sprouts Farmers Market"),
        rule("costco", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "Costco"),
        rule("walmart com", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Walmart"),
        rule("walmart", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Walmart"),
        rule("wal mart", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "Walmart"),
        rule("macys", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Macy's"),
        rule("amazon", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Amazon"),
        rule("target", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "Target"),
        rule("temu", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Temu"),
        rule("ross stores", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Ross"),
        rule("burlington stores", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Burlington"),
        rule("t j maxx", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "T.J. Maxx"),
        rule("marshalls", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Marshalls"),
        rule("netflix", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Netflix"),
        rule("spotify", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Spotify"),
        rule("hulu", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Hulu"),
        rule("disney plus", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Disney Plus"),
        rule("disneyplus", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Disney Plus"),
        rule("amazon prime", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Amazon Prime"),
        rule("google google one", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Google One"),
        rule("youtube", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "YouTube Premium"),
        rule("openai", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "OpenAI"),
        rule("apple com", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Apple"),
        rule("meta payroll", DefaultBudgetTaxonomy.CategoryID.income, merchantName: "Meta Payroll"),
        rule(
            "meta direct dep",
            DefaultBudgetTaxonomy.CategoryID.income,
            merchantName: "Meta Payroll",
            matchKind: .prefixNormalizedMerchant
        ),
        rule("interest payment", DefaultBudgetTaxonomy.CategoryID.income, merchantName: "Interest Payment"),
        rule(
            "interest paid",
            DefaultBudgetTaxonomy.CategoryID.income,
            merchantName: "Interest Paid",
            matchKind: .prefixNormalizedMerchant
        ),
        rule("rocket mortgage", DefaultBudgetTaxonomy.CategoryID.homeAndUtilities, merchantName: "Rocket Mortgage"),
        rule("flagstar bank", DefaultBudgetTaxonomy.CategoryID.homeAndUtilities, merchantName: "Flagstar Bank"),
        rule("cim 37 degrees n", DefaultBudgetTaxonomy.CategoryID.homeAndUtilities, merchantName: "CIM-37 Degrees N"),
        rule("citi autopay", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "Citi Autopay"),
        rule("chase credit crd", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "Chase Credit Card"),
        rule("tjx rewards payment", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "TJX Rewards Payment"),
        rule(
            "automatic payment thank",
            DefaultBudgetTaxonomy.CategoryID.transfers,
            merchantName: "Automatic Payment",
            matchKind: .prefixNormalizedMerchant
        ),
        rule("ally bank p2p", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "Ally Bank P2P"),
        rule("autopay", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "Autopay"),
        rule("venmo", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "Venmo"),
        rule("zelle", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "Zelle"),
        rule("vanguard", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "Vanguard"),
        rule("guardianwp", DefaultBudgetTaxonomy.CategoryID.homeAndUtilities, merchantName: "Guardian Water & Power"),
        rule("pgande", DefaultBudgetTaxonomy.CategoryID.homeAndUtilities, merchantName: "PG&E"),
        rule("comcast", DefaultBudgetTaxonomy.CategoryID.homeAndUtilities, merchantName: "Comcast"),
        rule("xfinity", DefaultBudgetTaxonomy.CategoryID.homeAndUtilities, merchantName: "Xfinity"),
        rule("verizon", DefaultBudgetTaxonomy.CategoryID.homeAndUtilities, merchantName: "Verizon"),
        rule("t mobile", DefaultBudgetTaxonomy.CategoryID.homeAndUtilities, merchantName: "T-Mobile"),
        rule("mindbody", DefaultBudgetTaxonomy.CategoryID.health, merchantName: "Mindbody"),
        rule("usaa", DefaultBudgetTaxonomy.CategoryID.transportation, merchantName: "USAA"),
        rule(
            "progressive ins",
            DefaultBudgetTaxonomy.CategoryID.transportation,
            merchantName: "Progressive",
            matchKind: .prefixNormalizedMerchant
        ),
        rule("dmv", DefaultBudgetTaxonomy.CategoryID.transportation, merchantName: "DMV"),
        rule("yell madison camp", DefaultBudgetTaxonomy.CategoryID.family, merchantName: "Yell Madison Camp"),
        rule("bright horizons", DefaultBudgetTaxonomy.CategoryID.family, merchantName: "Bright Horizons"),
        rule(
            "airborne gymnastics",
            DefaultBudgetTaxonomy.CategoryID.family,
            merchantName: "Airborne Gymnastics",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "waterworks swim",
            DefaultBudgetTaxonomy.CategoryID.family,
            merchantName: "Waterworks Swim School",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "tutu school",
            DefaultBudgetTaxonomy.CategoryID.family,
            merchantName: "Tutu School",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "first position dance",
            DefaultBudgetTaxonomy.CategoryID.family,
            merchantName: "First Position Dance",
            matchKind: .prefixNormalizedMerchant
        ),
        rule("facts", DefaultBudgetTaxonomy.CategoryID.family, merchantName: "FACTS"),
        rule(
            "bb tuition mgmt",
            DefaultBudgetTaxonomy.CategoryID.family,
            merchantName: "BB Tuition Management",
            matchKind: .prefixNormalizedMerchant
        ),
        rule("beast academy", DefaultBudgetTaxonomy.CategoryID.family, merchantName: "Beast Academy"),
        rule("king s academy", DefaultBudgetTaxonomy.CategoryID.family, merchantName: "The King's Academy"),
        rule("joe the juice", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Joe & The Juice"),
        rule("blue bottle coffee", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Blue Bottle Coffee"),
        rule("tesla", DefaultBudgetTaxonomy.CategoryID.transportation, merchantName: "Tesla"),
        rule("waymo", DefaultBudgetTaxonomy.CategoryID.transportation, merchantName: "Waymo"),
        rule("uber", DefaultBudgetTaxonomy.CategoryID.transportation, merchantName: "Uber"),
        rule("lyft", DefaultBudgetTaxonomy.CategoryID.transportation, merchantName: "Lyft"),
        rule("golden gate bridge", DefaultBudgetTaxonomy.CategoryID.transportation, merchantName: "Golden Gate Bridge"),
        rule("parkwhiz", DefaultBudgetTaxonomy.CategoryID.transportation, merchantName: "ParkWhiz"),
        rule("connectyourcare", DefaultBudgetTaxonomy.CategoryID.health, merchantName: "ConnectYourCare"),
        rule("cvs", DefaultBudgetTaxonomy.CategoryID.health, merchantName: "CVS"),
        rule("pamf", DefaultBudgetTaxonomy.CategoryID.health, merchantName: "PAMF"),
        rule("irs", DefaultBudgetTaxonomy.CategoryID.financial, merchantName: "IRS"),
        rule("franchise tax bo", DefaultBudgetTaxonomy.CategoryID.financial, merchantName: "Franchise Tax Board"),
        rule("dishdash", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Dishdash"),
        rule("merit vegan", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Merit Vegan"),
        rule("sri anandabhavan", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Sri Anandabhavan"),
        rule("halal fried chicken", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Halal Fried Chicken"),
        rule("halal fried", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Halal Fried"),
        rule("chick fil a", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Chick-fil-A"),
        rule("khans karahi kabob", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Khans Karahi Kabob"),
        rule("happy sushi", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Happy Sushi"),
        rule("tobang korean bbq", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Tobang Korean BBQ"),
        rule("chipotle", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Chipotle"),
        rule("in n out", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "In-N-Out"),
        rule("zeni ethiopian", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Zeni Ethiopian"),
        rule("mumu hot pot", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Mumu Hot Pot"),
        rule("mylapore", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Mylapore"),
        rule("atlas pizza", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Atlas Pizza"),
        rule("taj mahal", DefaultBudgetTaxonomy.CategoryID.dining, merchantName: "Taj Mahal"),
        rule("shirdi sai", DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle, merchantName: "Shirdi Sai"),
    ]

    public static let heuristics: [ClassificationHeuristic] = [
        heuristic("pizza", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("pizzeria", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("restaurant", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("burger", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("taco", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("tacos", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("ramen", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("kabob", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("kebab", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("sushi", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("hot pot", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("chaat", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("momo", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("wok", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("baguette", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("creamery", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("cafe", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("coffee", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("espresso", DefaultBudgetTaxonomy.CategoryID.dining),
        heuristic("pharmacy", DefaultBudgetTaxonomy.CategoryID.health),
        heuristic("rx", DefaultBudgetTaxonomy.CategoryID.health),
        heuristic("payroll", DefaultBudgetTaxonomy.CategoryID.income),
        heuristic("salary", DefaultBudgetTaxonomy.CategoryID.income),
        heuristic("direct deposit", DefaultBudgetTaxonomy.CategoryID.income),
        heuristic("transfer", DefaultBudgetTaxonomy.CategoryID.transfers),
        heuristic("zelle", DefaultBudgetTaxonomy.CategoryID.transfers),
        heuristic("atm withdrawal", DefaultBudgetTaxonomy.CategoryID.transfers),
        heuristic("uber", DefaultBudgetTaxonomy.CategoryID.transportation),
        heuristic("lyft", DefaultBudgetTaxonomy.CategoryID.transportation),
        heuristic("supermarket", DefaultBudgetTaxonomy.CategoryID.groceries),
        heuristic("farmers mark", DefaultBudgetTaxonomy.CategoryID.groceries),
        heuristic("cash carry", DefaultBudgetTaxonomy.CategoryID.groceries),
    ]

    public static let curatedReviewPrefills: [CuratedReviewPrefill] = [
        curatedReviewPrefill(
            id: "starter.issuer-credit.platinum-digital-entertainment-credit",
            merchantPattern: "platinum digital entertainment credit",
            categoryID: DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle,
            merchantName: "Platinum Digital Entertainment Credit",
            matchKind: .exactNormalizedMerchant
        ),
        curatedReviewPrefill(
            id: "starter.issuer-credit.amex-airline-fee-reimbursement",
            merchantPattern: "amex airline fee reimbursement",
            categoryID: DefaultBudgetTaxonomy.CategoryID.travel,
            merchantName: "Amex Airline Fee Reimbursement",
            matchKind: .exactNormalizedMerchant
        ),
        curatedReviewPrefill(
            id: "starter.issuer-credit.platinum-hotel-credit",
            merchantPattern: "platinum hotel credit",
            categoryID: DefaultBudgetTaxonomy.CategoryID.travel,
            merchantName: "Platinum Hotel Credit",
            matchKind: .exactNormalizedMerchant
        ),
        curatedReviewPrefill(
            id: "starter.travel.booking-com",
            merchantPattern: "booking com",
            categoryID: DefaultBudgetTaxonomy.CategoryID.travel,
            merchantName: "Booking.com",
            matchKind: .prefixNormalizedMerchant
        ),
        curatedReviewPrefill(
            id: "starter.travel.amex-travel",
            merchantPattern: "amex travel",
            categoryID: DefaultBudgetTaxonomy.CategoryID.travel,
            merchantName: "Amex Travel",
            matchKind: .prefixNormalizedMerchant
        ),
        curatedReviewPrefill(
            id: "starter.99pledg.family",
            merchantPattern: "99pledg",
            categoryID: DefaultBudgetTaxonomy.CategoryID.shoppingAndLifestyle,
            merchantName: "99PLEDG",
            matchKind: .prefixNormalizedMerchant
        ),
        curatedReviewPrefill(
            id: "starter.choicelunch.school-lunch",
            merchantPattern: "choicelunch",
            categoryID: DefaultBudgetTaxonomy.CategoryID.family,
            merchantName: "Choicelunch",
            matchKind: .prefixNormalizedMerchant
        ),
        curatedReviewPrefill(
            id: "starter.lineleader.childcare-billing",
            merchantPattern: "lineleader",
            categoryID: DefaultBudgetTaxonomy.CategoryID.family,
            merchantName: "LineLeader",
            matchKind: .prefixNormalizedMerchant
        ),
    ]

    public static func liveClassifier() -> ClassificationEngine {
        ClassificationEngine(
            explicitRules: deterministicRules,
            curatedReviewPrefills: curatedReviewPrefills,
            heuristics: heuristics,
            seededHeuristicAutoAcceptEnabled: false
        )
    }

    private static func rule(
        _ pattern: String,
        _ categoryID: UUID,
        merchantName: String? = nil,
        matchKind: ClassificationRuleMatchKind = .contains
    ) -> ClassificationRule {
        ClassificationRule(
            merchantPattern: pattern,
            categoryID: categoryID,
            merchantName: merchantName,
            matchKind: matchKind,
            sourceReferenceKind: .seededSourceID
        )
        .canonicalizedDefaultCategory()
    }

    private static func heuristic(
        _ pattern: String,
        _ categoryID: UUID,
        merchantName: String? = nil
    ) -> ClassificationHeuristic {
        ClassificationHeuristic(
            merchantPattern: pattern,
            categoryID: categoryID,
            merchantName: merchantName
        )
        .canonicalizedDefaultCategory()
    }

    private static func curatedReviewPrefill(
        id: String,
        merchantPattern: String,
        categoryID: UUID,
        merchantName: String? = nil,
        matchKind: ClassificationRuleMatchKind = .contains
    ) -> CuratedReviewPrefill {
        CuratedReviewPrefill(
            id: id,
            merchantPattern: merchantPattern,
            assignment: ClassificationAssignment(
                categoryID: categoryID,
                merchantName: merchantName
            ),
            matchKind: matchKind
        )
        .canonicalizedDefaultCategory()
    }
}
