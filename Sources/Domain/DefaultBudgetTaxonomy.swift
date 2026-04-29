import Foundation

public struct DefaultCategoryGroupDefinition: Sendable {
    public var id: UUID
    public var name: String

    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

public struct DefaultBudgetCategoryDefinition: Sendable {
    public var id: UUID
    public var name: String
    public var kind: BudgetCategoryKind
    public var groupID: UUID?

    public init(id: UUID, name: String, kind: BudgetCategoryKind, groupID: UUID? = nil) {
        self.id = id
        self.name = name
        self.kind = kind
        self.groupID = groupID
    }
}

public enum DefaultBudgetTaxonomy {
    public enum CategoryGroupID {
        public static let housingAndUtilities = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        public static let foodAndDrink = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        public static let autoAndTransit = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
        public static let travel = UUID(uuidString: "10000000-0000-0000-0000-000000000005")!
        public static let lifestyleAndDiscretionary = UUID(uuidString: "10000000-0000-0000-0000-000000000006")!
        public static let healthAndWellness = UUID(uuidString: "10000000-0000-0000-0000-000000000007")!
        public static let familyAndHousehold = UUID(uuidString: "10000000-0000-0000-0000-000000000010")!
        public static let financial = UUID(uuidString: "10000000-0000-0000-0000-000000000011")!
    }

    public enum CategoryID {
        public static let homeAndUtilities = UUID(uuidString: "20000000-0000-0000-0000-000000000005")!
        public static let groceries = UUID(uuidString: "20000000-0000-0000-0000-000000000009")!
        public static let dining = UUID(uuidString: "20000000-0000-0000-0000-000000000010")!
        public static let transportation = UUID(uuidString: "20000000-0000-0000-0000-000000000012")!
        public static let travel = UUID(uuidString: "20000000-0000-0000-0000-000000000014")!
        public static let shoppingAndLifestyle = UUID(uuidString: "20000000-0000-0000-0000-000000000023")!
        public static let health = UUID(uuidString: "20000000-0000-0000-0000-000000000027")!
        public static let family = UUID(uuidString: "20000000-0000-0000-0000-000000000052")!
        public static let financial = UUID(uuidString: "20000000-0000-0000-0000-000000000043")!
        public static let income = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        public static let transfers = UUID(uuidString: "20000000-0000-0000-0000-000000000046")!

        // Temporary aliases so the rest of the codebase can be simplified in stages.
        public static let rentAndMortgage = homeAndUtilities
        public static let utilities = homeAndUtilities
        public static let internetAndPhone = homeAndUtilities
        public static let homeMaintenanceAndSupplies = homeAndUtilities
        public static let restaurantsAndBars = dining
        public static let coffeeShops = dining
        public static let gasAndCharging = transportation
        public static let publicTransitAndRideShare = transportation
        public static let autoMaintenanceAndInsurance = transportation
        public static let flights = travel
        public static let hotels = travel
        public static let shoppingAndClothing = shoppingAndLifestyle
        public static let subscriptionsAndEntertainment = shoppingAndLifestyle
        public static let personalCare = shoppingAndLifestyle
        public static let pets = shoppingAndLifestyle
        public static let funMoney = shoppingAndLifestyle
        public static let donations = shoppingAndLifestyle
        public static let medicalAndPharmacy = health
        public static let fitnessAndGym = health
        public static let childcareAndKidsActivities = family
        public static let educationAndStudentLoans = family
        public static let taxes = financial
        public static let feesAndBankCharges = financial
    }

    public enum LegacyCategoryID: String, CaseIterable, Sendable {
        case income = "20000000-0000-0000-0000-000000000001"
        case rentAndMortgage = "20000000-0000-0000-0000-000000000005"
        case homeMaintenanceAndSupplies = "20000000-0000-0000-0000-000000000008"
        case groceries = "20000000-0000-0000-0000-000000000009"
        case restaurantsAndBars = "20000000-0000-0000-0000-000000000010"
        case coffeeShops = "20000000-0000-0000-0000-000000000011"
        case gasAndCharging = "20000000-0000-0000-0000-000000000012"
        case publicTransitAndRideShare = "20000000-0000-0000-0000-000000000013"
        case flights = "20000000-0000-0000-0000-000000000014"
        case autoMaintenanceAndInsurance = "20000000-0000-0000-0000-000000000015"
        case hotels = "20000000-0000-0000-0000-000000000016"
        case utilities = "20000000-0000-0000-0000-000000000017"
        case internetAndPhone = "20000000-0000-0000-0000-000000000020"
        case subscriptionsAndEntertainment = "20000000-0000-0000-0000-000000000022"
        case shoppingAndClothing = "20000000-0000-0000-0000-000000000023"
        case medicalAndPharmacy = "20000000-0000-0000-0000-000000000027"
        case fitnessAndGym = "20000000-0000-0000-0000-000000000030"
        case personalCare = "20000000-0000-0000-0000-000000000039"
        case educationAndStudentLoans = "20000000-0000-0000-0000-000000000040"
        case feesAndBankCharges = "20000000-0000-0000-0000-000000000042"
        case taxes = "20000000-0000-0000-0000-000000000043"
        case transfers = "20000000-0000-0000-0000-000000000046"
        case pets = "20000000-0000-0000-0000-000000000050"
        case funMoney = "20000000-0000-0000-0000-000000000051"
        case childcareAndKidsActivities = "20000000-0000-0000-0000-000000000052"
        case donations = "20000000-0000-0000-0000-000000000053"

