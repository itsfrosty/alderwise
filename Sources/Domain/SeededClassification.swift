import Foundation

public enum SeededClassification {
    public static let deterministicRules: [ClassificationRule] = [
        rule(
            "air india",
            DefaultBudgetTaxonomy.CategoryID.flights,
            merchantName: "Air India",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "emirates",
            DefaultBudgetTaxonomy.CategoryID.flights,
            merchantName: "Emirates",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "united airlines",
            DefaultBudgetTaxonomy.CategoryID.flights,
            merchantName: "United Airlines",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "turkish airlines",
            DefaultBudgetTaxonomy.CategoryID.flights,
            merchantName: "Turkish Airlines",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "grand hyatt",
            DefaultBudgetTaxonomy.CategoryID.hotels,
            merchantName: "Grand Hyatt",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "marriott marquis",
            DefaultBudgetTaxonomy.CategoryID.hotels,
            merchantName: "Marriott Marquis",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "westin st francis",
            DefaultBudgetTaxonomy.CategoryID.hotels,
            merchantName: "Westin St. Francis",
            matchKind: .prefixNormalizedMerchant
        ),
        rule("costco rx", DefaultBudgetTaxonomy.CategoryID.medicalAndPharmacy, merchantName: "Costco RX"),
        rule("costco annual", DefaultBudgetTaxonomy.CategoryID.subscriptionsAndEntertainment, merchantName: "Costco Annual"),
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
        rule("walmart com", DefaultBudgetTaxonomy.CategoryID.shoppingAndClothing, merchantName: "Walmart"),
        rule("walmart", DefaultBudgetTaxonomy.CategoryID.shoppingAndClothing, merchantName: "Walmart"),
        rule("wal mart", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "Walmart"),
        rule("macys", DefaultBudgetTaxonomy.CategoryID.shoppingAndClothing, merchantName: "Macy's"),
        rule("amazon", DefaultBudgetTaxonomy.CategoryID.shoppingAndClothing, merchantName: "Amazon"),
        rule("target", DefaultBudgetTaxonomy.CategoryID.groceries, merchantName: "Target"),
        rule("temu", DefaultBudgetTaxonomy.CategoryID.shoppingAndClothing, merchantName: "Temu"),
        rule("ross stores", DefaultBudgetTaxonomy.CategoryID.shoppingAndClothing, merchantName: "Ross"),
        rule("burlington stores", DefaultBudgetTaxonomy.CategoryID.shoppingAndClothing, merchantName: "Burlington"),
        rule("t j maxx", DefaultBudgetTaxonomy.CategoryID.shoppingAndClothing, merchantName: "T.J. Maxx"),
        rule("marshalls", DefaultBudgetTaxonomy.CategoryID.shoppingAndClothing, merchantName: "Marshalls"),
        rule("netflix", DefaultBudgetTaxonomy.CategoryID.subscriptionsAndEntertainment, merchantName: "Netflix"),
        rule("spotify", DefaultBudgetTaxonomy.CategoryID.subscriptionsAndEntertainment, merchantName: "Spotify"),
        rule("hulu", DefaultBudgetTaxonomy.CategoryID.subscriptionsAndEntertainment, merchantName: "Hulu"),
        rule("disney plus", DefaultBudgetTaxonomy.CategoryID.subscriptionsAndEntertainment, merchantName: "Disney Plus"),
        rule("disneyplus", DefaultBudgetTaxonomy.CategoryID.subscriptionsAndEntertainment, merchantName: "Disney Plus"),
        rule("amazon prime", DefaultBudgetTaxonomy.CategoryID.subscriptionsAndEntertainment, merchantName: "Amazon Prime"),
        rule("google google one", DefaultBudgetTaxonomy.CategoryID.subscriptionsAndEntertainment, merchantName: "Google One"),
        rule("youtube", DefaultBudgetTaxonomy.CategoryID.subscriptionsAndEntertainment, merchantName: "YouTube"),
        rule("openai", DefaultBudgetTaxonomy.CategoryID.subscriptionsAndEntertainment, merchantName: "OpenAI"),
        rule("apple com", DefaultBudgetTaxonomy.CategoryID.subscriptionsAndEntertainment, merchantName: "Apple"),
        rule("meta payroll", DefaultBudgetTaxonomy.CategoryID.income, merchantName: "Meta Payroll"),
        rule(
            "meta direct dep",
            DefaultBudgetTaxonomy.CategoryID.income,
            merchantName: "Meta Direct Deposit",
            matchKind: .prefixNormalizedMerchant
        ),
        rule("interest payment", DefaultBudgetTaxonomy.CategoryID.income, merchantName: "Interest Payment"),
        rule(
            "interest paid",
            DefaultBudgetTaxonomy.CategoryID.income,
            merchantName: "Interest Paid",
            matchKind: .prefixNormalizedMerchant
        ),
        rule("rocket mortgage", DefaultBudgetTaxonomy.CategoryID.rentAndMortgage, merchantName: "Rocket Mortgage"),
        rule("flagstar bank", DefaultBudgetTaxonomy.CategoryID.rentAndMortgage, merchantName: "Flagstar Bank"),
        rule("cim 37 degrees n", DefaultBudgetTaxonomy.CategoryID.homeMaintenanceAndSupplies, merchantName: "CIM-37 Degrees N"),
        rule("citi autopay", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "Citi Autopay"),
        rule("chase credit crd", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "Chase Credit Card"),
        rule("tjx rewards payment", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "TJX Rewards Payment"),
        rule(
            "automatic payment thank",
            DefaultBudgetTaxonomy.CategoryID.transfers,
            merchantName: "Automatic Payment Thank You",
            matchKind: .prefixNormalizedMerchant
        ),
        rule("ally bank p2p", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "Ally Bank P2P"),
        rule("autopay", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "Autopay"),
        rule("venmo", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "Venmo"),
        rule("zelle", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "Zelle"),
        rule("vanguard", DefaultBudgetTaxonomy.CategoryID.transfers, merchantName: "Vanguard"),
        rule("guardianwp", DefaultBudgetTaxonomy.CategoryID.utilities, merchantName: "Guardian Water & Power"),
        rule("pgande", DefaultBudgetTaxonomy.CategoryID.utilities, merchantName: "PG&E"),
        rule("comcast", DefaultBudgetTaxonomy.CategoryID.internetAndPhone, merchantName: "Comcast"),
        rule("xfinity", DefaultBudgetTaxonomy.CategoryID.internetAndPhone, merchantName: "Xfinity"),
        rule("verizon", DefaultBudgetTaxonomy.CategoryID.internetAndPhone, merchantName: "Verizon"),
        rule("t mobile", DefaultBudgetTaxonomy.CategoryID.internetAndPhone, merchantName: "T-Mobile"),
        rule("mindbody", DefaultBudgetTaxonomy.CategoryID.fitnessAndGym, merchantName: "Mindbody"),
        rule("usaa", DefaultBudgetTaxonomy.CategoryID.autoMaintenanceAndInsurance, merchantName: "USAA"),
        rule(
            "progressive ins",
            DefaultBudgetTaxonomy.CategoryID.autoMaintenanceAndInsurance,
            merchantName: "Progressive",
            matchKind: .prefixNormalizedMerchant
        ),
        rule("dmv", DefaultBudgetTaxonomy.CategoryID.autoMaintenanceAndInsurance, merchantName: "DMV"),
        rule("yell madison camp", DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities, merchantName: "Yell Madison Camp"),
        rule("bright horizons", DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities, merchantName: "Bright Horizons"),
        rule(
            "airborne gymnastics",
            DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities,
            merchantName: "Airborne Gymnastics",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "waterworks swim",
            DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities,
            merchantName: "Waterworks Swim",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "tutu school",
            DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities,
            merchantName: "Tutu School",
            matchKind: .prefixNormalizedMerchant
        ),
        rule(
            "first position dance",
            DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities,
            merchantName: "First Position Dance",
            matchKind: .prefixNormalizedMerchant
        ),
        rule("facts", DefaultBudgetTaxonomy.CategoryID.educationAndStudentLoans, merchantName: "FACTS"),
        rule(
            "bb tuition mgmt",
            DefaultBudgetTaxonomy.CategoryID.educationAndStudentLoans,
            merchantName: "BB Tuition Mgmt",
            matchKind: .prefixNormalizedMerchant
        ),
        rule("beast academy", DefaultBudgetTaxonomy.CategoryID.educationAndStudentLoans, merchantName: "Beast Academy"),
        rule("king s academy", DefaultBudgetTaxonomy.CategoryID.educationAndStudentLoans, merchantName: "The King's Academy"),
        rule("joe the juice", DefaultBudgetTaxonomy.CategoryID.coffeeShops, merchantName: "Joe & The Juice"),
        rule("blue bottle coffee", DefaultBudgetTaxonomy.CategoryID.coffeeShops, merchantName: "Blue Bottle Coffee"),
        rule("tesla", DefaultBudgetTaxonomy.CategoryID.gasAndCharging, merchantName: "Tesla"),
        rule("waymo", DefaultBudgetTaxonomy.CategoryID.publicTransitAndRideShare, merchantName: "Waymo"),
        rule("uber", DefaultBudgetTaxonomy.CategoryID.publicTransitAndRideShare, merchantName: "Uber"),
        rule("lyft", DefaultBudgetTaxonomy.CategoryID.publicTransitAndRideShare, merchantName: "Lyft"),
        rule("golden gate bridge", DefaultBudgetTaxonomy.CategoryID.publicTransitAndRideShare, merchantName: "Golden Gate Bridge"),
        rule("parkwhiz", DefaultBudgetTaxonomy.CategoryID.publicTransitAndRideShare, merchantName: "ParkWhiz"),
        rule("connectyourcare", DefaultBudgetTaxonomy.CategoryID.medicalAndPharmacy, merchantName: "ConnectYourCare"),
        rule("cvs", DefaultBudgetTaxonomy.CategoryID.medicalAndPharmacy, merchantName: "CVS"),
        rule("pamf", DefaultBudgetTaxonomy.CategoryID.medicalAndPharmacy, merchantName: "PAMF"),
        rule("irs", DefaultBudgetTaxonomy.CategoryID.taxes, merchantName: "IRS"),
        rule("franchise tax bo", DefaultBudgetTaxonomy.CategoryID.taxes, merchantName: "Franchise Tax Board"),
        rule("dishdash", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "Dishdash"),
        rule("merit vegan", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "Merit Vegan"),
        rule("sri anandabhavan", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "Sri Anandabhavan"),
        rule("halal fried chicken", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "Halal Fried Chicken"),
        rule("halal fried", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "Halal Fried"),
        rule("chick fil a", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "Chick-fil-A"),
        rule("khans karahi kabob", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "Khans Karahi Kabob"),
        rule("happy sushi", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "Happy Sushi"),
        rule("tobang korean bbq", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "Tobang Korean BBQ"),
        rule("chipotle", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "Chipotle"),
        rule("in n out", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "In-N-Out"),
        rule("zeni ethiopian", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "Zeni Ethiopian"),
        rule("mumu hot pot", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "Mumu Hot Pot"),
        rule("mylapore", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "Mylapore"),
        rule("atlas pizza", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "Atlas Pizza"),
        rule("taj mahal", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars, merchantName: "Taj Mahal"),
        rule("shirdi sai", DefaultBudgetTaxonomy.CategoryID.funMoney, merchantName: "Shirdi Sai"),
    ]

