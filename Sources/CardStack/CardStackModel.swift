import Combine
import Foundation
import SwiftUI
import CoreGraphics

public class CardStackData<Element: Identifiable, Direction: Equatable>: Identifiable {
    
    public var id: Element.ID {
        return element.id
    }
    let element: Element
    var direction: Direction?
    
    init(_ element: Element, direction: Direction? = nil) {
        self.element = element
        self.direction = direction
    }
    
}

public class CardStackModel<Element: Identifiable, Direction: Equatable>: ObservableObject {
    
    @Published private(set) public var numberOfElements: Int
    @Published private(set) public var numberOfElementsRemaining: Int

    @Published private(set) var data: [CardStackData<Element, Direction>]
    @Published private(set) var currentIndex: Int?
    
    private var subscriptions: Set<AnyCancellable> = []
        
    /// Sets up internal Combine bindings for element count tracking.
    private func setupSubscriptions() {
        $data
            .sink { [weak self] data in
                guard let self = self else { return }
                self.numberOfElements = data.count
            }
            .store(in: &subscriptions)

        $numberOfElements.combineLatest($currentIndex)
            .sink { [weak self] number, index in
                guard let self = self else { return }
                if let index = index {
                    self.numberOfElementsRemaining = number - index
                } else {
                    self.numberOfElementsRemaining = 0
                }
            }
            .store(in: &subscriptions)
    }
    
    /// Initialize with a static array of elements.
    public init(_ elements: [Element]) {
        data = elements.map { CardStackData($0) }
        currentIndex = elements.count > 0 ? 0 : nil
        numberOfElements = elements.count
        numberOfElementsRemaining = elements.count
        
        setupSubscriptions()
    }
    
    /// Initialize by binding to a Combine publisher of element arrays.
    public init<P: Publisher>(_ publisher: P) where P.Output == [Element], P.Failure == Never {
        data = []
        currentIndex = nil
        numberOfElements = 0
        numberOfElementsRemaining = 0
        
        setupSubscriptions()
        
        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] elements in
                guard let self = self else { return }
                // If upstream publishes an empty array, clear the stack (e.g., on filter change/reset)
                if elements.isEmpty {
                    self.removeAllElements()
                    return
                }
                // If first load or incoming is a full replacement (e.g., filters applied), replace data
                if self.data.isEmpty || elements.count < self.data.count {
                    self.setElements(elements)
                    return
                }
                // Otherwise, append only new elements; do not reset index or existing data
                let existingIDs = Set(self.data.map { $0.id })
                let newItems = elements.filter { !existingIDs.contains($0.id) }
                if !newItems.isEmpty {
                    self.appendElements(newItems)
                }
            }
            .store(in: &subscriptions)
    }
    
    public func setElements(_ elements: [Element]) {
        data = elements.map { CardStackData($0) }
        currentIndex = elements.count > 0 ? 0 : nil
    }
    
    public func appendElement(_ element: Element) {
        data.append(CardStackData(element))
        if currentIndex == nil { currentIndex = 0 }
    }
    
    public func appendElements(_ elements: [Element]) {
        data.append(contentsOf: elements.map { CardStackData($0) })
        if currentIndex == nil { currentIndex = 0 }
    }
    
    public func removeAllElements() {
        data.removeAll()
        currentIndex = nil
    }
    
    /// Deprecated: use the publisher init instead.
    @available(*, deprecated, message: "Use init(_ publisher:) instead")
    public func bind<P: Publisher>(to publisher: P) where P.Output == [Element], P.Failure == Never {
        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] elements in
                guard let self = self else { return }
                let oldIndex = self.currentIndex
                self.data = elements.map { CardStackData($0) }
                if let idx = oldIndex, idx < self.data.count {
                    self.currentIndex = idx
                } else {
                    self.currentIndex = self.data.isEmpty ? nil : 0
                }
            }
            .store(in: &subscriptions)
    }
    
    public func swipe(direction: Direction, completion: ((Element, Direction) -> Void)?) {
        guard let currentIndex = currentIndex else {
            return
        }
        
        let element = data[currentIndex].element
        data[currentIndex].direction = direction

        let nextIndex = currentIndex + 1
        if nextIndex < data.count {
            self.currentIndex = nextIndex
        } else {
            self.currentIndex = nil
        }
        
        completion?(element, direction)
    }
    
    public func unswipe() {
        
        var currentIndex: Int! = self.currentIndex
        if currentIndex == nil {
            currentIndex = data.count
        }
        
        let previousIndex = currentIndex - 1
        if previousIndex >= 0 {
            data[previousIndex].direction = nil
            self.currentIndex = previousIndex
        }
    }
    
    internal func indexInStack(_ dataPiece: CardStackData<Element, Direction>) -> Int? {
        guard let index = data.firstIndex(where: { $0.id == dataPiece.id }) else { return nil }
        return index - (currentIndex ?? data.count)
    }
}
