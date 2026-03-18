# SDUIEngine Component Props Documentation

## 📋 Overview
This document provides comprehensive documentation for all available props in each SDUIEngine component. Each prop includes its type, default value, and description.

---

## 🎨 Text Component

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `text` | String | `""` | The text content to display. Supports state token interpolation with `{{key}}` syntax |
| `color` | String | `"#000000"` | Text color in hex format (e.g., "#FF5733") or system color name |
| `inputLike` | Boolean | `false` | Whether to render text with input-like styling (background, border, padding) |
| `borderColor` | String | `"#D1D5DB"` | Border color for input-like styling in hex format |
| `backgroundColor` | String | `"#F9FAFB"` | Background color for input-like styling in hex format |
| `cornerRadius` | Number | `8` | Corner radius for input-like styling in points |
| `inputPaddingVertical` | Number | `10` | Vertical padding for input-like styling in points |
| `inputPaddingHorizontal` | Number | `12` | Horizontal padding for input-like styling in points |

### Events
- `SET_TEXT` - Change text content
- `SET_COLOR` - Change text color

---

## 🔘 Button Component

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `title` | String | `"Button"` | Button text label. Falls back to `text` prop if not specified |
| `text` | String | `"Button"` | Alternative button text label (fallback for title) |
| `borderColor` | String | `nil` | Border color in hex format (e.g., "#007AFF") |
| `borderWidth` | Number | `1` | Border width in points |
| `cornerRadius` | Number | `10` | Corner radius in points |
| `backgroundColor` | String | `nil` | Background color in hex format |

### Events
- `onTap` - Triggered when button is tapped

---

## 📝 TextField Component

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `placeholder` | String | `""` | Placeholder text displayed when field is empty |
| `stateKey` | String | `component.id` | Key for storing field value in global state. Falls back to `bind` prop |
| `bind` | String | `component.id` | Alternative state key (fallback for stateKey) |
| `borderWidth` | Number | `0` | Border width in points |
| `borderColor` | String | `"gray"` | Border color in hex format or color name |
| `cornerRadius` | Number | `0` | Corner radius in points |
| `maxLength` | Number | `100` | Maximum number of characters allowed |
| `multilineTextAlignment` | String | `"leading"` | Text alignment: "leading", "center", "trailing", or "right" |

### Events
- `onChange` - Triggered when text changes
- `onSubmit` - Triggered when user submits (presses return)
- `SET_TEXT` - Programmatically set text value

---

## 📑 TabBar Component

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `selectedIndex` | Number | `0` | Index of the initially selected tab |

### Child Props (for each tab)

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `title` | String | `"Tab {index}"` | Tab title text |
| `systemImage` | String | `nil` | SF Symbols icon name (e.g., "house.fill") |
| `iconName` | String | `nil` | Custom icon name for Image component |

### Events
- `selectTab` - Programmatically select tab by index (params: `index`)

---

## 🖼️ Image Component

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `url` | String | `nil` | URL for remote image loading |
| `systemName` | String | `nil` | SF Symbols icon name |
| `name` | String | `nil` | Local image asset name |
| `resizable` | Boolean | `true` | Whether image can be resized |
| `contentMode` | String | `"fit"` | Content mode: "fit" or "fill" |

---

## 📏 Spacer Component

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| Uses Style props for sizing and spacing | | | See Style props below |

---

## 📊 DBGrid Component

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `dataSourceId` | String | `required` | ID of the registered DataSource to bind to |
| `rowMode` | String | `"template"` | Row rendering mode: "template" or "component" |
| `rowTemplate` | Object | `auto-generated` | Template specification for row rendering |
| `refreshable` | Boolean | `true` | Whether pull-to-refresh is enabled |
| `loadMoreEnabled` | Boolean | `true` | Whether load-more functionality is enabled |
| `filterPlaceholder` | String | `"Search..."` | Placeholder text for search field |
| `showFilter` | Boolean | `true` | Whether to show search/filter field |

