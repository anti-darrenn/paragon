---
type: article
title: Adding and subtracting in another base
---
# Adding and subtracting in another base

Column addition works in every base. The only thing that changes is when you
carry: in base ten you carry at ten, and in base \(b\) you carry at \(b\).

## Addition

Add \(243_5 + 134_5\), working right to left.

- Units: \(3 + 4 = 7\). That is \(7 = 1 \times 5 + 2\), so write \(2\) and
  carry \(1\).
- Fives: \(4 + 3 + 1 = 8\). That is \(8 = 1 \times 5 + 3\), so write \(3\) and
  carry \(1\).
- Twenty-fives: \(2 + 1 + 1 = 4\). That is less than \(5\), so write \(4\).

\[ 243_5 + 134_5 = 432_5 \]

Check it in base ten: \(243_5 = 73\), \(134_5 = 44\), and \(73 + 44 = 117\).
Converting \(117\) to base five gives \(432_5\). It agrees.

## Subtraction

Borrowing works the same way, except that a borrowed unit is worth \(b\), not
ten.

Subtract \(142_5\) from \(321_5\):

- Units: \(1 - 2\) will not do, so borrow from the fives column. The borrowed
  unit is worth \(5\), so the units become \(1 + 5 = 6\), and \(6 - 2 = 4\).
- Fives: the \(2\) is now \(1\). Again \(1 - 4\) will not do, so borrow from the
  twenty-fives: \(1 + 5 = 6\), and \(6 - 4 = 2\).
- Twenty-fives: the \(3\) is now \(2\), and \(2 - 1 = 1\).

\[ 321_5 - 142_5 = 124_5 \]

## The mistake to avoid

The digits you write must stay inside the base. If a column of your answer
contains a digit of \(5\) or more in base five, you have forgotten to carry.
That check alone will catch most errors before you hand the paper in.

- In base 2, carry at \(2\) — so \(1 + 1 = 10_2\)
- In base 8, carry at \(8\) — so \(7 + 1 = 10_8\)
- In base 5, carry at \(5\) — so \(4 + 1 = 10_5\)

Every one of those reads as "one zero" in its own base, and every one of them
means a different number.
