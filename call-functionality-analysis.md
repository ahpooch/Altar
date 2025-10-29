# Анализ функционала Call в Altar

## Дата анализа
24 октября 2025 г.

## Резюме
Функционал **Call** из Jinja2 **частично реализован** в Altar, но имеет критические проблемы, которые делают его **нерабочим** в текущем состоянии.

## Что такое Call в Jinja2?

Call block в Jinja2 - это специальная конструкция, которая позволяет передавать блок контента в макрос через специальную переменную `caller()`. Это делает макросы более гибкими и мощными.

### Основные возможности Call:

1. **Базовое использование**: Передача блока контента в макрос
```jinja2
{% macro render_dialog(title) -%}
    <div>
        <h2>{{ title }}</h2>
        <div class="contents">
            {{ caller() }}
        </div>
    </div>
{%- endmacro %}

{% call render_dialog('Hello World') %}
    This is the content passed to the macro.
{% endcall %}
```

2. **Call с параметрами**: Макрос может передавать данные обратно в caller
```jinja2
{% macro dump_users(users) -%}
    <ul>
    {%- for user in users %}
        <li>{{ caller(user) }}</li>
    {%- endfor %}
    </ul>
{%- endmacro %}

{% call(user) dump_users(list_of_users) %}
    <p>{{ user.username }}</p>
{% endcall %}
```

## Текущее состояние в Altar

### ✅ Что реализовано:

1. **AST узлы**:
   - `CallNode` - класс для представления call блока в AST
   - Содержит `MacroCall` и `Body` (контент блока)

2. **Парсинг**:
   - `ParseCall()` метод существует
   - Распознает синтаксис `{% call macroname() %} ... {% endcall %}`
   - Парсит тело call блока

3. **Компиляция**:
   - `VisitCall()` метод существует
   - Генерирует PowerShell код для call блока
   - Создает функцию `__CALLER__` с контентом блока

4. **Лексер**:
   - Ключевые слова `call` и `endcall` добавлены в список keywords

### ❌ Что НЕ работает:

1. **Критическая проблема #1: caller() не определен**
   ```
   Error: The term '__MACRO_caller__' is not recognized
   ```
   - Компилятор создает функцию `__CALLER__`, но макрос пытается вызвать `__MACRO_caller__`
   - Несоответствие имен функций

2. **Критическая проблема #2: Call с параметрами не парсится**
   ```
   Error: Unexpected token PUNCTUATION. Expected: IDENTIFIER.
   ```
   - Синтаксис `{% call(user) macroname() %}` не поддерживается
   - Парсер не ожидает параметры в скобках после `call`

3. **Проблема #3: Передача параметров в caller()**
   - Даже если базовый `caller()` заработает, передача параметров типа `caller(user)` не реализована

## Детальный анализ кода

### Парсер (ParseCall)
```powershell
[CallNode]ParseCall([Token]$startToken) {
    # Parse the macro call expression
    $macroCall = $this.ParseMacroCallExpression()
    
    # Expect closing %}
    $this.Expect([TokenType]::BLOCK_END)
    
    # Create call node
    $callNode = [CallNode]::new($macroCall, $startToken.Line, $startToken.Column, $startToken.Filename)
    
    # Parse call body until {% endcall %}
    # ...
}
```

**Проблема**: Не обрабатывает параметры типа `{% call(user) ... %}`

