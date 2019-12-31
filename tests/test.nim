# Copyright © 2019-20 Mark Summerfield. All rights reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may only use this file in compliance with the License. The license
# is available from http://www.apache.org/licenses/LICENSE-2.0

import diff
import hashes
import sequtils
import strformat
import strutils
import sugar
import unittest

proc replacements*[T](a, b: seq[T]; prefix="% ", sep=" => "): string =
  var i = 0
  var j = 0
  while i < len(a) and j < len(b):
    result.add(prefix & $a[i] & sep & $b[j] & "\n")
    inc i
    inc j
  while i < len(a):
    result.add(prefix & $a[i] & sep & "\n")
    inc i
  while j < len(b):
    result.add(prefix & sep & $b[i] & "\n")
    inc j
  if result.endsWith('\n'):
    result = result[0 .. ^2]

# For Items, we only consider the text (to make testing easier)
type
  Item = object
    x: int
    y: int
    text: string

proc newItem(x, y: int, text: string): Item =
  result.x = x
  result.y = y
  result.text = text

# This must match `==`
proc hash(i: Item): Hash =
  var h: Hash = 0
  h = h !& hash(i.text)
  !$h

# This must match hash()
proc `==`(a, b: Item): bool =
  a.text == b.text

suite "diff tests":

  test "01":
    let a = "the quick brown fox jumped over the lazy dogs".split()
    let b = "the quick red fox jumped over the very busy dogs".split()
    let diff = newDiff(a, b)
    let expected = @[
      newSpan(tagEqual, 0, 2, 0, 2),   # the quick
      newSpan(tagReplace, 2, 3, 2, 3), # brown -> red
      newSpan(tagEqual, 3, 7, 3, 7),   # fox jumped over the
      newSpan(tagReplace, 7, 8, 7, 9), # lazy -> very busy
      newSpan(tagEqual, 8, 9, 9, 10),  # dogs
      ]
    let spans = toSeq(diff.spans())
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "02":
    let a = toSeq("qabxcd")
    let b = toSeq("abycdf")
    let diff = newDiff(a, b)
    let expected = @[
        newSpan(tagDelete, 0, 1, 0, 0),  # q ->
        newSpan(tagEqual, 1, 3, 0, 2),   # ab
        newSpan(tagReplace, 3, 4, 2, 3), # x -> y
        newSpan(tagEqual, 4, 6, 3, 5),   # cd
        newSpan(tagInsert, 6, 6, 5, 6),  # -> f
      ]
    let spans = toSeq(diff.spans())
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "03":
    let a = toSeq("private Thread currentThread;")
    let b = toSeq("private volatile Thread currentThread;")
    let diff = newDiff(a, b)
    let expected = @[
        newSpan(tagEqual, 0, 6, 0, 6),    # privat
        newSpan(tagInsert, 6, 6, 6, 15),  # -> e volatil
        newSpan(tagEqual, 6, 29, 15, 38), # e Thread currentThread;
    ]
    let spans = toSeq(diff.spans())
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "04":
    let a = "the quick brown fox jumped over the lazy dogs".split()
    let b = "the quick red fox jumped over the very busy dogs".split()
    let diff = newDiff(a, b)
    let longest = diff.longestMatch(0, len(a), 0, len(b))
    check(newMatch(3, 3, 4) == longest)

  test "05":
    let a = "a s c ( 99 ) x z".split()
    let b = "r s b c ( 99 )".split()
    let diff = newDiff(a, b)
    let longest = diff.longestMatch(0, len(a), 0, len(b))
    check(newMatch(2, 3, 4) == longest)

  test "06":
    let a = "foo\nbar\nbaz\nquux".split('\n')
    let b = "foo\nbaz\nbar\nquux".split('\n')
    let diff = newDiff(a, b)
    let expected = @[
        newSpan(tagEqual, 0, 1, 0, 1),  # foo
        newSpan(tagInsert, 1, 1, 1, 2), # -> baz
        newSpan(tagEqual, 1, 2, 2, 3),  # bar
        newSpan(tagDelete, 2, 3, 3, 3), # baz ->
        newSpan(tagEqual, 3, 4, 3, 4),  # quux
    ]
    let spans = toSeq(diff.spans())
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "07":
    let a = "foo\nbar\nbaz\nquux".split('\n')
    let b = "foo\nbaz\nbar\nquux".split('\n')
    let diff = newDiff(a, b)
    let expected = @[
        newSpan(tagInsert, 1, 1, 1, 2), # -> baz
        newSpan(tagDelete, 2, 3, 3, 3), # baz ->
    ]
    # See test 08 for a better solution
    let spans = filter(toSeq(diff.spans()), span => span.tag != tagEqual)
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "08":
    let a = "foo\nbar\nbaz\nquux".split('\n')
    let b = "foo\nbaz\nbar\nquux".split('\n')
    let diff = newDiff(a, b)
    let expected = @[
        newSpan(tagInsert, 1, 1, 1, 2), # -> baz
        newSpan(tagDelete, 2, 3, 3, 3), # baz ->
    ]
    let spans = toSeq(diff.spans(skipEqual=true))
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "09":
    let a = @[1, 2, 3, 4, 5, 6]
    let b = @[2, 3, 5, 7]
    let diff = newDiff(a, b)
    let expected = @[
        newSpan(tagDelete, 0, 1, 0, 0),  # 1 ->
        newSpan(tagEqual, 1, 3, 0, 2),   # 2 3
        newSpan(tagDelete, 3, 4, 2, 2),  # 4 ->
        newSpan(tagEqual, 4, 5, 2, 3),   # 5
        newSpan(tagReplace, 5, 6, 3, 4), # 6 -> 7
    ]
    let spans = toSeq(diff.spans())
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "10":
    let a = toSeq("qabxcd")
    let b = toSeq("abycdf")
    let diff = newDiff(a, b)
    let expected = @[
        newSpan(tagDelete, 0, 1, 0, 0),  # q ->
        newSpan(tagEqual, 1, 3, 0, 2),   # a b
        newSpan(tagReplace, 3, 4, 2, 3), # x -> y
        newSpan(tagEqual, 4, 6, 3, 5),   # c d
        newSpan(tagInsert, 6, 6, 5, 6),  # -> f
    ]
    let spans = toSeq(diff.spans())
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "11":
    let a = @[
      newItem(1, 3, "A"),
      newItem(2, 4, "B"),
      newItem(3, 8, "C"),
      newItem(5, 9, "D"),
      newItem(7, 2, "E"),
      newItem(3, 8, "F"),
      newItem(1, 6, "G"),
      ]
    let b = @[
      newItem(3, 1, "A"),
      newItem(8, 3, "C"),
      newItem(9, 5, "B"),
      newItem(8, 3, "D"),
      newItem(6, 1, "E"),
      newItem(4, 2, "G"),
      ]
    let diff = newDiff(a, b)
    let expected = @[
      newSpan(tagEqual, 0, 1, 0, 1),  # A
      newSpan(tagInsert, 1, 1, 1, 2), # -> C
      newSpan(tagEqual, 1, 2, 2, 3),  # B
      newSpan(tagDelete, 2, 3, 3, 3), # C ->
      newSpan(tagEqual, 3, 5, 3, 5),  # D E
      newSpan(tagDelete, 5, 6, 5, 5), # F ->
      newSpan(tagEqual, 6, 7, 5, 6),  # G
      ]
    let spans = toSeq(diff.spans())
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "12":
    let a = @[
      newItem(1, 3, "quebec"),
      newItem(2, 4, "alpha"),
      newItem(3, 8, "bravo"),
      newItem(5, 9, "x-ray"),
      ]
    let b = @[
      newItem(3, 1, "alpha"),
      newItem(8, 3, "bravo"),
      newItem(9, 5, "yankee"),
      newItem(8, 3, "charlie"),
      ]
    let diff = newDiff(a, b)
    let expected = @[
      newSpan(tagDelete, 0, 1, 0, 0),  # quebec ->
      newSpan(tagEqual, 1, 3, 0, 2),   # alpha bravo
      newSpan(tagReplace, 3, 4, 2, 4), # x-ray -> yankee charlie
      ]
    let spans = toSeq(diff.spans())
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "13":
    let a = toSeq("abxcd")
    let b = toSeq("abcd")
    let diff = newDiff(a, b)
    let expected = @[
        newMatch(0, 0, 2),
        newMatch(3, 2, 2),
        newMatch(5, 4, 0),
    ]
    let matches = diff.matches()
    check(len(expected) == len(matches))
    for (act, exp) in zip(matches, expected):
      check(act == exp)

  test "14":
    let a = "the quick brown fox jumped over the lazy dogs".split()
    let b = newSeq[string]() # empty
    let diff = newDiff(a, b)
    let expected = @[newSpan(tagDelete, 0, 9, 0, 0)]
    let spans = toSeq(diff.spans())
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "15":
    let a = newSeq[string]() # empty
    let b = "the quick red fox jumped over the very busy dogs".split()
    let diff = newDiff(a, b)
    let expected = @[newSpan(tagInsert, 0, 0, 0, 10)]
    let spans = toSeq(diff.spans())
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "16":
    let a = newSeq[string]() # empty
    let b = newSeq[string]() # empty
    let diff = newDiff(a, b)
    let spans = toSeq(diff.spans())
    check(len(spans) == 0)

  test "17":
    #        0   1     2     3   4      5    6   7    8
    let a = "the quick brown fox jumped over the lazy dogs".split()
    #        0   1     2   3   4      5    6   7    8    9
    let b = "the quick red fox jumped over the very busy dogs".split()
    let diff = newDiff(a, b)
    let expected = @[
      newSpan(tagEqual, 0, 2, 0, 2),   # the quick
      newSpan(tagReplace, 2, 3, 2, 3),  # brown -> red
      newSpan(tagEqual, 3, 7, 3, 7),   # fox jumped over the
      newSpan(tagReplace, 7, 8, 7, 9),  # lazy -> very busy
      newSpan(tagEqual, 8, 9, 9, 10),  # dogs
      ]
    let spans = toSeq(diff.spans())
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "18":
    let a = "the quick brown fox jumped over the lazy dogs".split()
    let b = "the slow red fox jumped over the very busy dogs".split()
    let expected = @[
      """change "quick brown" => "slow red"""",
      """change "lazy" => "very busy""""
      ]
    var spans = newSeq[string]()
    let diff = newDiff(a, b)
    for span in toSeq(diff.spans(skipEqual = true)):
      let aspan = join(a[span.aStart ..< span.aEnd], " ")
      let bspan = join(b[span.bStart ..< span.bEnd], " ")
      case span.tag
      of tagReplace:
        spans.add("change \"" & aspan & "\" => \"" & bspan & "\"")
      of tagInsert: spans.add("insert \"" & bspan & "\"")
      of tagDelete: spans.add("delete \"" & aspan & "\"")
      of tagEqual: doAssert(false) # Should never occur
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "19":
    let a = "the quick brown fox jumped over the lazy dogs".split()
    let b = "the slow red fox jumped over the very busy dogs".split()
    let expected = @[
      """replace "quick brown" => "slow red"""",
      """replace "lazy" => "very busy"""",
      ]
    var spans = newSeq[string]()
    let diff = newDiff(a, b)
    for span in diff.spans(skipEqual = true):
      let aspan = join(a[span.aStart ..< span.aEnd], " ")
      let bspan = join(b[span.bStart ..< span.bEnd], " ")
      case span.tag
      of tagReplace: spans.add("replace \"" & aspan & "\" => \"" &
                               bspan & "\"")
      of tagInsert: spans.add("insert \"" & bspan & "\"")
      of tagDelete: spans.add("delete \"" & aspan & "\"")
      of tagEqual: doAssert(false) # Should never occur
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "20":
    let a = "quebec alpha bravo x-ray yankee".split()
    let b = "alpha bravo yankee charlie".split()
    let expected = @[
      """delete "quebec"""",
      """delete "x-ray"""",
      """insert "charlie"""",
      ]
    var spans = newSeq[string]()
    let diff = newDiff(a, b)
    for span in diff.spans(skipEqual = true):
      let aspan = join(a[span.aStart ..< span.aEnd], " ")
      let bspan = join(b[span.bStart ..< span.bEnd], " ")
      case span.tag
      of tagReplace:
        spans.add("change \"" & aspan & "\" => \"" & bspan & "\"")
      of tagInsert: spans.add("insert \"" & bspan & "\"")
      of tagDelete: spans.add("delete \"" & aspan & "\"")
      of tagEqual: doAssert(false) # Should never occur
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "21":
    let a = ("Tulips are yellow,\nViolets are blue,\nAgar is sweet,\n" &
             "As are you.").split('\n')
    let b = ("Roses are red,\nViolets are blue,\nSugar is sweet,\n" &
             "And so are you.").split('\n')
    let expected = @[
      "replace a[0:1]: Tulips are yellow, => Roses are red,",
      "replace a[2:4]: Agar is sweet, NL As are you. => " &
        "Sugar is sweet, NL And so are you."
      ]
    var spans = newSeq[string]()
    let diff = newDiff(a, b)
    for span in diff.spans(skipEqual = true):
      case span.tag
      of tagReplace:
        spans.add(&"replace a[{span.aStart}:{span.aEnd}]: " &
                  join(a[span.aStart ..< span.aEnd], " NL ") & " => " &
                  join(b[span.bStart ..< span.bEnd], " NL "))
      of tagDelete:
        spans.add(&"delete a[{span.aStart}:{span.aEnd}]: " &
                  join(a[span.aStart ..< span.aEnd], " NL "))
      of tagInsert:
        spans.add(&"insert b[{span.bStart}:{span.bEnd}]: " &
                  join(b[span.bStart ..< span.bEnd], " NL "))
      of tagEqual: doAssert(false) # Should never occur
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "22":
    let a = ("Tulips are yellow,\nViolets are blue,\nAgar is sweet,\n" &
             "As are you.").split('\n')
    let b = ("Roses are red,\nViolets are blue,\nSugar is sweet,\n" &
             "And so are you.").split('\n')
    let expected = @[
      "replace [0:1]: Tulips are yellow, => Roses are red,",
      "replace [2:4]: Agar is sweet, NL As are you. => Sugar is sweet, " &
        "NL And so are you.",
      ]
    var spans = newSeq[string]()
    let diff = newDiff(a, b)
    for span in diff.spans(skipEqual = true):
      case span.tag
      of tagReplace:
        spans.add(&"replace [{span.aStart}:{span.aEnd}]: " &
                  join(a[span.aStart ..< span.aEnd], " NL ") & " => " &
                  join(b[span.bStart ..< span.bEnd], " NL "))
      of tagDelete:
        spans.add(&"delete a[{span.aStart}:{span.aEnd}]: " &
                  join(a[span.aStart ..< span.aEnd], " NL "))
      of tagInsert:
        spans.add(&"insert b[{span.bStart}:{span.bEnd}]: " &
                  join(b[span.bStart ..< span.bEnd], " NL "))
      of tagEqual: doAssert(false) # Should never occur
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "23":
    let a = ("Tulips are yellow,\nViolets are blue,\nAgar is sweet,\n" &
             "As are you.").split('\n')
    let b = ("Roses are red,\nViolets are blue,\nSugar is sweet,\n" &
             "And so are you.").split('\n')
    let expected = @[
      "% Tulips are yellow, => Roses are red,",
      "= Violets are blue,",
      "% Agar is sweet, => Sugar is sweet,\n" &
        "% As are you. => And so are you.",
      ]
    var spans = newSeq[string]()
    for span in spanSlices(a, b):
      case span.tag
      of tagReplace: spans.add(replacements(span.a, span.b))
      of tagDelete: spans.add("- " & join(span.a, "\n"))
      of tagInsert: spans.add("+ " & join(span.b, "\n"))
      of tagEqual: spans.add("= " & join(span.a, "\n"))
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "24":
    let a = ("Tulips are yellow,\nViolets are blue,\nAgar is sweet,\n" &
             "As are you.").split('\n')
    let b = ("Roses are red,\nViolets are blue,\nSugar is sweet,\n" &
             "And so are you.").split('\n')
    let expected = @[
      "- Tulips are yellow,",
      "+ Roses are red,",
      "= Violets are blue,",
      "- Agar is sweet,\nAs are you.",
      "+ Sugar is sweet,\nAnd so are you.",
      ]
    var spans = newSeq[string]()
    for span in spanSlices(a, b):
      case span.tag
      of tagReplace:
        spans.add("- " & join(span.a, "\n"))
        spans.add("+ " & join(span.b, "\n"))
      of tagDelete: spans.add("- " & join(span.a, "\n"))
      of tagInsert: spans.add("+ " & join(span.b, "\n"))
      of tagEqual: spans.add("= " & join(span.a, "\n"))
    check(len(expected) == len(spans))
    for (act, exp) in zip(spans, expected):
      check(act == exp)

  test "25":
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
