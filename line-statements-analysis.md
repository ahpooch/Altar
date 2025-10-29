# Анализ возможности реализации Line Statements и Line Comments в Altar

## Обзор функционала Jinja2

### Line Statements
Jinja2 позволяет использовать специальный префикс (например, `#`) для обозначения строк как statements:

```jinja2
# for item in seq:
    <li>{{ item }}</li>
# endfor
```

Эквивалентно:
```jinja2
{% for item in seq %}
    <li>{{ item }}</li>
{% endfor %}
```

**Особенности:**
1. Префикс может быть в любом месте строки, если перед ним нет текста
2. Statements могут заканчиваться двоеточием `:` для читаемости
3. Поддержка многострочных statements при открытых скобках

### Line Comments
Позволяет использовать префикс (например, `##`) для комментариев:

```jinja2
# for item in seq:
    <li>{{ item }}</li>     ## this comment is ignored
# endfor
```

## Возможность реализации в Altar

### ✅ МОЖНО РЕАЛИЗОВАТЬ

Да, этот функционал можно реализовать в Altar. Вот почему:

#### 1. Архитектурная совместимость
- Altar использует трёхэтапную обработку: Lexer → Parser → Compiler
- Line statements и line comments обрабатываются на этапе **Lexer**
- Текущая архитектура Lexer уже поддерживает состояния и может быть расширена

#### 2. Существующие аналоги в Altar
Altar уже имеет похожие механизмы:
- Whitespace trimming (`{%-` и `-%}`)
- Различные типы токенов (TEXT, BLOCK_START, COMMENT_START)
- Обработка многострочных конструкций (raw blocks)

#### 3. Точки интеграции

**В классе Lexer:**
```powershell
class Lexer {
    static [string]$LINE_STATEMENT_PREFIX = $null  # Например: '#'
    static [string]$LINE_COMMENT_PREFIX = $null    # Например: '##'
    
    # Новый метод для обработки line statements
    [void]TokenizeLineStatement([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens)
    
    # Новый метод для обработки line comments
    [void]TokenizeLineComment([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens)
}
```

**В методе TokenizeInitial:**
- Проверка начала строки на наличие line_statement_prefix
- Проверка на наличие line_comment_prefix
- Преобразование line statement в обычные BLOCK_START/BLOCK_END токены

## Детальный план реализации

### Этап 1: Расширение Lexer

#### 1.1 Добавление статических свойств
```powershell
class Lexer {
    static [string]$LINE_STATEMENT_PREFIX = $null
    static [string]$LINE_COMMENT_PREFIX = $null
}
```

#### 1.2 Модификация TokenizeInitial
Добавить проверку в начале метода:
```powershell
[void]TokenizeInitial([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
    # Проверка на line comment
    if (![string]::IsNullOrEmpty([Lexer]::LINE_COMMENT_PREFIX)) {
        if ($this.CheckLineComment($state)) {
            $this.TokenizeLineComment($state, $tokens)
            return
        }
    }
    
    # Проверка на line statement
    if (![string]::IsNullOrEmpty([Lexer]::LINE_STATEMENT_PREFIX)) {
        if ($this.CheckLineStatement($state)) {
            $this.TokenizeLineStatement($state, $tokens)
            return
        }
    }
    
    # Существующая логика...
}
```

#### 1.3 Новые вспомогательные методы

**CheckLineStatement:**
```powershell
[bool]CheckLineStatement([LexerState]$state) {
    # Проверяем, что мы в начале строки или после whitespace
    if ($state.Column -eq 1 -or $this.IsAtLineStart($state)) {
        # Проверяем наличие префикса
        $prefix = [Lexer]::LINE_STATEMENT_PREFIX
        $prefixLen = $prefix.Length
        
        for ($i = 0; $i -lt $prefixLen; $i++) {
            if ($state.PeekOffset($i) -ne $prefix[$i]) {
                return $false
            }
        }
        
        return $true
    }
    
    return $false
}
```

