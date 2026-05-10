<div align="center">
  <img width="128" height="128" src="/Resources/Icon.png" alt="Livable Icon">
  <h1><b>Livable</b></h1>
  <p>
    Make views livable.
  </p>
</div>

Livable is a SwiftUI package that turns a view's own pixels into a soft,
animated, liquid-like gradient surface. The effect is implemented with a
SwiftUI layer shader and Metal, so it can be applied directly to any SwiftUI
view without extracting colors or providing a separate palette.

<div align="center">
  <img width="256" src="/Resources/Example.gif" alt="Preview">
</div>

## Requirements

- iOS 17+

## Installation

Add Livable as a Swift Package dependency in Xcode, or add it to your
`Package.swift` dependencies:

```swift
.package(url: "https://github.com/whatsinlab/livable.git", from: "0.1.0")
```

Then add `Livable` to the target that uses the effect.

## Usage

Import Livable and apply the modifier to any SwiftUI view:

```swift
import Livable
import SwiftUI

struct ContentView: View {
    var body: some View {
        Image("Artwork")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .livable()
    }
}
```

You can control whether the effect renders, how quickly it moves, and how much
post-process blur is applied:

```swift
SomeView()
    .livable(isEnabled: true, speed: 0.8, blurRadius: 48)
```

The effect renders inside the modified view's layout bounds. To use it as a
full-screen backdrop, give the source view a full-screen frame at the call site.

## License

Livable is available under the MIT License.
