---
type: article
title: Converting between bases
---
# Converting between bases

Two directions, two different methods. Both are mechanical once you have seen
them, and both are worth doing slowly the first few times.

## Any base to base ten: expand it

Write out the place values and add. That is the whole method.

Convert \(2314_5\) to base ten:

\[ 2 \times 5^3 + 3 \times 5^2 + 1 \times 5^1 + 4 \times 5^0 \]

\[ = 2 \times 125 + 3 \times 25 + 1 \times 5 + 4 \times 1 \]

\[ = 250 + 75 + 5 + 4 = 334 \]

So \(2314_5 = 334_{10}\).

The one thing to watch is the rightmost digit: it carries \(b^0\), which is
\(1\), not \(b\). Starting the powers in the wrong place is the most common
slip on this conversion.

## Base ten to any base: divide repeatedly

Divide by the new base, write down the remainder, and keep dividing the
quotient until it reaches zero. Then read the remainders \textbf{upwards}.

Convert \(334\) to base five:

1. \(334 \div 5 = 66\) remainder \(4\)
2. \(66 \div 5 = 13\) remainder \(1\)
3. \(13 \div 5 = 2\) remainder \(3\)
4. \(2 \div 5 = 0\) remainder \(2\)

Reading the remainders from the bottom up gives \(2314_5\) — which is where we
started, so the two methods agree.

> Reading the remainders downwards instead of upwards gives \(4132_5\), which
> is a completely different number. If your answer disagrees with the original
> by a reversal, this is almost certainly why.

## Between two bases, neither of them ten

There is no separate method. Go through base ten: expand out of the first base,
then divide into the second.

To convert \(1101_2\) to base five:

\[ 1101_2 = 8 + 4 + 0 + 1 = 13_{10} \]

Then \(13 \div 5 = 2\) remainder \(3\), and \(2 \div 5 = 0\) remainder \(2\),
so \(1101_2 = 23_5\).

## Checking your work

Every conversion can be checked by converting back. It takes twenty seconds and
it catches the two errors that actually happen: a misplaced power, and
remainders read the wrong way round.
