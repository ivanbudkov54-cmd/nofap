//
//  SOSExercise.swift
//  NoFap
//

import Foundation

struct SOSExercise: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let targetRepsOrTime: String
    let subtitle: String
    let instructions: [String]
    let whyItWorks: String
    let iconName: String
    let durationSeconds: Int?
}

enum SOSExerciseLibrary {
    static let all: [SOSExercise] = [
        SOSExercise(
            id: "ex_pushups",
            title: "Взрывные отжимания",
            targetRepsOrTime: "До отказа",
            subtitle: "Перенаправление кровотока в верхний плечевой пояс",
            instructions: [
                "Прими упор лёжа с идеальной прямой спиной.",
                "Выполняй отжимания в максимальном темпе без пауз.",
                "В последнем повторении замри в нижней точке на 5 секунд."
            ],
            whyItWorks: "Срочно перенаправляет кровь из тазовой зоны в грудь и плечи. Выброс молочной кислоты выбивает мозг из сексуального транса.",
            iconName: "figure.strengthtraining.traditional",
            durationSeconds: nil
        ),
        SOSExercise(
            id: "ex_wallsit",
            title: "«Стульчик» у стены",
            targetRepsOrTime: "60 секунд",
            subtitle: "Статическое жжение в квадрицепсах",
            instructions: [
                "Прижмись спиной к стене и опустись до угла 90° в коленях.",
                "Руки вытяни перед собой, не клади их на ноги.",
                "Держи позицию через жжение, пока таймер не завершится."
            ],
            whyItWorks: "Изометрическое напряжение крупнейших мышц ног заставляет префронтальную кору фокусироваться на удержании позы, гася компульсивный импульс.",
            iconName: "figure.seated.side",
            durationSeconds: 60
        ),
        SOSExercise(
            id: "ex_burpees",
            title: "Бёрпи на скорость",
            targetRepsOrTime: "20 повторений",
            subtitle: "Резкий разгон пульса до анаэробной зоны",
            instructions: [
                "Упор присев -> прыжком в упор лёжа -> коснись пола грудью.",
                "Взрывным движением вернись в присед и выпрыгни вверх с хлопком.",
                "Делай без пауз на отдых."
            ],
            whyItWorks: "Поднимает пульс до 140+ уд/мин. Активирует режим «бей или беги», в котором размножение биологически блокируется организмом.",
            iconName: "figure.run",
            durationSeconds: nil
        ),
        SOSExercise(
            id: "ex_plank_knees",
            title: "Планка с коленями к локтям",
            targetRepsOrTime: "60 секунд",
            subtitle: "Жесткая фиксация мышечного корсета",
            instructions: [
                "Встань в планку на предплечьях, напряги пресс и ягодицы.",
                "Поочередно медленно подтягивай колено к локтю с фиксацией на 2 секунды.",
                "Не задирай и не проваливай таз."
            ],
            whyItWorks: "Разгружает пояснично-крестцовый отдел и включает глубокие стабилизаторы кора, убирая физический застой.",
            iconName: "figure.core.training",
            durationSeconds: 60
        ),
        SOSExercise(
            id: "ex_jump_squats",
            title: "Приседания с выпрыгиванием",
            targetRepsOrTime: "25 повторений",
            subtitle: "Взрывная нагрузка на нижний этаж тела",
            instructions: [
                "Опустись в глубокий присед ниже параллели.",
                "Резко и мощно выпрыгни максимально высоко.",
                "Приземляйся мягко на носки и сразу уходи в следующий присед."
            ],
            whyItWorks: "Мощная циклическая нагрузка утилизирует избыточный кортизол и адреналин, заменяя навязчивую мысль мышечной усталостью.",
            iconName: "figure.cross.training",
            durationSeconds: nil
        )
    ]
}
