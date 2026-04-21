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
    public var groupID: UUID

    public init(id: UUID, name: String, kind: BudgetCategoryKind, groupID: UUID) {
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
        public static let lifestyleAndDiscretionary = UUID(uuidString: "10000000-0000-0000-0000-000000000006")!
        public static let healthAndWellness = UUID(uuidString: "10000000-0000-0000-0000-000000000007")!
        public static let familyAndHousehold = UUID(uuidString: "10000000-0000-0000-0000-000000000010")!
        public static let financial = UUID(uuidString: "10000000-0000-0000-0000-000000000011")!
    }

    public enum CategoryID {
        public static let rentAndMortgage = UUID(uuidString: "20000000-0000-0000-0000-000000000005")!
        public static let utilities = UUID(uuidString: "20000000-0000-0000-0000-000000000017")!
        public static let internetAndPhone = UUID(uuidString: "20000000-0000-0000-0000-000000000020")!
        public static let homeMaintenanceAndSupplies = UUID(uuidString: "20000000-0000-0000-0000-000000000008")!
        public static let groceries = UUID(uuidString: "20000000-0000-0000-0000-000000000009")!
        public static let restaurantsAndBars = UUID(uuidString: "20000000-0000-0000-0000-000000000010")!
        public static let coffeeShops = UUID(uuidString: "20000000-0000-0000-0000-000000000011")!
        public static let gasAndCharging = UUID(uuidString: "20000000-0000-0000-0000-000000000012")!
        public static let publicTransitAndRideShare = UUID(uuidString: "20000000-0000-0000-0000-000000000013")!
        public static let autoMaintenanceAndInsurance = UUID(uuidString: "20000000-0000-0000-0000-000000000015")!
        public static let shoppingAndClothing = UUID(uuidString: "20000000-0000-0000-0000-000000000023")!
        public static let subscriptionsAndEntertainment = UUID(uuidString: "20000000-0000-0000-0000-000000000022")!
        public static let personalCare = UUID(uuidString: "20000000-0000-0000-0000-000000000039")!
        public static let pets = UUID(uuidString: "20000000-0000-0000-0000-000000000050")!
        public static let funMoney = UUID(uuidString: "20000000-0000-0000-0000-000000000051")!
        public static let medicalAndPharmacy = UUID(uuidString: "20000000-0000-0000-0000-000000000027")!
        public static let fitnessAndGym = UUID(uuidString: "20000000-0000-0000-0000-000000000030")!
        public static let childcareAndKidsActivities = UUID(uuidString: "20000000-0000-0000-0000-000000000052")!
        public static let educationAndStudentLoans = UUID(uuidString: "20000000-0000-0000-0000-000000000040")!
        public static let income = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        public static let transfers = UUID(uuidString: "20000000-0000-0000-0000-000000000046")!
        public static let taxes = UUID(uuidString: "20000000-0000-0000-0000-000000000043")!
        public static let feesAndBankCharges = UUID(uuidString: "20000000-0000-0000-0000-000000000042")!
    }

    public static let categoryGroups: [DefaultCategoryGroupDefinition] = [
        DefaultCategoryGroupDefinition(id: CategoryGroupID.housingAndUtilities, name: "Housing & Utilities"),
        DefaultCategoryGroupDefinition(id: CategoryGroupID.foodAndDrink, name: "Food & Drink"),
        DefaultCategoryGroupDefinition(id: CategoryGroupID.autoAndTransit, name: "Auto & Transit"),
        DefaultCategoryGroupDefinition(id: CategoryGroupID.lifestyleAndDiscretionary, name: "Lifestyle & Discretionary"),
        DefaultCategoryGroupDefinition(id: CategoryGroupID.healthAndWellness, name: "Health & Wellness"),
        DefaultCategoryGroupDefinition(id: CategoryGroupID.familyAndHousehold, name: "Family & Household"),
        DefaultCategoryGroupDefinition(id: CategoryGroupID.financial, name: "Financial"),
    ]

    public static let categories: [DefaultBudgetCategoryDefinition] = [
        DefaultBudgetCategoryDefinition(id: CategoryID.rentAndMortgage, name: "Rent & Mortgage", kind: .expense, groupID: CategoryGroupID.housingAndUtilities),
        DefaultBudgetCategoryDefinition(id: CategoryID.utilities, name: "Utilities", kind: .expense, groupID: CategoryGroupID.housingAndUtilities),
        DefaultBudgetCategoryDefinition(id: CategoryID.internetAndPhone, name: "Internet & Phone", kind: .expense, groupID: CategoryGroupID.housingAndUtilities),
        DefaultBudgetCategoryDefinition(id: CategoryID.homeMaintenanceAndSupplies, name: "Home Maintenance & Supplies", kind: .expense, groupID: CategoryGroupID.housingAndUtilities),
        DefaultBudgetCategoryDefinition(id: CategoryID.groceries, name: "Groceries", kind: .expense, groupID: CategoryGroupID.foodAndDrink),
        DefaultBudgetCategoryDefinition(id: CategoryID.restaurantsAndBars, name: "Restaurants & Bars", kind: .expense, groupID: CategoryGroupID.foodAndDrink),
        DefaultBudgetCategoryDefinition(id: CategoryID.coffeeShops, name: "Coffee Shops", kind: .expense, groupID: CategoryGroupID.foodAndDrink),
        DefaultBudgetCategoryDefinition(id: CategoryID.gasAndCharging, name: "Gas & Charging", kind: .expense, groupID: CategoryGroupID.autoAndTransit),
        DefaultBudgetCategoryDefinition(id: CategoryID.publicTransitAndRideShare, name: "Public Transit & Ride Share", kind: .expense, groupID: CategoryGroupID.autoAndTransit),
        DefaultBudgetCategoryDefinition(id: CategoryID.autoMaintenanceAndInsurance, name: "Auto Maintenance & Insurance", kind: .expense, groupID: CategoryGroupID.autoAndTransit),
        DefaultBudgetCategoryDefinition(id: CategoryID.shoppingAndClothing, name: "Shopping & Clothing", kind: .expense, groupID: CategoryGroupID.lifestyleAndDiscretionary),
        DefaultBudgetCategoryDefinition(id: CategoryID.subscriptionsAndEntertainment, name: "Subscriptions & Entertainment", kind: .expense, groupID: CategoryGroupID.lifestyleAndDiscretionary),
        DefaultBudgetCategoryDefinition(id: CategoryID.personalCare, name: "Personal Care", kind: .expense, groupID: CategoryGroupID.lifestyleAndDiscretionary),
        DefaultBudgetCategoryDefinition(id: CategoryID.pets, name: "Pets", kind: .expense, groupID: CategoryGroupID.lifestyleAndDiscretionary),
        DefaultBudgetCategoryDefinition(id: CategoryID.funMoney, name: "Fun Money", kind: .expense, groupID: CategoryGroupID.lifestyleAndDiscretionary),
        DefaultBudgetCategoryDefinition(id: CategoryID.medicalAndPharmacy, name: "Medical & Pharmacy", kind: .expense, groupID: CategoryGroupID.healthAndWellness),
        DefaultBudgetCategoryDefinition(id: CategoryID.fitnessAndGym, name: "Fitness & Gym", kind: .expense, groupID: CategoryGroupID.healthAndWellness),
        DefaultBudgetCategoryDefinition(id: CategoryID.childcareAndKidsActivities, name: "Childcare & Kids' Activities", kind: .expense, groupID: CategoryGroupID.familyAndHousehold),
        DefaultBudgetCategoryDefinition(id: CategoryID.educationAndStudentLoans, name: "Education & Student Loans", kind: .expense, groupID: CategoryGroupID.familyAndHousehold),
        DefaultBudgetCategoryDefinition(id: CategoryID.income, name: "Income", kind: .income, groupID: CategoryGroupID.financial),
        DefaultBudgetCategoryDefinition(id: CategoryID.transfers, name: "Transfers", kind: .transfer, groupID: CategoryGroupID.financial),
        DefaultBudgetCategoryDefinition(id: CategoryID.taxes, name: "Taxes", kind: .expense, groupID: CategoryGroupID.financial),
        DefaultBudgetCategoryDefinition(id: CategoryID.feesAndBankCharges, name: "Fees & Bank Charges", kind: .expense, groupID: CategoryGroupID.financial),
    ]
}
