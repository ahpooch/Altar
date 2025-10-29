# Line Statements и Line Comments в Altar

## Обзор

Altar поддерживает синтаксис line statements и line comments, совместимый с Jinja2. Это позволяет писать более компактные и читаемые шаблоны, используя специальные префиксы для операторов и комментариев вместо полных тегов `{% %}` и `{# #}`.

## Line Statements

### Что такое Line Statements?

Line statements позволяют использовать специальный префикс (например, `#`) в начале строки вместо блочных тегов `{% %}`. Это делает шаблоны более компактными и похожими на обычный код.

### Синтаксис

```altar
# for item in items
    <li>{{ item }}</li>
# endfor
```

Эквивалентно:

```altar
{% for item in items %}
    <li>{{ item }}</li>
{% endfor %}
```

### Настройка префикса

Префикс для line statements настраивается через параметр `LineStatementPrefix` функции `Invoke-AltarTemplate`:

```powershell
Invoke-AltarTemplate -Template $template -Context $context -LineStatementPrefix '#'
```

Или напрямую через статическое свойство:

```powershell
[Lexer]::LINE_STATEMENT_PREFIX = '#'
```

### Правила использования

1. **Префикс должен быть в начале строки** (после пробелов/табуляции)
2. **Поддерживаются все операторы**: `for`, `if`, `elif`, `else`, `endif`, `endfor`, и т.д.
3. **Опциональное двоеточие** в конце строки (как в Jinja2):
   ```altar
   # for item in items:
       {{ item }}
   # endfor
   ```
4. **Работает с отступами** - можно использовать вложенные конструкции:
   ```altar
   # for category in categories
       <h2>{{ category.name }}</h2>
       # for item in category.items
           <li>{{ item }}</li>
       # endfor
   # endfor
   ```

### Примеры

#### Базовый цикл

```altar
<ul>
# for product in products
    <li>{{ product.name }} - ${{ product.price }}</li>
# endfor
</ul>
```

#### Условные операторы

```altar
# if user_logged_in
    <p>Welcome, {{ username }}!</p>
# else
    <p>Please log in.</p>
# endif
```

#### Вложенные конструкции

```altar
# for category in categories
    <h2>{{ category.name }}</h2>
    <ul>
    # for item in category.items
        <li>{{ item }}</li>
    # endfor
    </ul>
# endfor
```

## Line Comments

### Что такое Line Comments?

Line comments позволяют добавлять комментарии в шаблон, используя специальный префикс (например, `##`). Комментарии полностью игнорируются при рендеринге.

### Синтаксис

```altar
## Это комментарий - будет проигнорирован
<h1>User Profile</h1>

## Следующая секция отображает информацию о пользователе
# if user
    <div class="profile">
        <h2>{{ user.name }}</h2>  ## Отображаем имя пользователя
    </div>
# endif
```

### Настройка префикса

Префикс для line comments настраивается через параметр `LineCommentPrefix`:

```powershell
Invoke-AltarTemplate -Template $template -Context $context `
    -LineStatementPrefix '#' -LineCommentPrefix '##'
```

Или напрямую:

```powershell
[Lexer]::LINE_COMMENT_PREFIX = '##'
```

### Типы комментариев

1. **Полные строки комментариев**:
   ```altar
   ## Это комментарий на всю строку
   ```

2. **Inline комментарии**:
   ```altar
   <li>{{ item }}</li>  ## Комментарий в конце строки
   ```

### Примеры

```altar
## Заголовок шаблона
<h1>Product List</h1>

## Цикл по продуктам
# for product in products
    <li>{{ product.name }}</li>  ## Отображаем название
# endfor

## Конец шаблона
```

## Пользовательские префиксы

Вы можете использовать любые префиксы, которые вам нравятся:

```powershell
# Использование % для операторов и // для комментариев
Invoke-AltarTemplate -Template $template -Context $context `
    -LineStatementPrefix '%' -LineCommentPrefix '//'
```

Пример шаблона:

```altar
// Список пользователей
% for user in users
    <div>{{ user.name }}</div>  // Имя пользователя
% endfor
```

## Совместимость с Jinja2

Функционал line statements и line comments полностью совместим с Jinja2:

- ✅ Префиксы настраиваются аналогично Jinja2
- ✅ Поддержка опционального двоеточия в конце line statements
- ✅ Line comments работают как в Jinja2 (полные строки и inline)
- ✅ Префикс должен быть в начале строки (после пробелов)
- ✅ Работает с вложенными конструкциями

## Важные замечания

1. **Префиксы сбрасываются после рендеринга** - это предотвращает побочные эффекты между разными вызовами
2. **Кэширование учитывает префиксы** - изменение префиксов инвалидирует кэш
3. **Line statements имеют приоритет над обычным текстом** - если строка начинается с префикса, она обрабатывается как оператор
4. **Trailing whitespace перед inline комментариями удаляется** - это обеспечивает чистый вывод

## Примеры использования

### Пример 1: Простой список

```powershell
$template = @"
<ul>
# for item in items
    <li>{{ item }}</li>
# endfor
</ul>
"@

$context = @{ items = @('Apple', 'Banana', 'Cherry') }

$result = Invoke-AltarTemplate -Template $template -Context $context `
    -LineStatementPrefix '#'
```

### Пример 2: С комментариями

```powershell
$template = @"
## Шаблон профиля пользователя
# if user
    <div class="profile">
        <h2>{{ user.name }}</h2>  ## Имя
        <p>{{ user.email }}</p>   ## Email
    </div>
# else
    <p>Пользователь не найден</p>
# endif
"@

$context = @{ user = @{ name = 'John'; email = 'john@example.com' } }

$result = Invoke-AltarTemplate -Template $template -Context $context `
    -LineStatementPrefix '#' -LineCommentPrefix '##'
```

### Пример 3: Вложенные циклы

```powershell
$template = @"
# for category in categories
    <h2>{{ category.name }}</h2>
    <ul>
    # for item in category.items
        <li>{{ item }}</li>
    # endfor
    </ul>
# endfor
"@

$context = @{
    categories = @(
        @{ name = 'Fruits'; items = @('Apple', 'Banana') },
        @{ name = 'Vegetables'; items = @('Carrot', 'Potato') }
    )
}

$result = Invoke-AltarTemplate -Template $template -Context $context `
    -LineStatementPrefix '#'
```

## Отключение функционала

Если вы не хотите использовать line statements и line comments, просто не устанавливайте префиксы. По умолчанию они отключены:

```powershell
# Обычный режим без line statements
$result = Invoke-AltarTemplate -Template $template -Context $context
