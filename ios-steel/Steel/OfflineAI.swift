import Foundation
import NaturalLanguage

@MainActor
enum OfflineAI {
    static let homeExercises: [(String, Int, String, String)] = [
        ("Отжимания", 50, "раз", "figure.strengthtraining.traditional"),
        ("Приседания", 80, "раз", "figure.strengthtraining.traditional"),
        ("Планка", 90, "секунд", "timer"),
        ("Бёрпи", 30, "раз", "figure.highintensity.intervaltraining"),
        ("Скручивания", 50, "раз", "figure.core.training"),
        ("Выпады", 40, "раз", "figure.walk"),
        ("Прыжки на месте", 100, "раз", "figure.jump"),
        ("Отжимания узким хватом", 30, "раз", "figure.strengthtraining.traditional"),
        ("Подъём ног лёжа", 30, "раз", "figure.core.training"),
        ("Супермен", 25, "раз", "figure.strengthtraining.traditional"),
        ("Приседания с выпрыгиванием", 30, "раз", "figure.highintensity.intervaltraining"),
        ("Мостик", 20, "раз", "figure.flexibility"),
        ("Альпинист", 40, "раз", "figure.highintensity.intervaltraining"),
        ("Отжимания алмазом", 25, "раз", "figure.strengthtraining.traditional"),
        ("Приседания сумо", 50, "раз", "figure.strengthtraining.traditional"),
    ]

    static let gymExercises: [(String, Int, String, String)] = [
        ("Жим лёжа", 15, "раз", "figure.strengthtraining.traditional"),
        ("Тяга штанги в наклоне", 15, "раз", "figure.strengthtraining.traditional"),
        ("Приседания со штангой", 20, "раз", "figure.strengthtraining.traditional"),
        ("Подтягивания", 12, "раз", "figure.strengthtraining.traditional"),
        ("Жим гантелей сидя", 15, "раз", "figure.strengthtraining.traditional"),
        ("Разгибание на трицепс", 20, "раз", "figure.strengthtraining.traditional"),
        ("Сгибание на бицепс", 20, "раз", "figure.strengthtraining.traditional"),
        ("Жим ногами", 20, "раз", "figure.strengthtraining.traditional"),
        ("Тяга верхнего блока", 15, "раз", "figure.strengthtraining.traditional"),
        ("Махи гантелями", 20, "раз", "figure.strengthtraining.traditional"),
        ("Становая тяга", 12, "раз", "figure.strengthtraining.traditional"),
        ("Выпады с гантелями", 20, "раз", "figure.walk"),
        ("Отжимания на брусьях", 15, "раз", "figure.strengthtraining.traditional"),
        ("Скручивания на блоке", 20, "раз", "figure.core.training"),
        ("Гиперэкстензия", 20, "раз", "figure.flexibility"),
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
        ("Лень", "couch"),
        ("Переедание", "fork.knife"),
    ]

    struct Response {
        let message: String
        let commands: [AICommand]
    }

