# SDUIEngine Project Structure

## Overview
SDUIEngine is a SwiftUI-based iOS application that implements a server-driven UI engine. It allows building user interfaces through JSON configuration files, enabling dynamic UI updates without requiring app code changes.

## Project Structure

### Root Directory
- `.git/` - Git version control directory
- `.gitignore` - Git ignore configuration
- `SDUIEngine/` - Main iOS project directory

### iOS Project Structure (`SDUIEngine/SDUIEngine/`)
- `ContentView.swift` - Main application view that loads and renders the initial screen
- `SDUIEngineApp.swift` - Application entry point
- `Resources/` - JSON configuration files defining UI screens
  - `main.json` - Main screen definition
  - `demo_screen.json` - Demo screen definition
- `Screens/` - Screen rendering components
  - `ScreenView.swift` - Individual screen view renderer
- `Network/` - Network services
  - `UIService.swift` - Service for loading UI configurations from backend
- `Engine/` - Core engine components

### Engine Components (`SDUIEngine/SDUIEngine/Engine/`)
- `Components/` - UI component implementations
  - `UIComponent.swift` - Protocol defining UI components
  - `ComponentRenderer.swift` - Generic renderer that converts ComponentModel to SwiftUI views
  - `ButtonComponent.swift` - Button component implementation
  - `TextComponent.swift` - Text component implementation
  - `ImageComponent.swift` - Image component implementation
  - `TextFieldComponent.swift` - Text field component implementation
  - `SpacerComponent.swift` - Spacer component implementation
  - `ComponentStyle.swift` - Component styling utilities
- `Core/` - Core data models and structures
  - `ComponentModel.swift` - Data model representing a UI component
  - `JSONValue.swift` - Enum for handling various JSON value types
  - `UIContext.swift` - Runtime context shared by all components
- `Events/` - Event handling mechanisms
  - `EventModel.swift` - Event model definition
- `Layout/` - Layout components
  - `VStackComponent.swift` - Vertical stack layout component
  - `HStackComponent.swift` - Horizontal stack layout component
  - `ScrollViewComponent.swift` - Scroll view component
- `Registry/` - Component registry for managing component types
  - `ComponentRegistry.swift` - Registry for registering and resolving components
- `State/` - State management
  - `NavigationEngine.swift` - Navigation state management

## Key Features

1. **Server-Driven UI**: UI is defined through JSON configuration files that can be updated without app releases
2. **Component-Based Architecture**: Reusable UI components that can be composed to build complex interfaces
3. **Event Handling**: Support for component events (tap, change, submit) that can trigger actions
4. **State Management**: In-memory state store for managing component properties
5. **Navigation**: Backend-driven navigation between screens
6. **Dynamic Actions**: Components can update other components through event chains

## How It Works

1. The app loads a JSON configuration file (like `main.json`) that defines the initial screen
2. The `ComponentRenderer` interprets the JSON and creates appropriate SwiftUI views
3. Components can define events (like `onTap`) that trigger actions
4. Actions can update component properties or navigate to other screens
5. The UI context provides state management, event handling, and navigation capabilities

## Sample JSON Structure

```json
{
  "id": "root_stack",
  "type": "VStack",
  "props": {
    "padding": 16,
    "spacing": 12
  },
  "events": {},
  "children": [
    {
      "id": "title_text",
      "type": "Text",
      "props": {
        "text": "Welcome to SDUIEngine",
        "fontSize": 24,
        "fontWeight": "bold"
      },
      "events": {},
      "children": []
    }
  ]
}
```
