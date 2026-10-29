class Widget {
    let id: Int

    init(id: Int = 0) {
        self.id = id
    }

    func render() -> String {
        "widget \(id)"
    }
}

protocol WidgetDelegate: AnyObject {
    func widgetDidLoad(id: Int)
}

protocol WidgetModel: Widget {
    func refresh() -> Int
}

protocol WidgetScreen where Self: Widget {
    func title() -> String
}

protocol TitledWidgetScreen: WidgetScreen {
    func subtitle() -> String
}

class GenericInitBox {
    let label: String

    init<T>(value: T) {
        label = "\(value)"
    }

    func describe() -> String {
        label
    }
}

protocol GenericInitFactory {
    init<T>(value: T)
    func describe() -> String
}