    static func respond(to userText: String, isHome: Bool?) -> Response {
        let lower = userText.lowercased()
        let settings = DataManager.shared.settings
        let tasks = DataManager.shared.fetchTasks()
        let done = tasks.filter(\.isCompleted).count

        if lower.contains("дом") || lower.contains("дома") || lower.contains("домашн") {
            return Response(
                message: "Дома? Отлично. Не нужно оборудования чтобы стать сильнее. Назначаю тренировку. Выполняй.",
                commands: buildWorkoutCommands(isHome: true, count: 4)
            )
        }
        if lower.contains("зал") || lower.contains("спортзал") || lower.contains("тренажёр") || lower.contains("зале") {
            return Response(
                message: "Зал — это серьёзно. Назначаю программу. Без отговорок.",
                commands: buildWorkoutCommands(isHome: false, count: 4)
            )
        }

        if lower.contains("да") || lower.contains("давай") || lower.contains("ок") || lower.contains("хочу") || lower.contains("добавляй") || lower.contains("соглас") || lower.contains("тренировк") || lower.contains("заниматься") {
            let useHome = isHome ?? true
            return Response(
                message: "Хочешь тренировку? Получай. Без жалоб.",
                commands: buildWorkoutCommands(isHome: useHome, count: 4)
            )
        }

        if lower.contains("удал") || lower.contains("убер") || lower.contains("убра") {
            let tasks = DataManager.shared.fetchTasks()
            if let task = tasks.first(where: { lower.contains($0.title.lowercased()) }) {
                return Response(
                    message: "Убираю \(task.title). Слабак сдаётся. Добавляю привычку вместо этого.",
                    commands: [.removeTask(title: task.title), .addHabit(title: "Лень", icon: "couch")]
                )
            }
            return Response(message: "Какое задание удалить? Назови. И не смей лениться.", commands: [])
        }

        if lower.contains("привычк") || lower.contains("брос") || lower.contains("отказ") {
            let suggestion = habitSuggestions.randomElement()!
            let useHome = isHome ?? true
            var cmds: [AICommand] = [.addHabit(title: suggestion.0, icon: suggestion.1)]
            cmds.append(contentsOf: buildWorkoutCommands(isHome: useHome, count: 2))
            return Response(
                message: "Привычка «\(suggestion.0)» добавлена. И тренировку впридачу — дисциплина начинается сейчас.",
                commands: cmds
            )
        }

        if lower.contains("план") || lower.contains("программ") || lower.contains("расписан") {
            let useHome = isHome ?? true
            let exercises = useHome ? homeExercises : gymExercises
            let picked = exercises.shuffled().prefix(5)
            let planText = picked.map { "- \($0.0): \($0.1) \($0.2)" }.joined(separator: "\n")
            var cmds: [AICommand] = [.buildPlan(plan: planText)]
            for ex in picked { cmds.append(.addTask(title: ex.0, amount: ex.1, unit: ex.2, icon: ex.3)) }
            return Response(
                message: "Вот план. Жёсткий. Выполняй каждый пункт. Без пропусков.",
                commands: cmds
            )
        }

        if lower.contains("сил") || lower.contains("мощ") || lower.contains("мышц") {
            let useHome = isHome ?? true
            let exercises = useHome ? homeExercises : gymExercises
            let strength = exercises.filter { $0.1 <= 25 }.shuffled().prefix(4)
            var commands: [AICommand] = []
            for ex in strength { commands.append(.addTask(title: ex.0, amount: ex.1, unit: ex.2, icon: ex.3)) }
            let list = strength.map { "\($0.0) \($0.1) \($0.2)" }.joined(separator: ", ")
            return Response(
                message: "Для силы — мало повторений, максимальное усилие. \(list). Не халтурь.",
                commands: commands
            )
        }

        if lower.contains("выносл") || lower.contains("кардио") || lower.contains("бег") {
            let endurance = homeExercises.filter { $0.1 >= 40 }.shuffled().prefix(4)
            var commands: [AICommand] = []
            for ex in endurance { commands.append(.addTask(title: ex.0, amount: ex.1, unit: ex.2, icon: ex.3)) }
            let list = endurance.map { "\($0.0) \($0.1) \($0.2)" }.joined(separator: ", ")
            return Response(
                message: "Выносливость — это не талант, это дисциплина. \(list). Всё делаешь или слабак?",
                commands: commands
            )
        }

        if lower.contains("похуд") || lower.contains("вес") || lower.contains("жиры") || lower.contains("фигур") {
            let cardio = homeExercises.filter { $0.1 >= 30 }.shuffled().prefix(4)
            var commands: [AICommand] = []
            for ex in cardio { commands.append(.addTask(title: ex.0, amount: ex.1, unit: ex.2, icon: ex.3)) }
            commands.append(.addHabit(title: "Фастфуд", icon: "takeoutbag.and.cup.and.straw.fill"))
            return Response(
                message: "Хочешь похудеть? Дисциплина + дефицит. Тренировка назначена. Привычка от фастфуда добавлена. Без компромиссов.",
                commands: commands
            )
        }

        if lower.contains("устал") || lower.contains("боль") || lower.contains("тяжело") || lower.contains("не могу") || lower.contains("лень") || lower.contains("не хоч") {
            let useHome = isHome ?? true
            var cmds = buildWorkoutCommands(isHome: useHome, count: 3)
            cmds.append(.addHabit(title: "Лень", icon: "couch"))
            return Response(
                message: "Жалуешься? Боль — признак роста. Лень — твой враг. Добавляю тренировку и привычку от лени. Выполняй.",
                commands: cmds
            )
        }

        if lower.contains("привет") || lower.contains("здравств") || lower.contains("хай") || lower.contains("хелло") {
            let useHome = isHome ?? true
            let cmds = buildWorkoutCommands(isHome: useHome, count: 3)
            return Response(
                message: "Привет. Раз пришёл — тренируйся. Назначаю упражнения. Выполняй всё. Без отговорок.",
                commands: cmds
            )
        }

        if lower.contains("прогресс") || lower.contains("как я") || lower.contains("результат") {
            if done < tasks.count {
                let remaining = tasks.count - done
                return Response(
                    message: "Выполнено \(done) из \(tasks.count). Ещё \(remaining) не сделано. Хватит спрашивать — делай! Добавляю ещё.",
                    commands: buildWorkoutCommands(isHome: isHome ?? true, count: 2)
                )
            } else if !tasks.isEmpty {
                return Response(
                    message: "Всё выполнено. Неплохо. Но расслабляться рано. Завтра будет сложнее. Готовься.",
                    commands: []
                )
            }
        }

        let useHome = isHome ?? true
        var cmds = buildWorkoutCommands(isHome: useHome, count: 3)
        let habit = habitSuggestions.randomElement()!
        cmds.append(.addHabit(title: habit.0, icon: habit.1))
        return Response(
            message: "Не понимаешь что делать? Я решу за тебя. Тренировка + привычка назначены. Выполняй. Не спорь.",
            commands: cmds
        )
    }

    private static func buildWorkoutCommands(isHome: Bool, count: Int) -> [AICommand] {
        let exercises = isHome ? homeExercises : gymExercises
        let picked = exercises.shuffled().prefix(count)
        return picked.map { .addTask(title: $0.0, amount: $0.1, unit: $0.2, icon: $0.3) }
    }
}