    public static let heuristics: [ClassificationHeuristic] = [
        heuristic("pizza", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("pizzeria", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("restaurant", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("burger", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("taco", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("tacos", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("ramen", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("kabob", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("kebab", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("sushi", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("hot pot", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("chaat", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("momo", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("wok", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("baguette", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("creamery", DefaultBudgetTaxonomy.CategoryID.restaurantsAndBars),
        heuristic("cafe", DefaultBudgetTaxonomy.CategoryID.coffeeShops),
        heuristic("coffee", DefaultBudgetTaxonomy.CategoryID.coffeeShops),
        heuristic("espresso", DefaultBudgetTaxonomy.CategoryID.coffeeShops),
        heuristic("pharmacy", DefaultBudgetTaxonomy.CategoryID.medicalAndPharmacy),
        heuristic("rx", DefaultBudgetTaxonomy.CategoryID.medicalAndPharmacy),
        heuristic("payroll", DefaultBudgetTaxonomy.CategoryID.income),
        heuristic("salary", DefaultBudgetTaxonomy.CategoryID.income),
        heuristic("direct deposit", DefaultBudgetTaxonomy.CategoryID.income),
        heuristic("transfer", DefaultBudgetTaxonomy.CategoryID.transfers),
        heuristic("zelle", DefaultBudgetTaxonomy.CategoryID.transfers),
        heuristic("atm withdrawal", DefaultBudgetTaxonomy.CategoryID.transfers),
        heuristic("uber", DefaultBudgetTaxonomy.CategoryID.publicTransitAndRideShare),
        heuristic("lyft", DefaultBudgetTaxonomy.CategoryID.publicTransitAndRideShare),
        heuristic("supermarket", DefaultBudgetTaxonomy.CategoryID.groceries),
        heuristic("farmers mark", DefaultBudgetTaxonomy.CategoryID.groceries),
        heuristic("cash carry", DefaultBudgetTaxonomy.CategoryID.groceries),
        heuristic("market", DefaultBudgetTaxonomy.CategoryID.groceries),
    ]

    public static let curatedReviewPrefills: [CuratedReviewPrefill] = [
        curatedReviewPrefill(
            id: "starter.issuer-credit.platinum-digital-entertainment-credit",
            merchantPattern: "platinum digital entertainment credit",
            categoryID: DefaultBudgetTaxonomy.CategoryID.subscriptionsAndEntertainment,
            merchantName: "Platinum Digital Entertainment Credit",
            matchKind: .exactNormalizedMerchant
        ),
        curatedReviewPrefill(
            id: "starter.issuer-credit.amex-airline-fee-reimbursement",
            merchantPattern: "amex airline fee reimbursement",
            categoryID: DefaultBudgetTaxonomy.CategoryID.flights,
            merchantName: "Amex Airline Fee Reimbursement",
            matchKind: .exactNormalizedMerchant
        ),
        curatedReviewPrefill(
            id: "starter.issuer-credit.platinum-hotel-credit",
            merchantPattern: "platinum hotel credit",
            categoryID: DefaultBudgetTaxonomy.CategoryID.hotels,
            merchantName: "Platinum Hotel Credit",
            matchKind: .exactNormalizedMerchant
        ),
        curatedReviewPrefill(
            id: "starter.travel.booking-com",
            merchantPattern: "booking com",
            categoryID: DefaultBudgetTaxonomy.CategoryID.hotels,
            merchantName: "Booking.com",
            matchKind: .prefixNormalizedMerchant
        ),
        curatedReviewPrefill(
            id: "starter.travel.amex-travel",
            merchantPattern: "amex travel",
            categoryID: DefaultBudgetTaxonomy.CategoryID.hotels,
            merchantName: "Amex Travel",
            matchKind: .prefixNormalizedMerchant
        ),
        curatedReviewPrefill(
            id: "starter.99pledg.family",
            merchantPattern: "99pledg",
            categoryID: DefaultBudgetTaxonomy.CategoryID.donations,
            merchantName: "99PLEDG",
            matchKind: .prefixNormalizedMerchant
        ),
        curatedReviewPrefill(
            id: "starter.school-family.choicelunch",
            merchantPattern: "choicelunch",
            categoryID: DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities,
            merchantName: "Choicelunch",
            matchKind: .prefixNormalizedMerchant
        ),
        curatedReviewPrefill(
            id: "starter.school-family.lineleader",
            merchantPattern: "lineleader",
            categoryID: DefaultBudgetTaxonomy.CategoryID.childcareAndKidsActivities,
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
    }
}
