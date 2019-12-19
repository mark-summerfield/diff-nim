# Copyright © 2019-20 Mark Summerfield. All rights reserved.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may only use this file in compliance with the License. The license
# is available from http://www.apache.org/licenses/LICENSE-2.0
{.experimental: "codeReordering".}

## This library provides methods for comparing two sequences.
##
## The sequences could be seq[string] of words, or any other sequence
## providing the elements support ``==`` and ``hash()``.
##
## To get a comparison, first call ``diff = newDiff(a, b)`` where ``a``
## and ``b`` are both sequences containing the same type of object. Then
## call ``diff.spans()`` to get a sequence of ``Spans`` which if followed
## would turn sequence ``a`` into sequence ``b``.
##
## (The algorithm is a slightly simplified version of the one used by the
## Python difflib module's SequenceMatcher.)

import algorithm
import math
import sequtils
import sets
import sugar
import tables

type
  Match* = tuple[aStart, bStart, length: int]

  Span* = tuple[tag: Tag, aStart, aEnd, bStart, bEnd: int]

  Tag* = enum
    tagEqual = "equal"
    tagInsert = "insert"
    tagDelete = "delete"
    tagReplace = "replace"

  Diff*[T] = object
    a: seq[T]
    b: seq[T]
    b2j: Table[T, seq[int]]

proc newMatch*(aStart, bStart, length: int): Match =
  (aStart, bStart, length)

proc newSpan*(tag: Tag): Span =
  result.tag = tag

proc newSpan*(tag: Tag, aStart, aEnd, bStart, bEnd: int): Span =
  result.tag = tag
  result.aStart = aStart
  result.aEnd = aEnd
  result.bStart = bStart
  result.bEnd = bEnd

proc `==`*(a, b: Span): bool =
  a.tag == b.tag and a.aStart == b.aStart and a.aEnd == b.aEnd and
  a.bStart == b.bStart and a.bEnd == b.bEnd

proc newDiff*[T](a, b: seq[T]): Diff[T] =
  ## Creates a new ``Diff`` and computes the comparison data.
  ##
  ## To get all the spans (equals, insertions, deletions, replacements)
  ## necessary to convert sequence `a` into `b`, use ``diff.spans()``.
  ##
  ## To get all the matches (i.e., the positions and lengths) where `a`
  ## and `b` are the same, use ``diff.matches()``.
  ##
  ## If you need _both_ the matches _and_ the spans, use
  ## ``diff.matches()``, and then use ``spansForMatches()``.
  result.a = a
  result.b = b
  result.b2j = initTable[T, seq[int]]()
  result.chain_b_seq()

proc chain_b_seq[T](diff: var Diff[T]) =
  for (i, key) in diff.b.pairs():
    var indexes = diff.b2j.getOrDefault(key, @[])
    indexes.add(i)
    diff.b2j[key] = indexes
  if (let length = len(diff.b); length > 200):
    let popularLength = int(floor(float(length) / 100.0)) + 1
    var bPopular = initHashSet[T]()
    for (element, indexes) in diff.b2j.pairs():
      if len(indexes) > popularLength:
        bPopular.incl(element)
    for element in bPopular.items():
      diff.b2j.del(element)

proc spans*[T](diff: Diff[T], skipSame=false): seq[Span] =
  ## Returns all the spans (equals, insertions, deletions,
  ## replacements) necessary to convert sequence ``a`` into ``b``.
  ##
  ## If you need _both_ the matches _and_ the spans, use
  ## ``diff.matches()``, and then use ``spansForMatches()``.
  let matches = diff.matches()
  spansForMatches(matches, skipSame)

proc matches*[T](diff: Diff[T]): seq[Match] =
  ## Returns every ``Match`` between the two sequences.
  ##
  ## The differences are the spans between matches.
  ##
  ## To get all the spans (equals, insertions, deletions, replacements)
  ## necessary to convert sequence ``a`` into ``b``, use ``diff.spans()``.
  let aLen = len(diff.a)
  let bLen = len(diff.b)
  var queue = @[(0, aLen, 0, bLen)]
  var matches = newSeq[Match]()
  while len(queue) > 0:
    let (aStart, aEnd, bStart, bEnd) = queue.pop()
    let match = diff.longestMatch(aStart, aEnd, bStart, bEnd)
    let i = match.aStart
    let j = match.bStart
    let k = match.length
    if k > 0:
      matches.add(match)
      if aStart < i and bStart < j:
        queue.add((aStart, i, bStart, j))
      if i + k < aEnd and j + k < bEnd:
        queue.add((i + k, aEnd, j + k, bEnd))
  matches.sort()
  var aStart = 0
  var bStart = 0
  var length = 0
  for match in matches:
    if aStart + length == match.aStart and bStart + length == match.bStart:
      length += match.length
    else:
      if length != 0:
        result.add(newMatch(aStart, bStart, length))
      aStart = match.aStart
      bStart = match.bStart
      length = match.length
  if length != 0:
    result.add(newMatch(aStart, bStart, length))
  result.add(newMatch(aLen, bLen, 0))

proc longestMatch*[T](diff: Diff[T], aStart, aEnd, bStart, bEnd: int):
    Match =
  ## Returns the longest ``Match`` between the two given sequences, within
  ## the given index ranges.
  ##
  ## This is used internally, but may be useful, e.g., when called
  ## with say, ``diff.longest_match(0, len(a), 0, len(b))``.
  var bestI = aStart
  var bestJ = bStart
  var bestSize = 0
  var j2Len = initTable[int, int]()
  for i in aStart ..< aEnd:
    var tempJ2Len = initTable[int, int]()
    var indexes = diff.b2j.getOrDefault(diff.a[i], @[])
    if len(indexes) > 0:
      for j in indexes:
        if j < bStart:
          continue
        if j >= bEnd:
          break
        let k = j2Len.getOrDefault(j - 1, 0) + 1
        tempJ2Len[j] = k
        if k > bestSize:
          bestI = i - k + 1
          bestJ = j - k + 1
          bestSize = k
    j2len = tempJ2Len
  while bestI > aStart and bestJ > bStart and
      diff.a[bestI - 1] == diff.b[bestJ - 1]:
    dec bestI
    dec bestJ
    inc bestSize
  while bestI + bestSize < aEnd and bestJ + bestSize < bEnd and
      diff.a[bestI + bestSize] == diff.b[bestJ + bestSize]:
    inc bestSize
  newMatch(bestI, bestJ, bestSize)

proc spansForMatches*(matches: seq[Match], skipSame=false): seq[Span] =
  # Returns all the spans (equals, insertions, deletions, replacements)
  # necessary to convert sequence ``a`` into ``b``, given the precomputed
  # matches. Drops the equals spans if skipSame is true.
  #
  # Use this if you need _both_ matches _and_ spans, to avoid needlessly
  # recomputing the matches, i.e., call ``diff.matches()`` to get the
  # matches, and then this function for the spans.
  #
  # If you don't need the matches, then use ``diff.spans()``.
  var i = 0
  var j = 0
  for match in matches:
    var span = newSpan(tagEqual, i, match.aStart, j, match.bStart)
    if i < match.aStart and j < match.bStart:
      span.tag = tagReplace
    elif i < match.aStart:
      span.tag = tagDelete
    elif j < match.bStart:
      span.tag = tagInsert
    if span.tag != tagEqual:
      result.add(span)
    i = match.aStart + match.length
    j = match.bStart + match.length
    if match.length != 0:
      result.add(newSpan(tagEqual, match.aStart, i, match.bStart, j))
  if skipSame:
    result = filter(result, span => span.tag != tagEqual)
