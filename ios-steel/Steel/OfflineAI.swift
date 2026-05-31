import Foundation
import NaturalLanguage

@MainActor
enum OfflineAI {
    static let homeExercises: [(String, Int, String, String)] = [
        ("Отжимания", 30, "раз", "figure.strengthtraining.traditional"),
        ("Приседания", 50, "раз", "figure.strengthtraining.traditional"),
        ("Планка", 60, "секунд", "timer"),
        ("Бёрпи", 15, "раз", "figure.highintensity.intervaltraining"),
        ("Скручивания", 30, "раз", "figure.core.training"),
        ("Выпады", 20, "раз", "figure.walk"),
        ("Велосипед", 40, "раз", "figure.outdoor.cycle"),
        ("Прыжки на месте", 50, "раз", "figure.jump"),
        ("Отжимания узким хватом", 20, "раз", "figure.strengthtraining.traditional"),
        ("Подъём ног лёжа", 20, "раз", "figure.core.training"),
        ("Горизонтальная тяга", 15, "раз", "figure.rower"),
        ("Супермен", 15, "раз", "figure.strengthtraining.traditional"),
        ("Приседания с выпрыгиванием", 20, "раз", "figure.highintensity.intervaltraining"),
        ("Отжимания от колен", 20, "раз", "figure.strengthtraining.traditional"),
        ("Мостик", 15, "раз", "figure.flexibility"),
    ]

    static let gymExercises: [(String, Int, String, String)] = [
        ("Жим лёжа", 12, "раз", "figure.strengthtraining.traditional"),
        ("Тяга штанги в наклоне", 12, "раз", "figure.strengthtraining.traditional"),
        ("Приседания со штангой", 15, "раз", "figure.strengthtraining.traditional"),
        ("Подтягивания", 10, "раз", "figure.strengthtraining.traditional"),
        ("Жим гантелей сидя", 12, "раз", "figure.strengthtraining.traditional"),
        ("Разгибание на трицепс", 15, "раз", "figure.strengthtraining.traditional"),
        ("Сгибание на бицепс", 15, "раз", "figure.strengthtraining.traditional"),
        ("Жим ногами", 15, "раз", "figure.strengthtraining.traditional"),
        ("Тяга верхнего блока", 12, "раз", "figure.strengthtraining.traditional"),
        ("Махи гантелями", 15, "раз", "figure.strengthtraining.traditional"),
        ("Сведение в бабочке", 15, "раз", "figure.strengthtraining.traditional"),
        ("Разгибание ног", 15, "раз", "figure.strengthtraining.traditional"),
        ("Сгибание ног", 15, "раз", "figure.strengthtraining.traditional"),
        ("Скручивания на блоке", 15, "раз", "figure.core.training"),
        ("Гиперэкстензия", 15, "раз", "figure.flexibility"),
    ]

    static let habitSuggestions: [(String, String)] = [
        ("Сахар", "cube"),
        ("Кофе", "cup.and.saucer.fill"),
        ("Соцсети", "phone.fill"),
        ("Курение", "smoke.fill"),
        ("Алкоголь", "wineglass.fill"),
        ("Поздний ужин", "moon.fill"),
        ("Недосып", "bed.double.fill"),
        ("Прокрастинация", "clock.fill"),
        ("Фастфуд", "takeoutbag.and.cup.and.straw.fill"),
        ("Газировка", "drop.fill"),
    ]

    struct Response {
        let message: String
        let commands: [AICommand]
    }