**TokenizeLineStatement:**
```powershell
[void]TokenizeLineStatement([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
    $state.CaptureStart()
    
    # Пропускаем префикс
    $prefix = [Lexer]::LINE_STATEMENT_PREFIX
    for ($i = 0; $i -lt $prefix.Length; $i++) {
        $state.Consume()
    }
    
    # Пропускаем whitespace после префикса
    $this.SkipWhitespace($state)
    
    # Добавляем BLOCK_START токен
    $tokens.Add([Token]::new([TokenType]::BLOCK_START, '{%', $state.StartLine, $state.StartColumn, $state.Filename))
    
    # Переключаемся в состояние BLOCK
    $state.States.Push("BLOCK")
    
    # Собираем содержимое до конца строки
    $lineContent = ""
    $hasOpenBrackets = $false
    
    while (-not $state.IsEOF()) {
        $char = $state.Peek()
        
        # Проверяем открытые скобки для многострочных statements
        if ($char -in @('(', '[', '{')) {
            $hasOpenBrackets = $true
        }
        elseif ($char -in @(')', ']', '}')) {
            # Проверяем, закрыты ли все скобки
            # (требуется более сложная логика подсчёта)
        }
        
        # Проверяем конец строки
        if ($char -eq "`n" -and -not $hasOpenBrackets) {
            # Удаляем опциональное двоеточие в конце
            if ($lineContent.TrimEnd().EndsWith(':')) {
                $lineContent = $lineContent.TrimEnd().TrimEnd(':')
            }
            
            break
        }
        
        $lineContent += $char
        $state.Consume()
    }
    
    # Токенизируем содержимое как обычное выражение
    # (создаём временный lexer для обработки содержимого)
    $tempLexer = [Lexer]::new()
    $tempState = [LexerState]::new($lineContent, $state.Filename)
    
    while (-not $tempState.IsEOF()) {
        $tempLexer.TokenizeExpression($tempState, $tokens, "BLOCK")
    }
    
    # Добавляем BLOCK_END токен
    $tokens.Add([Token]::new([TokenType]::BLOCK_END, '%}', $state.Line, $state.Column, $state.Filename))
    
    # Возвращаемся в состояние INITIAL
    $state.States.Pop()
}
```

**CheckLineComment:**
```powershell
[bool]CheckLineComment([LexerState]$state) {
    $prefix = [Lexer]::LINE_COMMENT_PREFIX
    $prefixLen = $prefix.Length
    
    for ($i = 0; $i -lt $prefixLen; $i++) {
        if ($state.PeekOffset($i) -ne $prefix[$i]) {
            return $false
        }
    }
    
    return $true
}
```

**TokenizeLineComment:**
```powershell
[void]TokenizeLineComment([LexerState]$state, [System.Collections.Generic.List[Token]]$tokens) {
    # Пропускаем префикс
    $prefix = [Lexer]::LINE_COMMENT_PREFIX
    for ($i = 0; $i -lt $prefix.Length; $i++) {
        $state.Consume()
    }
    
    # Пропускаем всё до конца строки
    while (-not $state.IsEOF() -and $state.Peek() -ne "`n") {
        $state.Consume()
    }
    
    # Пропускаем символ новой строки
    if (-not $state.IsEOF() -and $state.Peek() -eq "`n") {
        $state.Consume()
    }
    
    # Не добавляем никаких токенов - комментарий игнорируется
}
```

### Этап 2: API для настройки

#### 2.1 Добавление в TemplateEngine
```powershell
class TemplateEngine {
    [string]$LineStatementPrefix
    [string]$LineCommentPrefix
    
    TemplateEngine() {
        $this.TemplateDir = ""
        $this.LineStatementPrefix = $null
        $this.LineCommentPrefix = $null
    }
    
    [string]Render([string]$template, [hashtable]$context) {
        # Устанавливаем префиксы в Lexer перед токенизацией
        [Lexer]::LINE_STATEMENT_PREFIX = $this.LineStatementPrefix
        [Lexer]::LINE_COMMENT_PREFIX = $this.LineCommentPrefix
        
        # Существующая логика...
    }
}
```

#### 2.2 Обновление Invoke-AltarTemplate
```powershell
function Invoke-AltarTemplate {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Path', Position = 0)]
        [string]$Path,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'Template', Position = 0)]
        [string]$Template,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [hashtable]$Context,
        
        [Parameter(Mandatory = $false)]
        [string]$LineStatementPrefix,
        
        [Parameter(Mandatory = $false)]
        [string]$LineCommentPrefix
    )
    
    $engine = [TemplateEngine]::new()
    
    if ($LineStatementPrefix) {
        $engine.LineStatementPrefix = $LineStatementPrefix
    }
    
    if ($LineCommentPrefix) {
        $engine.LineCommentPrefix = $LineCommentPrefix
    }
    
    # Существующая логика...
}
```

### Этап 3: Тестирование

#### 3.1 Тесты для Line Statements
```powershell
# Tests/Integration/LineStatements.Tests.ps1

