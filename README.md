# diff
Nim implementation of Python difflib's sequence matcher

diff is a library for finding the differences between two sequences.

The sequences can be of lines, strings (e.g., words), characters,
bytes, or of any custom “item” type so long as it implements `==`
and `hash()`.

# Examples

For example, this code:
```nim

let a = ("Tulips are yellow,\nViolets are blue,\nAgar is sweet,\n" &
					"As are you.").split('\n')
let b = ("Roses are red,\nViolets are blue,\nSugar is sweet,\n" &
					"And so are you.").split('\n')
let diff = newDiff(a, b)
for span in diff.spans(skipSame = true, useReplace = false):
	case span.tag
	of tagDelete:
		spans.add(&"delete a[{span.aStart}:{span.aEnd}]: " &
							join(a[span.aStart ..< span.aEnd], " NL "))
	of tagInsert:
		spans.add(&"insert b[{span.bStart}:{span.bEnd}]: " &
							join(b[span.bStart ..< span.bEnd], " NL "))
	of tagEqual, tagReplace: doAssert(false) # Should never occur
```
produces this output:
```
delete a[0:1]: Tulips are yellow,
insert b[0:1]: Roses are red,
delete a[2:4]: Agar is sweet, NL As are you.
insert b[2:4]: Sugar is sweet, NL And so are you.
```

See also `tests/test.nim`.

# License

diff is free open source software (FOSS) licensed under the 
Apache License, Version 2.0.