        public var id: UUID {
            UUID(uuidString: rawValue)!
        }
    }

    public static let categoryGroups: [DefaultCategoryGroupDefinition] = []

    public static let legacyCategoryGroups: [DefaultCategoryGroupDefinition] = [
        DefaultCategoryGroupDefinition(id: CategoryGroupID.housingAndUtilities, name: "Housing & Utilities"),
        DefaultCategoryGroupDefinition(id: CategoryGroupID.foodAndDrink, name: "Food & Drink"),
        DefaultCategoryGroupDefinition(id: CategoryGroupID.autoAndTransit, name: "Auto & Transit"),
        DefaultCategoryGroupDefinition(id: CategoryGroupID.travel, name: "Travel"),
        DefaultCategoryGroupDefinition(id: CategoryGroupID.lifestyleAndDiscretionary, name: "Lifestyle & Discretionary"),
        DefaultCategoryGroupDefinition(id: CategoryGroupID.healthAndWellness, name: "Health & Wellness"),
        DefaultCategoryGroupDefinition(id: CategoryGroupID.familyAndHousehold, name: "Family & Household"),
        DefaultCategoryGroupDefinition(id: CategoryGroupID.financial, name: "Financial"),
    ]

    public static let categories: [DefaultBudgetCategoryDefinition] = [
        DefaultBudgetCategoryDefinition(id: CategoryID.homeAndUtilities, name: "Home & Utilities", kind: .expense),
        DefaultBudgetCategoryDefinition(id: CategoryID.groceries, name: "Groceries", kind: .expense),
        DefaultBudgetCategoryDefinition(id: CategoryID.dining, name: "Dining", kind: .expense),
        DefaultBudgetCategoryDefinition(id: CategoryID.transportation, name: "Transportation", kind: .expense),
        DefaultBudgetCategoryDefinition(id: CategoryID.travel, name: "Travel", kind: .expense),
        DefaultBudgetCategoryDefinition(id: CategoryID.shoppingAndLifestyle, name: "Shopping & Lifestyle", kind: .expense),
        DefaultBudgetCategoryDefinition(id: CategoryID.health, name: "Health", kind: .expense),
        DefaultBudgetCategoryDefinition(id: CategoryID.family, name: "Kids & Education", kind: .expense),
        DefaultBudgetCategoryDefinition(id: CategoryID.financial, name: "Financial", kind: .expense),
        DefaultBudgetCategoryDefinition(id: CategoryID.income, name: "Income", kind: .income),
        DefaultBudgetCategoryDefinition(id: CategoryID.transfers, name: "Transfers", kind: .transfer),
    ]

