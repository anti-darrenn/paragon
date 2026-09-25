---
type: article
title: What a number base actually means
---
# What a number base actually means

Every number you write down is shorthand. When you write \(3428\), you are not
naming a single symbol — you are saying "three thousands, four hundreds, two
tens and eight units". The position of each digit tells you which power of ten
it carries:

\[ 3428 = 3 \times 10^3 + 4 \times 10^2 + 2 \times 10^1 + 8 \times 10^0 \]

That ten is the \textbf{base}. Nothing about arithmetic requires it. We use ten
because we have ten fingers, and for no deeper reason than that.

## The same idea in any base

Swap the ten for any whole number \(b > 1\) and everything else survives
unchanged. In base \(b\), a number written \(d_n \ldots d_2 d_1 d_0\) means:

\[ d_n b^n + \cdots + d_2 b^2 + d_1 b^1 + d_0 b^0 \]

So \(1011_2\) — read "one zero one one base two" — is:

\[ 1 \times 2^3 + 0 \times 2^2 + 1 \times 2^1 + 1 \times 2^0 = 8 + 0 + 2 + 1 = 11 \]

The subscript is not decoration. \(101\) is one hundred and one in base ten,
five in base two, and ten in base three. Without the subscript the digits alone
do not tell you what number you are looking at.

## Which digits are allowed

In base \(b\) the digits run from \(0\) to \(b - 1\). That is the rule that
catches most mistakes in an exam:

- Base 2 uses only \(0\) and \(1\)
- Base 8 uses \(0\) through \(7\)
- Base 5 uses \(0\) through \(4\)

> There is no digit \(8\) in base 8, in the same way there is no single digit
> for ten in base ten. If you ever write \(58_5\), something has gone wrong —
> that \(5\) cannot exist in base five.

For bases above ten we run out of digits and borrow letters: \(A\) stands for
ten, \(B\) for eleven, and so on. So \(2A_{16}\) means
\(2 \times 16 + 10 = 42\).

## Why WAEC asks about it

Two reasons, and both come up every year. Computers store everything in base
two, so binary is the one base outside ten you will meet in real work. And
converting between bases is a clean test of whether you understand place value
at all, rather than having memorised the ten-times table.
