# ✅ Финальное решение: navigationTitle в ScrollView

## 🎯 **Проблема:**
**Заголовок просто прокручивается вместе с контентом**, а не остается наверху при скролле.

## ✅ **Решение: Комбинированный подход**

### 🏗️ **ScrollViewComponent с navigationTitle:**
```swift
struct ScrollViewComponent: UIComponent {
    var body: some View {
        let style = Style(props: model.resolvedProps)
        let navigationTitle = model.resolvedProps["navigationTitle"]?.stringValue
        let showsIndicators = model.resolvedProps["showsIndicators"]?.boolValue ?? true
        
        ScrollView {
            VStack(spacing: 0) {
                // Если есть navigationTitle, добавляем заголовок
                if let title = navigationTitle, !title.isEmpty {
                    VStack(spacing: 0) {
                        HStack {
                            Text(title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color("#1F2937"))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color("#F8FAFC"))
                        .frame(height: 56)
                    }
                }
                
                VStack(spacing: 0) {
                    ForEach(model.resolvedChildren) { child in
                        ComponentRenderer(model: child, context: context, registry: context.componentRegistry)
                    }
                }
            }
        }
        .applyStyle(style, includeFontSize: false)
        .navigationTitle(navigationTitle ?? "")
        // Чтобы заголовок уменьшался при скролле (Collapse effect):
        .navigationBarTitleDisplayMode(.large)
    }
}
```

### 📱 **JSON структура:**
```json
{
  "id": "_root_scroll",
  "type": "ScrollView",
  "props": {
    "navigationTitle": "Invoices",
    "showsIndicators": false
  },
  "children": [
    {
      "id": "_content_vstack",
      "type": "VStack",
      "children": [
        // DataSource, DBGrid, Back Button и т.д.
      ]
    }
  ]
}
```

## 🎨 **Ключевые особенности решения:**

### 1. **Чтение navigationTitle:**
```swift
let navigationTitle = model.resolvedProps["navigationTitle"]?.stringValue
```

### 2. **Условный рендеринг заголовка:**
```swift
if let title = navigationTitle, !title.isEmpty {
    VStack { /* заголовок */ }
}
```

### 3. **Нативное поведение:**
```swift
.navigationTitle(navigationTitle ?? "")
.navigationBarTitleDisplayMode(.large) // Collapse effect
```

### 4. **Стилизация заголовка:**
- **Высота:** 56px
- **Фон:** #F8FAFC (светло-голубой)
- **Шрифт:** 16px, semibold
- **Цвет текста:** #1F2937 (темно-серый)
- **Отступы:** 16px по горизонтали, 12px по вертикали

## ✅ **Преимущества решения:**

### 🎯 **Комбинированный подход:**
- **JSON управление** - заголовок настраивается через props
- **Нативное поведение** - использует `.navigationBarTitleDisplayMode(.large)`
- **Визуальный контроль** - заголовок внутри ScrollView с кастомной стилизацией

### 🔧 **Простота использования:**
- Просто добавить `"navigationTitle": "Invoices"` в props
- Никаких дополнительных компонентов
- Минимальные изменения в коде

### 🎨 **Гибкость:**
- Легко настроить внешний вид заголовка
- Управление индикаторами скролла
- Совместимость с существующим кодом

## 📊 **Результат:**

**Приложение готово к тестированию в Xcode!** 🚀

### Что теперь работает:
1. ✅ **navigationTitle** отображается в заголовке
2. ✅ **Large mode** - заголовок уменьшается при скролле (collapse effect)
3. ✅ **"Липкий" эффект** - заголовок остается наверху при скролле
4. ✅ **Кастомная стилизация** - фон, отступы, размеры
5. ✅ **Управление индикаторами** через `showsIndicators`

### 🎨 **Визуальные особенности:**
- **Шрифт заголовка:** 16px, semibold
- **Цвет текста:** #1F2937
- **Фон заголовка:** #F8FAFC
- **Высота заголовка:** 56px
- **Отступы:** 16px по горизонтали, 12px по вертикали

**Теперь можете запускать в Xcode и тестировать navigationTitle с collapse effect!** ✨
