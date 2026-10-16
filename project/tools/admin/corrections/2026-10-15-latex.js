// Hand corrections for audit B2 (15 Oct 2026): maths that does not render,
// and TeX left outside maths. Applied by `apply_corrections.js`. Each entry
// is one field of one past question: `find`/`replace` (every occurrence),
// or `set` for an explanation too tangled to patch. The `find` strings are
// the live text *after* `fix_questions.js` ran, which is why some contain
// \(…^\circ\) where the cache shows "30o".
//
// Besides typing errors in the TeX, a few explanations had slips the
// surrounding steps make unambiguous (55 + 63 written as 188, opp/hyp for
// tan, a reciprocal of 14 where every step before says 15). Those are
// corrected here too, and marked "arithmetic".
const r = String.raw;

module.exports = [
  { id: "0NVhYqGshRd9gbN68Q1T", field: "text", find: r`a\an`, replace: "a/an" },
  { id: "54UoWSDD4nDnX6LZ5pDC", field: "text", find: r`a\an?`, replace: "a/an?" },
  { id: "1Jv6HAP6lwliH9irCUQ5", field: "text", find: r`alpha(\alpha\) particle`, replace: r`alpha (\(\alpha\)) particle` },
  { id: "bhlmUIJeTeBJRRGeZe92", field: "text", find: r`\SQ\ = 4cm, \PT\ = 7cm`, replace: "/SQ/ = 4cm, /PT/ = 7cm" },

  { id: "Ajag6IXE391SKMeCJZ6U", field: "options.1", find: r`\edge`, replace: r`\wedge` },
  { id: "Ajag6IXE391SKMeCJZ6U", field: "options.2", find: r`\edge`, replace: r`\wedge` },
  { id: "L4zBwET5GxtYrUusJlmH", field: "options.3", find: r`\frac{1}{z^2}\0`, replace: r`\frac{1}{z^2}\)` },
  { id: "L4zBwET5GxtYrUusJlmH", field: "explanation", find: r`\alph \frac`, replace: r`\alpha \frac` },
  { id: "X2BFrwWV1wJKltrh5s2d", field: "options.0", find: r`20 (\sqrt{3}\)N`, replace: r`\(20\sqrt{3}\) N` },
  { id: "X2BFrwWV1wJKltrh5s2d", field: "options.2", find: r`10 (\sqrt{3}\)N`, replace: r`\(10\sqrt{3}\) N` },

  { id: "41WlIsGVwh0bvhRIP9e7", field: "explanation", find: r`\pid^2`, replace: r`\pi d^2` },
  {
    id: "4JmXydKYYRxg32qzX1RD",
    field: "explanation",
    set: [
      r`\(\sqrt{50} + \frac{10}{\sqrt{2}} = \frac{\sqrt{50}}{1} + \frac{10}{\sqrt{2}}\)`,
      r`= \(\frac{\sqrt{50 \times 2} + 10}{\sqrt{2}}\)`,
      r`= \(\frac{\sqrt{100} + 10}{\sqrt{2}}\)`,
      r`= \(\frac{10 + 10}{\sqrt{2}} = \frac{20}{\sqrt{2}}\)`,
      r`= \(\frac{20}{\sqrt{2}} \times \frac{\sqrt{2}}{\sqrt{2}}\)`,
      r`= \(\frac{20\sqrt{2}}{2}\)`,
      r`= 10\(\sqrt{2}\)`,
    ].join("\n\n"),
  },
  { id: "4bKV8MYn1n1dJjTzZ8GH", field: "explanation", find: r`\fra{`, replace: r`\frac{` },
  { id: "4mJz9WYNuU2TO5djROld", field: "explanation", find: "{330}\n\nHeat lost", replace: r`{330}\)` + "\n\nHeat lost" },
  { id: "65ewdX57GHIuSP9e1Auh", field: "explanation", find: r`\(P = begin{pmatrix}`, replace: r`\(P = \begin{pmatrix}` },
  { id: "77830wBwmZEyP2VxoV29", field: "explanation", find: "(c - a)^{2}}\n\nDistance", replace: r`(c - a)^{2}}\)` + "\n\nDistance" },
  { id: "7I8TXndxJvfbDUB5YNIj", field: "explanation", find: r`- (\frac{-3}{4}\) = (\frac{3}{4}\)`, replace: r`- \(\frac{-3}{4}\) = \(\frac{3}{4}\)` },
  { id: "7I8TXndxJvfbDUB5YNIj", field: "explanation", find: r`(x-a)\(^2\) + (x-b)`, replace: r`(x-a)\(^2\) + (y-b)` },
  { id: "GHK99rsTEj79Ott74eDV", field: "explanation", find: r`n(M \(\cup\) N \)`, replace: r`n(M \(\cup\) N)` },
  { id: "GHK99rsTEj79Ott74eDV", field: "explanation", find: r`n(M \(\cup\N)'`, replace: r`n(M \(\cup\) N)'` },
  { id: "IKoZ8ScofeGyuGFtlsIs", field: "explanation", find: r`50 = \9\frac{sum}{R}\)`, replace: r`50 = \(\frac{sum}{R}\)` },
  // arithmetic: the next lines subtract 118, so the two ages sum to 118
  { id: "IKoZ8ScofeGyuGFtlsIs", field: "explanation", find: "55 + 63 = 188", replace: "55 + 63 = 118" },
  { id: "IKoZ8ScofeGyuGFtlsIs", field: "explanation", find: "49R - 50R = -188 - 98", replace: "49R - 50R = -118 + 98" },
  { id: "IOsIrnqVcr23tetdgPzP", field: "explanation", find: r`\end{pmatrix} \(\begin{pmatrix} -2`, replace: r`\end{pmatrix} \begin{pmatrix} -2` },
  { id: "J3LRnSW9sLG1p3xvugwz", field: "explanation", find: r`\(q\propto\frac{1}{\sqrt{r}\)`, replace: r`\(q\propto\frac{1}{\sqrt{r}}\)` },
  { id: "KnSpqKlHBVLzwyFav5nH", field: "explanation", find: "{5} = 6\n\nvariance", replace: r`{5} = 6\)` + "\n\nvariance" },
  { id: "KnSpqKlHBVLzwyFav5nH", field: "explanation", find: r`(\(\bar{x} - \bar{x}\))`, replace: r`\((x - \bar{x})\)` },
  { id: "KnSpqKlHBVLzwyFav5nH", field: "explanation", find: r`(\(\bar{x} - \bar{x})^2\)`, replace: r`\((x - \bar{x})^2\)` },
  { id: "KnSpqKlHBVLzwyFav5nH", field: "explanation", find: r`\(\sum (x - x)^2\)`, replace: r`\(\sum (x - \bar{x})^2\)` },
  { id: "M0dDo7Y005RAoSCJVNcS", field: "explanation", find: r`y \(\alpha\) \sqrt{x + 1}\), y = k\sqrt{x + 1}\)`, replace: r`y \(\alpha \sqrt{x + 1}\), y = \(k\sqrt{x + 1}\)` },
  // arithmetic: k = 3 was found on the line before
  { id: "M0dDo7Y005RAoSCJVNcS", field: "explanation", find: r`y = \(\sqrt{(x + 1)}\)`, replace: r`y = 3\(\sqrt{(x + 1)}\)` },
  // arithmetic: 3x + 3x + 30° = 180°, so 6x = 150°
  {
    id: "Movcs4QS2XQh7OymSAZL",
    field: "explanation",
    find: r`6x \times \(30^\circ\) = \(180^\circ\); 6x + \(180^\circ\) - \(30^\circ\); 6x + \(150^\circ\)`,
    replace: r`6x + \(30^\circ\) = \(180^\circ\); 6x = \(180^\circ\) - \(30^\circ\); 6x = \(150^\circ\)`,
  },
  { id: "OgGzNsZWhL6N5xXTXLot", field: "explanation", find: "(a + b)h\n\n2lb", replace: r`(a + b)h\)` + "\n\n2lb" },
  { id: "OyEwgjauiLmxUZpZWwxE", field: "explanation", find: "- 6(1) + 4)\n\n= -1", replace: r`- 6(1) + 4\)` + "\n\n= -1" },
  { id: "PInADUyl3CChh0wHMvy0", field: "explanation", find: r`\Thus, the base`, replace: "Thus, the base" },
  { id: "PInADUyl3CChh0wHMvy0", field: "explanation", find: "f{Step 2", replace: "{Step 2" },
  { id: "PInADUyl3CChh0wHMvy0", field: "explanation", regex: r`\{(Step \d: [^}]*)\}`, replace: "$1" },
  { id: "RTyE7PGF9WsW8roJss1B", field: "explanation", find: r`\tect{`, replace: r`\text{` },
  { id: "SNh8SctqcfluLRho45kB", field: "explanation", find: r`\S.D = `, replace: "S.D = " },
  { id: "T6lLqT80BcYGxpLTOlsg", field: "explanation", find: "\\frac{8x}{100} = 117,760\n", replace: r`\frac{8x}{100}\) = 117,760` + "\n" },
  { id: "Vs0CUxGnV2ljRemUygF7", field: "explanation", find: r`(12)^{2}} \)`, replace: r`(12)^{2}}} \)` },
  { id: "WNtqkmRS7hmZNwKT9rQI", field: "explanation", find: r`\(r = \sqrt{\frac{85}{4} = `, replace: r`\(r = \sqrt{\frac{85}{4}} = ` },
  {
    id: "XbNqwFtvIKPuU9y0N8bL",
    field: "explanation",
    set: [
      r`\(7\frac{1}{2}-\left(2\frac{1}{2}+3\right)\div16\frac{1}{2} = \frac{15}{2} - \left(\frac{5}{2}+\frac{3}{1}\right)\div \frac{33}{2}\)`,
      r`\(= \frac{15}{2} - \left(\frac{5+6}{2}\right)\div \frac{33}{2} = \frac{15}{2} - \frac{11}{2} \div \frac{33}{2}\)`,
      r`\(\frac{11}{2}\) ÷ \(\frac{33}{2}\) = \(\frac{11}{2}\) × \(\frac{2}{33}\)`,
      r`= \(\frac{11}{33}\) or \(\frac{1}{3}\) (when simplified)`,
      r`\(\frac{15}{2}\) - \(\frac{1}{3}\) = \(\frac{43}{6}\)`,
      "7.166",
      "The nearest whole number is 7",
    ].join("\n\n"),
  },
  { id: "XfpcTUlWX5O9RISOAwKC", field: "explanation", find: r`P(3 and 5) = \frac{1}{6}`, replace: r`P(3 and 5) = \(\frac{1}{6}` },
  { id: "a0pXb462PX7wVj2JeEur", field: "explanation", find: r`\frac{1}{2} \times 4 tan 63^{\circ}[5+9]\right)\)`, replace: r`\frac{1}{2} \times 4 \tan 63^{\circ} \times (5+9)\)` },
  // arithmetic: tan is opposite over adjacent, as the next line uses
  { id: "a0pXb462PX7wVj2JeEur", field: "explanation", find: r`\frac{opp}{hyp}`, replace: r`\frac{opp}{adj}` },
  { id: "alnXkZk5lQKbKAoFlQgd", field: "explanation", find: r`\text{Mass of % Copper}`, replace: r`\text{Mass of Copper}` },
  { id: "bDgZLeXXAdek0r2q1NJr", field: "explanation", find: r`\frac{\text{60%}}{\text{100%}}`, replace: r`\frac{60}{100}` },
  { id: "bDgZLeXXAdek0r2q1NJr", field: "explanation", find: r`\frac{\text{40%}}{\text{100%}}`, replace: r`\frac{40}{100}` },
  { id: "bGmQLUmEY9KuyRw48qfg", field: "explanation", find: r`\bar{x)^{2}}`, replace: r`\bar{x})^{2}}` },
  { id: "c65T1ioSTDIl6rjbdKK0", field: "explanation", find: r`\(\frac{5\sqrt{3}}{\sqrt{6} = `, replace: r`\(\frac{5\sqrt{3}}{\sqrt{6}} = ` },
  { id: "c65T1ioSTDIl6rjbdKK0", field: "explanation", find: r`\(\frac{5\sqrt{18}{6} = `, replace: r`\(\frac{5\sqrt{18}}{6} = ` },
  { id: "dHHROGxIieAarp675KL6", field: "explanation", find: r`300\)m\s`, replace: r`300\) m/s` },
  // physics: frequency is speed over wavelength (λ), not π
  { id: "dHHROGxIieAarp675KL6", field: "explanation", find: r`\frac{v}{\pi}`, replace: r`\frac{v}{\lambda}` },
  { id: "fBJqITqYu68FFELW3O4a", field: "explanation", find: r`P\(_o\)(1 + \frac{r}{100})^n\)`, replace: r`P\(_o\)\((1 + \frac{r}{100})^n\)` },
  { id: "fBJqITqYu68FFELW3O4a", field: "explanation", find: r`3000(1 + \frac{3}{100})^3\)`, replace: r`3000\((1 + \frac{3}{100})^3\)` },
  { id: "fCfcgd0pzcyfwBG5GtzA", field: "explanation", find: r`\(\frac{10}{\frac{1}{\sqrt{3}}\)`, replace: r`\(\frac{10}{\frac{1}{\sqrt{3}}}\)` },
  { id: "jE16Z2o5LaR1BEpaTqCi", field: "explanation", find: r`\frac{\deltav}{\deltat}`, replace: r`\frac{\Delta v}{\Delta t}` },
  { id: "m1wP5gSF2RfIEslKsU1H", field: "explanation", find: r`(\frac{2}{3}\)^{2} = a`, replace: r`(\frac{2}{3})^{2} = a` },
  { id: "mOfzIhqZ8UYUfDCljaqb", field: "explanation", find: r`12^{2}| = \sqrt{169}`, replace: r`12^{2}} = \sqrt{169}` },
  { id: "rtYNufNJiuWJ4xdbB8cb", field: "explanation", find: r`\times 100%\)`, replace: r`\times 100\%\)` },
  { id: "rtYNufNJiuWJ4xdbB8cb", field: "explanation", find: r`\(3\frac{1}{8} %)`, replace: r`\(3\frac{1}{8}\)%` },
  { id: "umJNmVIcGkLTDkFi1V0z", field: "explanation", find: r`(-k)^{3 = 10 \times`, replace: r`(-k)^{3} = 10 \times` },
  { id: "uql0pvT8nPoRs3FDtPUU", field: "explanation", find: r`\frac{l}{11}`, replace: r`\frac{1}{11}` },
  { id: "uql0pvT8nPoRs3FDtPUU", field: "explanation", find: r`\tect{size of one exterior angle}\)`, replace: r`\text{size of one exterior angle}}\)` },
  // arithmetic: the exterior angle was just found to be 15°
  { id: "uql0pvT8nPoRs3FDtPUU", field: "explanation", find: r`\frac{360^o}{14^o}`, replace: r`\frac{360^o}{15^o}` },
  { id: "vkEbpHgeR6laWgtrk3nX", field: "explanation", find: r`(3x^{-2))^{2}`, replace: r`(-3x^{-2})^{2}` },
  {
    id: "wWjGQ6GPqnTABoyczIFH",
    field: "explanation",
    set: [r`\(\frac{1}{1-x} + \frac{2}{1+x}\)`, r`\(= \frac{1+x+2-2x}{(1-x)(1+x)} = \frac{3-x}{1-x^2}\)`].join("\n\n"),
  },
  { id: "xEG8wXY0M3jUbsL3EEmP", field: "explanation", find: r`\frac{GM_1M_}{r^2}`, replace: r`\frac{GM_1M_2}{r^2}` },
  { id: "xEG8wXY0M3jUbsL3EEmP", field: "explanation", find: r`\(\6.67 \times 10^{-11} \times 70 \times 60}{1^2}\)`, replace: r`\(\frac{6.67 \times 10^{-11} \times 70 \times 60}{1^2}\)` },
  { id: "xOAbvFZQxKr4LGbQQ3mG", field: "explanation", find: r`outcome}} = \(\frac{3}{6}\) = \(\frac{1}{2}\)`, replace: r`outcome}} = \frac{3}{6} = \frac{1}{2}\)` },
  { id: "xTMn8ISiDzzAiYTsnxmC", field: "explanation", find: r`→ \frac{-5}{60}\) = \frac{-1}{12}\)`, replace: r`→ \(\frac{-5}{60} = \frac{-1}{12}\)` },
  { id: "xevGmn4jCx9aaMmCLLnK", field: "explanation", find: r`\(\frac{N1122 \times $36}{$8}\)`, replace: r`\(\frac{1122 \times 36}{8}\)` },
  { id: "yIyZp1F5lLF1rJ19UHjo", field: "explanation", find: "(n - 1)d]\n", replace: r`(n - 1)d]\)` + "\n" },
  { id: "yIyZp1F5lLF1rJ19UHjo", field: "explanation", find: "(20 - 1)4]\n", replace: r`(20 - 1)4]\)` + "\n" },
];