### Компилятор (VisitCall)
```powershell
[void]VisitCall([CallNode]$node) {
    # Generate code for call block with caller() support
    $macroCall = $node.MacroCall
    
    # First, compile the caller block into a function
    $this.AppendLine("# Call block with caller()")
    $this.AppendLine("function __CALLER__ {")
    # ...
    
    # Now call the macro with the caller function available
    $this.AppendLine("`$caller = Get-Item function:__CALLER__")
    # ...
}
```

**Проблемы**:
1. Создается `__CALLER__`, но макрос ищет `__MACRO_caller__`
2. Не передаются параметры в caller функцию
3. `$caller` устанавливается как переменная, но макрос вызывает её как функцию

## Требуется ли функционал Call в Altar?

### ✅ Аргументы ЗА:

1. **Совместимость с Jinja2**: Call - это стандартная функция Jinja2
2. **Гибкость макросов**: Позволяет создавать более мощные и переиспользуемые компоненты
3. **Альтернатива циклам**: Call с параметрами может заменять некоторые сложные циклы
4. **Уже частично реализовано**: Базовая структура существует, нужны только исправления

### ❌ Аргументы ПРОТИВ:

1. **Сложность**: Добавляет дополнительную сложность в шаблоны
2. **Альтернативы**: Многие задачи можно решить через обычные макросы и циклы
3. **Редкое использование**: В практике Jinja2 call используется нечасто

### 📊 Вывод: **ДА, функционал нужен**

Причины:
- Уже частично реализован (50% работы сделано)
- Важен для полной совместимости с Jinja2
- Позволяет создавать более элегантные решения для сложных задач
- Исправление требует относительно небольших изменений

## Рекомендации по исправлению

### Приоритет 1: Исправить базовый caller()

1. **Проблема**: Несоответствие имен `__CALLER__` vs `__MACRO_caller__`
   
   **Решение**: В `VisitCall()` изменить:
   ```powershell
   # Вместо:
   $this.AppendLine("function __CALLER__ {")
   
   # Использовать:
   $this.AppendLine("function __MACRO_caller__ {")
   ```

2. **Проблема**: `$caller` как переменная вместо функции
   
   **Решение**: Убрать строку `$caller = Get-Item function:__CALLER__` и просто определить функцию

### Приоритет 2: Добавить поддержку параметров в call

1. **В парсере**: Добавить парсинг параметров после `call`
   ```powershell
   [CallNode]ParseCall([Token]$startToken) {
       # Check for parameters: {% call(param1, param2) ... %}
       $parameters = @()
       if ($this.MatchTypeValue([TokenType]::PUNCTUATION, "(")) {
           $this.Consume()  # (
           # Parse parameter names
           while (-not $this.MatchTypeValue([TokenType]::PUNCTUATION, ")")) {
               $param = $this.Expect([TokenType]::IDENTIFIER).Value
               $parameters += $param
               if ($this.MatchTypeValue([TokenType]::PUNCTUATION, ",")) {
                   $this.Consume()
               }
           }
           $this.Consume()  # )
       }
       # ...
   }
   ```

2. **В CallNode**: Добавить свойство для параметров
   ```powershell
   class CallNode : StatementNode {
       [MacroCallNode]$MacroCall
       [StatementNode[]]$Body
       [string[]]$Parameters  # NEW
   }
   ```

3. **В компиляторе**: Передавать параметры в caller функцию
   ```powershell
   # Generate caller function with parameters
   if ($node.Parameters.Count -gt 0) {
       $paramList = $node.Parameters -join ', $'
       $this.AppendLine("function __MACRO_caller__ {")
       $this.AppendLine("    param(`$$paramList)")
   } else {
       $this.AppendLine("function __MACRO_caller__ {")
   }
   ```

### Приоритет 3: Добавить тесты

Создать файл `Tests/Integration/Call.Tests.ps1` с тестами:
1. Базовый call без параметров
2. Call с одним параметром
3. Call с несколькими параметрами
4. Call с вложенными макросами
5. Call с условиями внутри

### Приоритет 4: Добавить примеры

Создать `Examples/Call Block/` с примерами:
1. `example-call-simple.alt` - базовый пример
2. `example-call-with-params.alt` - с параметрами
3. `example-call-dialog.alt` - практический пример (диалоги)
4. `example-call-list.alt` - практический пример (списки)

## Оценка трудозатрат

- **Исправление базового caller()**: 1-2 часа
- **Добавление поддержки параметров**: 3-4 часа
- **Написание тестов**: 2-3 часа
- **Создание примеров и документации**: 1-2 часа

**Итого**: 7-11 часов работы

## Заключение

Функционал Call в Altar:
- ✅ **Реализован на 50%** (структура есть, но не работает)
- ❌ **Имеет критические баги** (caller() не определен, параметры не поддерживаются)
- ✅ **Необходим для полной совместимости с Jinja2**
- ✅ **Может быть исправлен относительно быстро** (7-11 часов)

**Рекомендация**: Исправить и довести до рабочего состояния, так как:
1. Базовая работа уже проделана
2. Функционал важен для совместимости с Jinja2
3. Исправление не требует больших затрат времени
4. Добавляет значительную гибкость в работе с макросами