### Row Template Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `title` | String | `"{{id}}"` | Template for row title with field interpolation |
| `subtitle` | String | `nil` | Template for row subtitle |
| `caption` | String | `nil` | Template for row caption |
| `badge` | String | `nil` | Template for row badge |

### Events
- `onRowTap` - Triggered when row is tapped
- `onRefresh` - Triggered on manual refresh
- `onLoadMore` - Triggered when loading more data

---

## 🔌 DataSource Component

### Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `id` | String | `component.id` | Unique identifier for the data source |
| `endpoint` | String | `required` | API endpoint URL for data fetching |
| `fetchPolicy` | String | `"NETWORK_FIRST_LOCAL_FALLBACK"` | Fetch policy (current default in runtime) |
| `pageSize` | Number | `25` | Number of items per page |
| `queryParam` | String | `"q"` | Query parameter name for search |
| `cursorParam` | String | `"offset"` | Cursor parameter name for pagination |
| `localFiltering` | Boolean | `true` | Enable client-side filtering |
| `remoteFiltering` | Boolean | `true` | Enable server-side filtering |
| `debounceMs` | Number | `450` | Debounce delay for search in milliseconds |
| `sorting` | Boolean | `false` | Enable sorting functionality |
| `defaultSortField` | String | `nil` | Default field for sorting |
| `defaultSortAscending` | Boolean | `true` | Default sort direction |
| `prefetchThreshold` | Number | `3` | Threshold (in rows to the end) for prefetching next page |
| `keyField` | String | `"id"` | Field to use as unique key for items |

---

## 🎨 Style Props (Common to all components)

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `width` | Number | `nil` | Fixed width in points |
| `height` | Number | `nil` | Fixed height in points |
| `padding` | Number | `0` | Padding in points |
| `margin` | Number | `0` | Margin in points |
| `color` | String | `nil` | Text/background color in hex format |
| `fontSize` | Number | `nil` | Font size in points |
| `fontWeight` | String | `nil` | Font weight: "regular", "bold", "semibold", etc. |
| `fontFamily` | String | `nil` | Font family name |
| `textAlign` | String | `nil` | Text alignment: "left", "center", "right" |

---

## 🔄 State Token Interpolation

Components that display text support state token interpolation using double curly braces:

```json
{
  "type": "Text",
  "props": {
    "text": "Hello {{userName}}, you have {{notificationCount}} messages"
  }
}
```

Tokens are replaced with values from the global state store.

---

## 📡 Event Handling

Components can define events in their JSON configuration:

```json
{
  "type": "Button",
  "props": {
    "title": "Click me"
  },
  "events": {
    "onTap": {
      "params": {
        "actions": [
          {
            "target": "navigation",
            "action": "push",
            "route": "next_screen"
          }
        ]
      }
    }
  }
}
```

---

## 🔧 Usage Examples

### Text Component
```json
{
  "type": "Text",
  "props": {
    "text": "Welcome {{userName}}!",
    "color": "#007AFF",
    "inputLike": true,
    "cornerRadius": 8
  }
}
```

### Button Component
```json
{
  "type": "Button",
  "props": {
    "title": "Submit",
    "backgroundColor": "#007AFF",
    "cornerRadius": 12
  },
  "events": {
    "onTap": {
      "params": {
        "actions": [{"target": "backend_data", "action": "SAVE_FORM"}]
      }
    }
  }
}
```

### DBGrid Component
```json
{
  "type": "DBGrid",
  "props": {
    "dataSourceId": "invoices",
    "rowTemplate": {
      "title": "{{doc_number}}",
      "subtitle": "{{customer_name}}",
      "caption": "{{doc_date}}"
    }
  }
}
```

---

## 📚 Additional Notes

- All color props support hex format (`#RRGGBB`) or system color names
- Number props are parsed as floating-point values
- Boolean props accept `true`, `false`, `1`, or `0`
- Missing props use their default values
- Component IDs must be unique within a screen
- State keys are used for data persistence and binding
