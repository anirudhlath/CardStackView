import Combine
import SwiftUI

struct CardView<Direction: CardSwipeDirection, Content: View>: View {

  @Environment(\.cardStackConfiguration) private var configuration: CardStackConfiguration

  @State private var translation: CGSize = .zero
  @State private var draggingState: CardDraggingState = .idle

  @GestureState private var isDragging: Bool = false

  private enum CardDraggingState {
    case dragging
    case ended
    case idle
  }

  private let isOnTop: Bool
  private let offset: CGSize
  private let onChange: (Direction?) -> Void
  private let onSwipe: (Direction, CGSize) -> Void
  private let content: (Direction?) -> Content

  init(
    isOnTop: Bool,
    offset: CGSize,
    onChange: @escaping (Direction?) -> Void,
    onSwipe: @escaping (Direction, CGSize) -> Void,
    @ViewBuilder content: @escaping (Direction?) -> Content
  ) {
    self.isOnTop = isOnTop
    self.offset = offset
    self.onChange = onChange
    self.onSwipe = onSwipe
    self.content = content
  }

  @ViewBuilder var cardView: some View {
    GeometryReader { geometry in
      content(ongoingSwipeDirection(geometry))
        .disabled(self.translation != .zero)
        .offset(combinedOffsets)
        .rotationEffect(rotation(geometry))
        .simultaneousGesture(isOnTop ? dragGesture(geometry) : nil)
        .animation(
          draggingState == .dragging ? .easeInOut(duration: 0.05) : self.configuration.animation,
          value: translation)
    }
  }

  private func cancelDragging() {
    draggingState = .idle
    translation = .zero
  }

  var body: some View {
    if #available(iOS 14.0, *) {
      cardView
        .onChange(of: isDragging) { newValue in
          if !newValue && draggingState == .dragging {
            cancelDragging()
          }
        }
    } else {  // iOS 13.0, *
      cardView
        .onReceive(Just(isDragging)) { newValue in
          if !newValue && draggingState == .dragging {
            cancelDragging()
          }
        }
    }
  }

  private var combinedOffsets: CGSize {
    .init(width: offset.width + translation.width, height: offset.height + translation.height)
  }

  private func dragGesture(_ geometry: GeometryProxy) -> some Gesture {
    DragGesture()
      .updating($isDragging) { value, state, transaction in
        state = true
      }
      .onChanged { value in
        self.draggingState = .dragging
        self.translation = value.translation
        if let ongoingDirection = ongoingSwipeDirection(geometry) {
          onChange(ongoingDirection)
        } else {
          onChange(nil)
        }
      }
      .onEnded { value in
        self.draggingState = .ended
        if let direction = ongoingSwipeDirection(geometry) {
          withAnimation(configuration.animation) {
            translation = .zero
            onSwipe(direction, translation)
          }
        } else {
          cancelDragging()
        }
      }
  }

  private var translationRadians: Angle {
    .radians(atan2(-translation.height, translation.width))
  }

  private func rotation(_ geometry: GeometryProxy) -> Angle {
    .degrees(Double(combinedOffsets.width / geometry.size.width) * 15)
  }

  private func ongoingSwipeDirection(_ geometry: GeometryProxy) -> Direction? {
    guard let direction = Direction.from(angle: translationRadians) else { return nil }
    let threshold = min(geometry.size.width, geometry.size.height) * configuration.swipeThreshold
    let distance = hypot(combinedOffsets.width, combinedOffsets.height)
    return distance > threshold ? direction : nil
  }

}
