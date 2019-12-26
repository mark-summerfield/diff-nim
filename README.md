# diff
Nim implementation of Python difflib's sequence matcher

diff is a library for finding the differences between two sequences.

The sequences can be of lines, strings (e.g., words), characters,
bytes, or of any custom “item” type so long as it implements `==`
and `hash()`.

For other Nim code see http://www.qtrac.eu/sitemap.html#foss

# Examples

For example, this code:
```nim
let a = ("Tulips are yellow,\nViolets are blue,\nAgar is sweet,\n" &
         "As are you.").split('\n')
let b = ("Roses are red,\nViolets are blue,\nSugar is sweet,\n" &
         "And so are you.").split('\n')
for span in spanSlices(a, b):
  case span.tag
  of tagReplace:
    for text in span.a:
      echo("- ", text)
    for text in span.b:
      echo("+ ", text)
  of tagDelete:
    for text in span.a:
      echo("- ", text)
  of tagInsert:
    for text in span.b:
      echo("+ ", text)
  of tagEqual:
    for text in span.a:
      echo("= ", text)
```
produces this output:
```
- Tulips are yellow,
+ Roses are red,
= Violets are blue,
- Agar is sweet,
- As are you.
+ Sugar is sweet,
+ And so are you.
```

If you need indexes rather than subsequences themselves, use
``spans(a, b)``.

To skip the same subsequences pass ``skipEqual = true`` and for
``tagEqual`` use: ``of tagEqual: doAssert(false)``.

See also `tests/test.nim`.

# License

diff is free open source software (FOSS) licensed under the 
Apache License, Version 2.0.