Describe "Line Statements" {
    BeforeAll {
        . "$PSScriptRoot/../../Altar.ps1"
    }
    
    It "Should process basic line statement" {
        $template = @"
<ul>
# for item in items
    <li>{{ item }}</li>
# endfor
</ul>
"@
        
        $context = @{
            items = @('Apple', 'Banana', 'Cherry')
        }
        
        $engine = [TemplateEngine]::new()
        $engine.LineStatementPrefix = '#'
        $result = $engine.Render($template, $context)
        
        $result | Should -Match '<li>Apple</li>'
        $result | Should -Match '<li>Banana</li>'
        $result | Should -Match '<li>Cherry</li>'
    }
    
    It "Should support colon at end of line statement" {
        $template = @"
# for item in items:
    {{ item }}
# endfor
"@
        
        $context = @{ items = @(1, 2, 3) }
        
        $engine = [TemplateEngine]::new()
        $engine.LineStatementPrefix = '#'
        $result = $engine.Render($template, $context)
        
        $result | Should -Match '1'
        $result | Should -Match '2'
        $result | Should -Match '3'
    }
    
    It "Should support multiline line statements" {
        $template = @"
# for href, caption in [('index.html', 'Index'),
                        ('about.html', 'About')]:
    <a href="{{ href }}">{{ caption }}</a>
# endfor
"@
        
        $context = @{}
        
        $engine = [TemplateEngine]::new()
        $engine.LineStatementPrefix = '#'
        $result = $engine.Render($template, $context)
        
        $result | Should -Match 'index.html.*Index'
        $result | Should -Match 'about.html.*About'
    }
}
```

#### 3.2 Тесты для Line Comments
```powershell
Describe "Line Comments" {
    It "Should ignore line comments" {
        $template = @"
# for item in items:
    <li>{{ item }}</li>     ## this is a comment
# endfor
"@
        
        $context = @{ items = @('Test') }
        
        $engine = [TemplateEngine]::new()
        $engine.LineStatementPrefix = '#'
        $engine.LineCommentPrefix = '##'
        $result = $engine.Render($template, $context)
        
        $result | Should -Not -Match 'this is a comment'
        $result | Should -Match '<li>Test</li>'
    }
}
```

## Сложности и ограничения

### 1. Многострочные statements
**Проблема:** Требуется отслеживание открытых/закрытых скобок
**Решение:** Реализовать счётчик скобок в TokenizeLineStatement

### 2. Префикс в середине строки
**Проблема:** Jinja2 позволяет префикс в любом месте, если перед ним нет текста
**Решение:** Проверять, что перед префиксом только whitespace

### 3. Взаимодействие с существующими токенами
**Проблема:** Line statements должны корректно работать с `{{`, `{%`, `{#`
**Решение:** Проверять line statement prefix в начале TokenizeInitial, до проверки других токенов

### 4. Производительность
**Проблема:** Дополнительные проверки на каждой строке
**Решение:** Проверки выполняются только если префиксы установлены (не null)

## Примеры использования

### Пример 1: Базовое использование
```powershell
$template = @"
<ul>
# for item in items
    <li>{{ item }}</li>
# endfor
</ul>
"@

$engine = [TemplateEngine]::new()
$engine.LineStatementPrefix = '#'

$result = $engine.Render($template, @{ items = @(1, 2, 3) })
```

### Пример 2: С комментариями
```powershell
$template = @"
## This is a header comment
# for item in items:  ## Loop through items
    <li>{{ item }}</li>
# endfor
"@

$engine = [TemplateEngine]::new()
$engine.LineStatementPrefix = '#'
$engine.LineCommentPrefix = '##'

$result = $engine.Render($template, @{ items = @('A', 'B') })
```

### Пример 3: Через Invoke-AltarTemplate
```powershell
Invoke-AltarTemplate -Template $template -Context @{ items = @(1, 2, 3) } `
    -LineStatementPrefix '#' -LineCommentPrefix '##'
```

## Рекомендации по реализации

### Приоритет 1 (Обязательно)
1. ✅ Базовая поддержка line statements с простым префиксом
2. ✅ Базовая поддержка line comments
3. ✅ Поддержка опционального двоеточия в конце statement

### Приоритет 2 (Желательно)
4. ⚠️ Поддержка многострочных statements (со скобками)
5. ⚠️ Префикс в любом месте строки (после whitespace)

### Приоритет 3 (Опционально)
6. ⭕ Настройка через конфигурационный файл
7. ⭕ Автоопределение префиксов из шаблона

## Заключение

**Вердикт: ДА, можно реализовать**

Функционал line statements и line comments из Jinja2 полностью совместим с архитектурой Altar и может быть реализован с минимальными изменениями в классе Lexer.

**Преимущества реализации:**
- ✅ Совместимость с Jinja2 шаблонами
- ✅ Улучшенная читаемость для некоторых типов шаблонов
- ✅ Гибкость в выборе синтаксиса

**Оценка трудозатрат:**
- Базовая реализация: ~4-6 часов
- Полная реализация с тестами: ~8-12 часов
- Документация и примеры: ~2-4 часа

**Итого:** ~14-22 часа для полной реализации