    public static let legacyCategories: [DefaultBudgetCategoryDefinition] = [
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.rentAndMortgage.id, name: "Rent & Mortgage", kind: .expense, groupID: CategoryGroupID.housingAndUtilities),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.utilities.id, name: "Utilities", kind: .expense, groupID: CategoryGroupID.housingAndUtilities),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.internetAndPhone.id, name: "Internet & Phone", kind: .expense, groupID: CategoryGroupID.housingAndUtilities),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.homeMaintenanceAndSupplies.id, name: "Home Maintenance & Supplies", kind: .expense, groupID: CategoryGroupID.housingAndUtilities),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.groceries.id, name: "Groceries", kind: .expense, groupID: CategoryGroupID.foodAndDrink),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.restaurantsAndBars.id, name: "Restaurants & Bars", kind: .expense, groupID: CategoryGroupID.foodAndDrink),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.coffeeShops.id, name: "Coffee Shops", kind: .expense, groupID: CategoryGroupID.foodAndDrink),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.gasAndCharging.id, name: "Gas & Charging", kind: .expense, groupID: CategoryGroupID.autoAndTransit),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.publicTransitAndRideShare.id, name: "Public Transit & Ride Share", kind: .expense, groupID: CategoryGroupID.autoAndTransit),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.autoMaintenanceAndInsurance.id, name: "Auto Maintenance & Insurance", kind: .expense, groupID: CategoryGroupID.autoAndTransit),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.flights.id, name: "Flights", kind: .expense, groupID: CategoryGroupID.travel),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.hotels.id, name: "Hotels", kind: .expense, groupID: CategoryGroupID.travel),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.shoppingAndClothing.id, name: "Shopping & Clothing", kind: .expense, groupID: CategoryGroupID.lifestyleAndDiscretionary),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.subscriptionsAndEntertainment.id, name: "Subscriptions & Entertainment", kind: .expense, groupID: CategoryGroupID.lifestyleAndDiscretionary),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.personalCare.id, name: "Personal Care", kind: .expense, groupID: CategoryGroupID.lifestyleAndDiscretionary),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.pets.id, name: "Pets", kind: .expense, groupID: CategoryGroupID.lifestyleAndDiscretionary),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.funMoney.id, name: "Fun Money", kind: .expense, groupID: CategoryGroupID.lifestyleAndDiscretionary),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.donations.id, name: "Donations", kind: .expense, groupID: CategoryGroupID.lifestyleAndDiscretionary),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.medicalAndPharmacy.id, name: "Medical & Pharmacy", kind: .expense, groupID: CategoryGroupID.healthAndWellness),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.fitnessAndGym.id, name: "Fitness & Gym", kind: .expense, groupID: CategoryGroupID.healthAndWellness),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.childcareAndKidsActivities.id, name: "Childcare & Kids' Activities", kind: .expense, groupID: CategoryGroupID.familyAndHousehold),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.educationAndStudentLoans.id, name: "Education & Student Loans", kind: .expense, groupID: CategoryGroupID.familyAndHousehold),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.income.id, name: "Income", kind: .income, groupID: CategoryGroupID.financial),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.transfers.id, name: "Transfers", kind: .transfer, groupID: CategoryGroupID.financial),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.taxes.id, name: "Taxes", kind: .expense, groupID: CategoryGroupID.financial),
        DefaultBudgetCategoryDefinition(id: LegacyCategoryID.feesAndBankCharges.id, name: "Fees & Bank Charges", kind: .expense, groupID: CategoryGroupID.financial),
    ]

    public static let canonicalCategoryIDs = Set(categories.map(\.id))

    public static let categoryNameByID = Dictionary(
        uniqueKeysWithValues: categories.map { ($0.id, $0.name) }
    )

    public static let legacyToSimplifiedCategoryID: [UUID: UUID] = [
        LegacyCategoryID.income.id: CategoryID.income,
        LegacyCategoryID.rentAndMortgage.id: CategoryID.homeAndUtilities,
        LegacyCategoryID.utilities.id: CategoryID.homeAndUtilities,
        LegacyCategoryID.internetAndPhone.id: CategoryID.homeAndUtilities,
        LegacyCategoryID.homeMaintenanceAndSupplies.id: CategoryID.homeAndUtilities,
        LegacyCategoryID.groceries.id: CategoryID.groceries,
        LegacyCategoryID.restaurantsAndBars.id: CategoryID.dining,
        LegacyCategoryID.coffeeShops.id: CategoryID.dining,
        LegacyCategoryID.gasAndCharging.id: CategoryID.transportation,
        LegacyCategoryID.publicTransitAndRideShare.id: CategoryID.transportation,
        LegacyCategoryID.autoMaintenanceAndInsurance.id: CategoryID.transportation,
        LegacyCategoryID.flights.id: CategoryID.travel,
        LegacyCategoryID.hotels.id: CategoryID.travel,
        LegacyCategoryID.shoppingAndClothing.id: CategoryID.shoppingAndLifestyle,
        LegacyCategoryID.subscriptionsAndEntertainment.id: CategoryID.shoppingAndLifestyle,
        LegacyCategoryID.personalCare.id: CategoryID.shoppingAndLifestyle,
        LegacyCategoryID.pets.id: CategoryID.shoppingAndLifestyle,
        LegacyCategoryID.funMoney.id: CategoryID.shoppingAndLifestyle,
        LegacyCategoryID.donations.id: CategoryID.shoppingAndLifestyle,
        LegacyCategoryID.medicalAndPharmacy.id: CategoryID.health,
        LegacyCategoryID.fitnessAndGym.id: CategoryID.health,
        LegacyCategoryID.childcareAndKidsActivities.id: CategoryID.family,
        LegacyCategoryID.educationAndStudentLoans.id: CategoryID.family,
        LegacyCategoryID.taxes.id: CategoryID.financial,
        LegacyCategoryID.feesAndBankCharges.id: CategoryID.financial,
        LegacyCategoryID.transfers.id: CategoryID.transfers,
    ]

    public static let removedLegacyCategoryIDs: Set<UUID> = {
        let legacyCategoryIDs = Set(LegacyCategoryID.allCases.map(\.id))
        return legacyCategoryIDs.subtracting(canonicalCategoryIDs)
    }()

    public static func canonicalCategoryID(for categoryID: UUID) -> UUID? {
        if canonicalCategoryIDs.contains(categoryID) {
            return categoryID
        }
        return legacyToSimplifiedCategoryID[categoryID]
    }

    public static func isCanonicalCategoryID(_ categoryID: UUID) -> Bool {
        canonicalCategoryIDs.contains(categoryID)
    }

    public static func categoryName(for categoryID: UUID) -> String? {
        guard let canonicalCategoryID = canonicalCategoryID(for: categoryID) else {
            return nil
        }
        return categoryNameByID[canonicalCategoryID]
    }
}
