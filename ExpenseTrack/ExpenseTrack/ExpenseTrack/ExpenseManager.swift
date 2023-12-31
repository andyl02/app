import SwiftUI
import Combine
import CoreData

/// `ExpenseManager` is a class that manages all expense-related operations.
///
/// This class provides published properties for expenses, categories, budgets, and expenses by category. It also provides methods for fetching expenses from Core Data, adding and deleting expenses and categories, setting and getting budgets for categories, calculating total expenses for a category, calculating the remaining budget for a category, saving the Core Data context, and fetching data from an API.
struct APIExpense: Decodable {
    let amount: Double
    let category: String
}

/// Manages all expense-related operations.
class ExpenseManager: ObservableObject {
    
    /// An array of expenses.
    @Published var expenses: [Expense] = []
    
    /// An array of categories.
    @Published var categories: [String] = ["Food", "Transport", "Entertainment", "Utilities", "Rent", "Miscellaneous"]
    
    /// A dictionary of budgets keyed by category.
    @Published var budgets: [String: Double] = [:]
    
    /// A dictionary of expenses by category.
    @Published var expensesByCategory: [String: Double] = [:]
    
    /// The Core Data stack.
    var coreDataStack = CoreDataStack.shared
    
    /// Initializes the expense manager.
    init() {
        do {
            try fetchExpenses()
            fetchDataFromAPI()
            loadBudgetsFromCoreData()
        } catch let error {
            print("Initialization failed: \(error)")
        }
    }
    
    /// Fetches expenses from Core Data.
    /// - Throws: An error if the fetch operation fails.
    func fetchExpenses() throws {
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        do {
            expenses = try coreDataStack.context.fetch(fetchRequest)
            updateExpensesByCategory()
        } catch {
            throw ExpenseManagerError.fetchFailed
        }
    }

    /// Adds a new category.
    /// - Parameter category: The category to add.
    func addCategory(_ category: String) {
        categories.append(category)
        saveContext()
    }

    /// Deletes a category.
    /// - Parameter offsets: The index set of the category to delete.
    func deleteCategory(at offsets: IndexSet) {
        for index in offsets {
            let category = categories[index]
            categories.remove(at: index)
            budgets[category] = nil
        }
        saveContext()
    }
    
    /// Sets the budget for a category.
    /// - Parameters:
    /// - category: The category for which to set the budget.
    /// - amount: The budget amount.
    func setBudget(for category: String, amount: Double) {
        budgets[category] = amount
        saveBudgetsToCoreData()
        NotificationCenter.default.post(name: NSNotification.Name("BudgetSaved"), object: nil)
    }
    
    /// Gets the budget for a category.
    /// - Parameter category: The category for which to get the budget.
    /// - Returns: The budget amount.
    func getBudget(for category: String) -> Double {
        return budgets[category] ?? 0.0
    }

    /// Calculates the total expenses for a category.
    /// - Parameter category: The category for which to calculate the total.
    /// - Returns: The total expenses for the category.
    func totalForCategory(_ category: String) -> Double {
        return expenses.filter { $0.category == category }.reduce(0) { $0 + $1.amount }
    }

    /// Calculates the remaining budget for a category.
    /// - Parameter category: The category for which to calculate the remaining budget.
    /// - Returns: The remaining budget for the category.
    func remainingBudget(for category: String) -> Double {
        let totalExpensesForCategory = expenses.filter { $0.category == category }.map { $0.amount }.reduce(0, +)
        let budgetForCategory = getBudget(for: category)
        return budgetForCategory - totalExpensesForCategory
    }

    /// Saves the Core Data context.
    func saveContext() {
        do {
            try coreDataStack.context.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }

    /// Defines errors that can occur in `ExpenseManager`.
    enum ExpenseManagerError: Error {
        case fetchFailed
        case saveFailed
        case deleteFailed
    }
    
    /// Fetches data from an API.
    func fetchDataFromAPI() {
        NetworkManager.shared.fetchJSONData(url: "https://api.example.com/data") { (result: Result<[APIExpense], NetworkError>) in
            switch result {
            case .success(let decodedData):
                print("Successfully fetched data: \(decodedData)")
            case .failure(let error):
                print("Error fetching data: \(error)")
            }
        }
    }
    
    /// Updates the expenses by category.
    func updateExpensesByCategory() {
        var newExpensesByCategory: [String: Double] = [:]
        for expense in expenses {
            let category = expense.category ?? "Unknown"
            let amount = expense.amount
            newExpensesByCategory[category, default: 0] += amount
        }
        expensesByCategory = newExpensesByCategory
    }

    /// Saves budgets to Core Data.
    func saveBudgetsToCoreData() {
        do {
            let data = try JSONEncoder().encode(budgets)
            UserDefaults.standard.set(data, forKey: "budgets")
            print("Budgets saved to Core Data")
        } catch {
            print("Failed to save budgets: \(error)")
        }
    }
    
    /// Loads budgets from Core Data.
    func loadBudgetsFromCoreData() {
        if let data = UserDefaults.standard.data(forKey: "budgets") {
            do {
                budgets = try JSONDecoder().decode([String: Double].self, from: data)
                print("Budgets loaded from Core Data")
            } catch {
                print("Failed to load budgets: \(error)")
            }
        }
    }

    /// Adds a new expense.
    /// - Parameters:
    ///   - amount: The amount of the new expense.
    ///   - category: The category of the new expense.
    ///   - note: A note for the new expense.
    func addExpense(amount: Double, category: String, note: String) {
        let newExpense = Expense(context: coreDataStack.context)
        newExpense.amount = amount
        newExpense.category = category
        newExpense.note = note
        expenses.append(newExpense)
        saveContext()
    }
}