    static func respond(to userText: String, isHome: Bool?) -> Response {
        let lower = userText.lowercased()

        // Detect home/gym preference
        if lower.contains("дом") || lower.contains("дома") || lower.contains("домашн") {
            return Response(
                message: "Дома — тоже战场. Подбираю упражнения без оборудования. Что хочешь: силу, выносливость или похудение?",
                commands: []
            )
        }
        if lower.contains("зал") || lower.contains("спортзал") || lower.contains("тренажёр") || lower.contains("зале") {
            return Response(
                message: "Зал — дело серьёзное. Какие мышцы в приоритете? Или полная программа?",
                commands: []
            )
        }

        // Agreement — add exercises
        if lower.contains("да") || lower.contains("давай") || lower.contains("ок") || lower.contains("хочу") || lower.contains("добавляй") || lower.contains("соглас") {
            let useHome = isHome ?? true
            let exercises = useHome ? homeExercises : gymExercises
            let picked = exercises.shuffled().prefix(3)
            var commands: [AICommand] = []
            for ex in picked {
                commands.append(.addTask(title: ex.0, amount: ex.1, unit: ex.2, icon: ex.3))
            }
            let list = picked.map { "\($0.0) \($0.1) \($0.2)" }.joined(separator: ", ")
            return Response(
                message: "Добавил: \(list). Выполняй и не жалуйся.",
                commands: commands
            )
        }

        // Remove task
        if lower.contains("удал") || lower.contains("убер") || lower.contains("убра") {
            let tasks = DataManager.shared.fetchTasks()
            if let task = tasks.first(where: { lower.contains($0.title.lowercased()) }) {
                return Response(
                    message: "Убрал \(task.title). Слабо было?",
                    commands: [.removeTask(title: task.title)]
                )
            }
            return Response(message: "Какое задание удалить? Назови его.", commands: [])
        }

        // Add habit
        if lower.contains("привычк") || lower.contains("брос") || lower.contains("отказ") {
            let suggestion = habitSuggestions.randomElement()!
            return Response(
                message: "Начни с малого — «\(suggestion.0)». Добавить в привычки?",
                commands: []
            )
        }

        // Plan request
        if lower.contains("план") || lower.contains("программ") || lower.contains("расписан") {
            let useHome = isHome ?? true
            let exercises = useHome ? homeExercises : gymExercises
            let picked = exercises.shuffled().prefix(5)
            let planText = picked.map { "- \($0.0): \($0.1) \($0.2)" }.joined(separator: "\n")
            return Response(
                message: "Вот план на сегодня:\n\(planText)\nДобавить все задания?",
                commands: [.buildPlan(plan: planText)]
            )
        }

        // Strength
        if lower.contains("сил") || lower.contains("мощ") || lower.contains("мышц") {
            let useHome = isHome ?? true
            let exercises = useHome ? homeExercises : gymExercises
            let strength = exercises.filter { $0.1 <= 20 }.shuffled().prefix(3)
            var commands: [AICommand] = []
            for ex in strength { commands.append(.addTask(title: ex.0, amount: ex.1, unit: ex.2, icon: ex.3)) }
            let list = strength.map { "\($0.0) \($0.1) \($0.2)" }.joined(separator: ", ")
            return Response(
                message: "Для силы — меньше повторений, больше усилий. Добавил: \(list).",
                commands: commands
            )
        }

        // Endurance
        if lower.contains("выносл") || lower.contains("кардио") || lower.contains("бег") {
            let endurance = homeExercises.filter { $0.1 >= 30 }.shuffled().prefix(3)
            var commands: [AICommand] = []
            for ex in endurance { commands.append(.addTask(title: ex.0, amount: ex.1, unit: ex.2, icon: ex.3)) }
            let list = endurance.map { "\($0.0) \($0.1) \($0.2)" }.joined(separator: ", ")
            return Response(
                message: "Выносливость — это дисциплина. Добавил: \(list).",
                commands: commands
            )
        }

        // Weight loss
        if lower.contains("похуд") || lower.contains("вес") || lower.contains("жиры") || lower.contains("фигур") {
            let cardio = homeExercises.filter { $0.1 >= 30 }.shuffled().prefix(3)
            var commands: [AICommand] = []
            for ex in cardio { commands.append(.addTask(title: ex.0, amount: ex.1, unit: ex.2, icon: ex.3)) }
            return Response(
                message: "Хочешь похудеть? Дисциплина + дефицит. Добавлю кардио. Согласен?",
                commands: commands
            )
        }

        // Beginner
        if lower.contains("начина") || lower.contains("новичок") || lower.contains("лёгк") || lower.contains("прост") {
            let easy = homeExercises.filter { $0.1 <= 30 }.shuffled().prefix(3)
            var commands: [AICommand] = []
            for ex in easy { commands.append(.addTask(title: ex.0, amount: ex.1 / 2, unit: ex.2, icon: ex.3)) }
            return Response(
                message: "Начнём с малого. Добавлю половинную нагрузку. Согласен?",
                commands: commands
            )
        }

        // Greeting
        if lower.contains("привет") || lower.contains("здравств") || lower.contains("хай") || lower.contains("хелло") {
            return Response(
                message: "Привет. Ты занимаешься дома или в спортзале? Скажи, и я подберу тренировку.",
                commands: []
            )
        }

        // Default
        return Response(
            message: "Скажи: дома или зал? И что хочешь — силу, выносливость, похудение? Я подберу программу.",
            commands: []
        )
    }
}
