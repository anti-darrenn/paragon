# The lesson format

Every article in a Paragon lesson is written in this format. The content studio's toolbar inserts each block for you; this page is the full reference.

It's the **only** lesson format: the app's renderer, the editor's problems panel, the glossary, formula sheets, revision cards and read-aloud all read it through one parser (`lib/core/lessons/lesson_doc.dart`). If this page and the parser disagree, the parser is right and this page is a bug.

## House style

- **Neutral, textbook-formal English, British spelling** (as WAEC uses): *colour*, *centre*, *practise* (verb) / *practice* (noun).
- Address the student directly and plainly. Define a term the first time it appears, in a `definition` box.
- One idea per paragraph. Short paragraphs read better on a phone.
- Every topic's lesson should end with the topic test in mind: the last article usually has a `summary` and an `exam` tip.

## Maths

Maths is LaTeX, exactly as in the question bank:

| You want | Write |
|---|---|
| Inline maths | `\( x^2 + 1 \)` |
| A displayed equation, on its own line | `\[ x = \frac{-b \pm \sqrt{b^2-4ac}}{2a} \]` or `$$ … $$` |
| Bold / italic text | `\textbf{bold}`, `\textit{italic}` |
| A dollar sign | just `$`; a lone `$` is money, never maths |

`**bold**`, `*italic*` and `$…$` inline maths are **not** supported. `*` and `_` appear inside maths constantly, and a lone `$` is always currency.

## Basic text

These are unchanged from the original article format.

```
# Title                  (one per article, at most)
## Section
### Sub-section

A paragraph. Lines next to each other join into one paragraph;
a blank line starts a new one.

- a bullet
- another

1. a numbered item (your numbers are kept)
2. the next

> A quote. Consecutive > lines are one quote.

---                      (a horizontal rule)
```

## Fenced blocks

A fenced block starts with `::: kind` (plus an optional title on the same line) and ends with a line that is just `:::`. Blocks can be nested.

### Callout boxes

```
::: definition Number base
The number of distinct digits a place-value system uses.
:::
```

| Kind | Label shown | Use it for |
|---|---|---|
| `note` | Note | A side remark |
| `tip` | Tip | A helpful shortcut |
| `remember` | Remember | Something to memorise; **becomes a revision card** |
| `mistake` | Common mistake | What students get wrong |
| `exam` | Exam tip | How WAEC asks about it |
| `definition Term` | Definition | **Feeds the glossary and cards.** Always give the term |
| `formula Name` | Formula | **Feeds the formula sheet and cards.** Put the formula in `\[ … \]` |
| `theorem Name` | Theorem | A result with a name |
| `objectives` | By the end of this lesson | A short list, at the start |
| `summary` | Summary | Key points, at the end; **each bullet becomes a card** |

### Worked example (steps revealed one at a time)

```
::: example Convert 1011₂ to base ten
Write each digit against its place value.
--- step Expand
\[ 1 \times 2^3 + 0 \times 2^2 + 1 \times 2^1 + 1 \times 2^0 \]
--- step Add
\( 8 + 0 + 2 + 1 \)
--- answer
\( 11 \)
:::
```

The text before the first `--- step` is the problem. Each `--- step Title` begins a step (the title is optional). `--- answer` is optional. A bare `---` inside the block is still a horizontal rule.

### Try it yourself

```
::: tryit
Convert \( 110_2 \) to base ten.
--- hint
The place values are 4, 2 and 1.
--- answer
\( 6 \)
:::
```

### Quick check (instant feedback, nothing saved)

```
::: check
What is \( 101_2 \) in base ten?
- [ ] 3
- [x] 5
- [ ] 6
--- why
\( 4 + 0 + 1 = 5 \)
:::
```

Exactly **one** option must be marked `[x]`. At least two options are needed.

### A question from the bank

```
::: check q:<questionId>
:::

::: waec q:<questionId>
:::
```

`waec` shows the question as **"Seen in WAEC <year>"**. The editor's question picker inserts these for you.

### Revision card

```
::: card
What does the subscript in 101₂ tell you?
---
The base the number is written in.
:::
```

### Go deeper (collapsed)

```
::: more Why this works
Optional extra depth, hidden until tapped.
:::
```

### Video inside the text

```
::: video https://www.youtube.com/watch?v=XXXXXXXXXXX
:::
```

Any YouTube link or the 11-character id works.

### Note to yourself (never shown to students)

```
::: todo Diagram needed: triangle ABC with the right angle at C
:::
```

Every `todo` is listed in the problems panel, so none ship forgotten.

## Images

```
![Caption shown under the image](asset:AbC123){width=60%}
```

- Upload with the editor's image button, which inserts the line for you. `asset:` images live in the app and work offline.
- `https://` links also work but depend on the other site staying up.
- `{width=…%}` is optional (1–100%, default 100%).

## Tables

```
| Base | Digits used | Example |
|:-----|:-----------:|--------:|
| 2    | \(0, 1\)    | \(101_2\) |
| 8    | 0 to 7      | \(17_8\)  |
```

The second row is required. Colons set the alignment: `:---` left, `:---:` centre, `---:` right. Maths works in cells. Write `\|` for a literal bar inside a cell.

## What happens with mistakes

Nothing a student sees ever breaks:
- An unknown `::: kind` shows its contents as plain text.
- An unclosed block runs to the end of the article.
- A quick check without exactly one right answer shows its options without judging.

Every such problem appears in the editor's **problems panel** with its line number.
