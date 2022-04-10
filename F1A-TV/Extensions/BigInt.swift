//===--- BigInt.swift -----------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
// Imported by Noah Fetz on 10.04.22. from https://github.com/apple/swift/blob/main/test/Prototypes/BigInt.swift
//
//===----------------------------------------------------------------------===//

// RUN: %empty-directory(%t)
// RUN: %target-build-swift -swift-version 4 -o %t/a.out %s -Xfrontend -requirement-machine-inferred-signatures=on -Xfrontend -requirement-machine-abstract-signatures=on -Xfrontend -requirement-machine-protocol-signatures=on
// RUN: %target-codesign %t/a.out
// RUN: %target-run %t/a.out
// REQUIRES: executable_test
// REQUIRES: CPU=x86_64

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#elseif os(Windows)
  import CRT
#else
#error("Unsupported platform")
#endif

extension FixedWidthInteger {
  /// Returns the high and low parts of a potentially overflowing addition.
  func addingFullWidth(_ other: Self) ->
    (high: Self, low: Self) {
    let sum = self.addingReportingOverflow(other)
    return (sum.overflow ? 1 : 0, sum.partialValue)
  }

  /// Returns the high and low parts of two seqeuential potentially overflowing
  /// additions.
  static func addingFullWidth(_ x: Self, _ y: Self, _ z: Self) ->
    (high: Self, low: Self) {
    let xy = x.addingReportingOverflow(y)
    let xyz = xy.partialValue.addingReportingOverflow(z)
    let high: Self = (xy.overflow ? 1 : 0) +
      (xyz.overflow ? 1 : 0)
    return (high, xyz.partialValue)
  }

  /// Returns a tuple containing the value that would be borrowed from a higher
  /// place and the partial difference of this value and `rhs`.
  func subtractingWithBorrow(_ rhs: Self) ->
    (borrow: Self, partialValue: Self) {
    let difference = subtractingReportingOverflow(rhs)
    return (difference.overflow ? 1 : 0, difference.partialValue)
  }

  /// Returns a tuple containing the value that would be borrowed from a higher
  /// place and the partial value of `x` and `y` subtracted from this value.
  func subtractingWithBorrow(_ x: Self, _ y: Self) ->
    (borrow: Self, partialValue: Self) {
    let firstDifference = subtractingReportingOverflow(x)
    let secondDifference =
      firstDifference.partialValue.subtractingReportingOverflow(y)
    let borrow: Self = (firstDifference.overflow ? 1 : 0) +
      (secondDifference.overflow ? 1 : 0)
    return (borrow, secondDifference.partialValue)
  }
}

//===--- BigInt -----------------------------------------------------------===//
//===----------------------------------------------------------------------===//

/// A dynamically-sized signed integer.
///
/// The `_BigInt` type is fully generic on the size of its "word" -- the
/// `BigInt` alias uses the system's word-sized `UInt` as its word type, but
/// any word size should work properly.
public struct _BigInt<Word: FixedWidthInteger & UnsignedInteger> :
  BinaryInteger, SignedInteger, CustomStringConvertible,
  CustomDebugStringConvertible
  where Word.Magnitude == Word
{

  /// The binary representation of the value's magnitude, with the least
  /// significant word at index `0`.
  ///
  /// - `_data` has no trailing zero elements
  /// - If `self == 0`, then `isNegative == false` and `_data == []`
  internal var _data: [Word] = []

  /// A Boolean value indicating whether this instance is negative.
  public private(set) var isNegative = false

  /// A Boolean value indicating whether this instance is equal to zero.
  public var isZero: Bool {
    return _data.isEmpty
  }

  //===--- Numeric initializers -------------------------------------------===//

  /// Creates a new instance equal to zero.
  public init() { }

  /// Creates a new instance using `_data` as the data collection.
  init<C: Collection>(_ _data: C) where C.Iterator.Element == Word {
    self._data = Array(_data)
    _standardize()
  }

  public init(integerLiteral value: Int) {
    self.init(value)
  }

  public init<T : BinaryInteger>(_ source: T) {
    var source = source
    if source < 0 as T {
      if source.bitWidth <= UInt64.bitWidth {
        let sourceMag = Int(truncatingIfNeeded: source).magnitude
        self = _BigInt(sourceMag)
        self.isNegative = true
        return
      } else {
        // Have to kind of assume that we're working with another BigInt here
        self.isNegative = true
        source *= -1
      }
    }

    // FIXME: This is broken on 32-bit arch w/ Word = UInt64
    let wordRatio = UInt.bitWidth / Word.bitWidth
    assert(wordRatio != 0)
    for var sourceWord in source.words {
      for _ in 0..<wordRatio {
        _data.append(Word(truncatingIfNeeded: sourceWord))
        sourceWord >>= Word.bitWidth
      }
    }
    _standardize()
  }

  public init?<T : BinaryInteger>(exactly source: T) {
    self.init(source)
  }

  public init<T : BinaryInteger>(truncatingIfNeeded source: T) {
    self.init(source)
  }

  public init<T : BinaryInteger>(clamping source: T) {
    self.init(source)
  }

  public init<T : BinaryFloatingPoint>(_ source: T) {
    fatalError("Not implemented")
  }

  public init?<T : BinaryFloatingPoint>(exactly source: T) {
    fatalError("Not implemented")
  }

  /// Returns a randomly-generated word.
  static func _randomWord() -> Word {
    // This handles up to a 64-bit word
    if Word.bitWidth > UInt32.bitWidth {
      return Word(UInt32.random(in: 0...UInt32.max)) << 32 | Word(UInt32.random(in: 0...UInt32.max))
    } else {
      return Word(truncatingIfNeeded: UInt32.random(in: 0...UInt32.max))
    }
  }

  /// Creates a new instance whose magnitude has `randomBits` bits of random
  /// data. The sign of the new value is randomly selected.
  public init(randomBits: Int) {
    let (words, extraBits) =
      randomBits.quotientAndRemainder(dividingBy: Word.bitWidth)

    // Get the bits for any full words.
    self._data = (0..<words).map({ _ in _BigInt._randomWord() })

    // Get another random number - the highest bit will determine the sign,
    // while the lower `Word.bitWidth - 1` bits are available for any leftover
    // bits in `randomBits`.
    let word = _BigInt._randomWord()
    if extraBits != 0 {
      let mask = ~((~0 as Word) << Word(extraBits))
      _data.append(word & mask)
    }
    isNegative = word & ~(~0 >> 1) == 0

    _standardize()
  }

  //===--- Private methods ------------------------------------------------===//

  /// Standardizes this instance after mutation, removing trailing zeros
  /// and making sure zero is nonnegative. Calling this method satisfies the
  /// two invariants.
  mutating func _standardize(source: String = #function) {
    defer { _checkInvariants(source: source + " >> _standardize()") }
    while _data.last == 0 {
      _data.removeLast()
    }
    // Zero is never negative.
    isNegative = isNegative && _data.count != 0
  }

  /// Checks and asserts on invariants -- all invariants must be satisfied
  /// at the end of every mutating method.
  ///
  /// - `_data` has no trailing zero elements
  /// - If `self == 0`, then `isNegative == false`
  func _checkInvariants(source: String = #function) {
    if _data.isEmpty {
      assert(isNegative == false,
        "\(source): isNegative with zero length _data")
    }
    assert(_data.last != 0, "\(source): extra zeroes on _data")
  }

  //===--- Word-based arithmetic ------------------------------------------===//

  mutating func _unsignedAdd(_ rhs: Word) {
    defer { _standardize() }

    // Quick return if `rhs == 0`
    guard rhs != 0 else { return }

    // Quick return if `self == 0`
    if isZero {
      _data.append(rhs)
      return
    }

    // Add `rhs` to the first word, catching any carry.
    var carry: Word
    (carry, _data[0]) = _data[0].addingFullWidth(rhs)

    // Handle any additional carries
    for i in 1..<_data.count {
      // No more action needed if there's nothing to carry
      if carry == 0 { break }
      (carry, _data[i]) = _data[i].addingFullWidth(carry)
    }

    // If there's any carry left, add it now
    if carry != 0 {
      _data.append(1)
    }
  }

  /// Subtracts `rhs` from this instance, ignoring the sign.
  ///
  /// - Precondition: `rhs <= self.magnitude`
  mutating func _unsignedSubtract(_ rhs: Word) {
    precondition(_data.count > 1 || _data[0] > rhs)

    // Quick return if `rhs == 0`
    guard rhs != 0 else { return }

    // If `isZero == true`, then `rhs` must also be zero.
    precondition(!isZero)

    var carry: Word
    (carry, _data[0]) = _data[0].subtractingWithBorrow(rhs)

    for i in 1..<_data.count {
      // No more action needed if there's nothing to carry
      if carry == 0 { break }
      (carry, _data[i]) = _data[i].subtractingWithBorrow(carry)
    }
    assert(carry == 0)

    _standardize()
  }

  /// Adds `rhs` to this instance.
  mutating func add(_ rhs: Word) {
    if isNegative {
      // If _data only contains one word and `rhs` is greater, swap them,
      // make self positive and continue with unsigned subtraction.
      var rhs = rhs
      if _data.count == 1 && _data[0] < rhs {
        swap(&rhs, &_data[0])
        isNegative = false
      }
      _unsignedSubtract(rhs)
    } else {   // positive or zero
      _unsignedAdd(rhs)
    }
  }

  /// Subtracts `rhs` from this instance.
  mutating func subtract(_ rhs: Word) {
    guard rhs != 0 else { return }

    if isNegative {
      _unsignedAdd(rhs)
    } else if isZero {
      isNegative = true
      _data.append(rhs)
    } else {
      var rhs = rhs
      if _data.count == 1 && _data[0] < rhs {
        swap(&rhs, &_data[0])
        isNegative = true
      }
      _unsignedSubtract(rhs)
    }
  }

  /// Multiplies this instance by `rhs`.
  mutating func multiply(by rhs: Word) {
    // If either `self` or `rhs` is zero, the result is zero.
    guard !isZero && rhs != 0 else {
      self = 0
      return
    }

    // If `rhs` is a power of two, can just left shift `self`.
    let rhsLSB = rhs.trailingZeroBitCount
    if rhs >> rhsLSB == 1 {
      self <<= rhsLSB
      return
    }

    var carry: Word = 0
    for i in 0..<_data.count {
      let product = _data[i].multipliedFullWidth(by: rhs)
      (carry, _data[i]) = product.low.addingFullWidth(carry)
      carry = carry &+ product.high
    }

    // Add the leftover carry
    if carry != 0 {
      _data.append(carry)
    }
    _standardize()
  }

  /// Divides this instance by `rhs`, returning the remainder.
  @discardableResult
  mutating func divide(by rhs: Word) -> Word {
    precondition(rhs != 0, "divide by zero")

    // No-op if `rhs == 1` or `self == 0`.
    if rhs == 1 || isZero {
      return 0
    }

    // If `rhs` is a power of two, can just right shift `self`.
    let rhsLSB = rhs.trailingZeroBitCount
    if rhs >> rhsLSB == 1 {
      defer { self >>= rhsLSB }
      return _data[0] & ~(~0 << rhsLSB)
    }

    var carry: Word = 0
    for i in (0..<_data.count).reversed() {
      let lhs = (high: carry, low: _data[i])
      (_data[i], carry) = rhs.dividingFullWidth(lhs)
    }

    _standardize()
    return carry
  }

  //===--- Numeric --------------------------------------------------------===//

  public typealias Magnitude = _BigInt

  public var magnitude: _BigInt {
    var result = self
    result.isNegative = false
    return result
  }

  /// Adds `rhs` to this instance, ignoring any signs.
  mutating func _unsignedAdd(_ rhs: _BigInt) {
    defer { _checkInvariants() }

    let commonCount = Swift.min(_data.count, rhs._data.count)
    let maxCount = Swift.max(_data.count, rhs._data.count)
    _data.reserveCapacity(maxCount)

    // Add the words up to the common count, carrying any overflows
    var carry: Word = 0
    for i in 0..<commonCount {
      (carry, _data[i]) = Word.addingFullWidth(_data[i], rhs._data[i], carry)
    }

    // If there are leftover words in `self`, just need to handle any carries
    if _data.count > rhs._data.count {
      for i in commonCount..<maxCount {
        // No more action needed if there's nothing to carry
        if carry == 0 { break }
        (carry, _data[i]) = _data[i].addingFullWidth(carry)
      }

    // If there are leftover words in `rhs`, need to copy to `self` with carries
    } else if _data.count < rhs._data.count {
      for i in commonCount..<maxCount {
        // Append remaining words if nothing to carry
        if carry == 0 {
          _data.append(contentsOf: rhs._data.suffix(from: i))
          break
        }
        let sum: Word
        (carry, sum) = rhs._data[i].addingFullWidth(carry)
        _data.append(sum)
      }
    }

    // If there's any carry left, add it now
    if carry != 0 {
      _data.append(1)
    }
  }

  /// Subtracts `rhs` from this instance, ignoring the sign.
  ///
  /// - Precondition: `rhs.magnitude <= self.magnitude` (unchecked)
  /// - Precondition: `rhs._data.count <= self._data.count`
  mutating func _unsignedSubtract(_ rhs: _BigInt) {
    precondition(rhs._data.count <= _data.count)

    var carry: Word = 0
    for i in 0..<rhs._data.count {
      (carry, _data[i]) = _data[i].subtractingWithBorrow(rhs._data[i], carry)
    }

    for i in rhs._data.count..<_data.count {
      // No more action needed if there's nothing to carry
      if carry == 0 { break }
      (carry, _data[i]) = _data[i].subtractingWithBorrow(carry)
    }
    assert(carry == 0)

    _standardize()
  }

  public static func +=(lhs: inout _BigInt, rhs: _BigInt) {
    defer { lhs._checkInvariants() }
    if lhs.isNegative == rhs.isNegative {
      lhs._unsignedAdd(rhs)
    } else {
      lhs -= -rhs
    }
  }

  public static func -=(lhs: inout _BigInt, rhs: _BigInt) {
    defer { lhs._checkInvariants() }

    // Subtracting something of the opposite sign just adds magnitude.
    guard lhs.isNegative == rhs.isNegative else {
      lhs._unsignedAdd(rhs)
      return
    }

    // Comare `lhs` and `rhs` so we can use `_unsignedSubtract` to subtract
    // the smaller magnitude from the larger magnitude.
    switch lhs._compareMagnitude(to: rhs) {
    case .equal:
      lhs = 0
    case .greaterThan:
      lhs._unsignedSubtract(rhs)
    case .lessThan:
      // x - y == -y + x == -(y - x)
      var result = rhs
      result._unsignedSubtract(lhs)
      result.isNegative = !lhs.isNegative
      lhs = result
    }
  }

  public static func *=(lhs: inout _BigInt, rhs: _BigInt) {
    // If either `lhs` or `rhs` is zero, the result is zero.
    guard !lhs.isZero && !rhs.isZero else {
      lhs = 0
      return
    }

    var newData: [Word] = Array(repeating: 0,
      count: lhs._data.count + rhs._data.count)
    let (a, b) = lhs._data.count > rhs._data.count
      ? (lhs._data, rhs._data)
      : (rhs._data, lhs._data)
    assert(a.count >= b.count)

    var carry: Word = 0
    for ai in 0..<a.count {
      carry = 0
      for bi in 0..<b.count {
        // Each iteration needs to perform this operation:
        //
        //     newData[ai + bi] += (a[ai] * b[bi]) + carry
        //
        // However, `a[ai] * b[bi]` produces a double-width result, and both
        // additions can overflow to a higher word. The following two lines
        // capture the low word of the multiplication and additions in
        // `newData[ai + bi]` and any addition overflow in `carry`.
        let product = a[ai].multipliedFullWidth(by: b[bi])
        (carry, newData[ai + bi]) = Word.addingFullWidth(
          newData[ai + bi], product.low, carry)

        // Now we combine the high word of the multiplication with any addition
        // overflow. It is safe to add `product.high` and `carry` here without
        // checking for overflow, because if `product.high == .max - 1`, then
        // `carry <= 1`. Otherwise, `carry <= 2`.
        //
        // Worst-case (aka 9 + 9*9 + 9):
        //
        //       newData         a[ai]        b[bi]         carry
        //      0b11111111 + (0b11111111 * 0b11111111) + 0b11111111
        //      0b11111111 + (0b11111110_____00000001) + 0b11111111
        //                   (0b11111111_____00000000) + 0b11111111
        //                   (0b11111111_____11111111)
        //
        // Second-worse case:
        //
        //      0b11111111 + (0b11111111 * 0b11111110) + 0b11111111
        //      0b11111111 + (0b11111101_____00000010) + 0b11111111
        //                   (0b11111110_____00000001) + 0b11111111
        //                   (0b11111111_____00000000)
        assert(!product.high.addingReportingOverflow(carry).overflow)
        carry = product.high &+ carry
      }

      // Leftover `carry` is inserted in new highest word.
      assert(newData[ai + b.count] == 0)
      newData[ai + b.count] = carry
    }

    lhs._data = newData
    lhs.isNegative = lhs.isNegative != rhs.isNegative
    lhs._standardize()
  }

  /// Divides this instance by `rhs`, returning the remainder.
  @discardableResult
  mutating func _internalDivide(by rhs: _BigInt) -> _BigInt {
    precondition(!rhs.isZero, "Divided by zero")
    defer { _checkInvariants() }

    // Handle quick cases that don't require division:
    // If `abs(self) < abs(rhs)`, the result is zero, remainder = self
    // If `abs(self) == abs(rhs)`, the result is 1 or -1, remainder = 0
    switch _compareMagnitude(to: rhs) {
    case .lessThan:
      defer { self = 0 }
      return self
    case .equal:
      self = isNegative != rhs.isNegative ? -1 : 1
      return 0
    default:
      break
    }

    var tempSelf = self.magnitude
    let n = tempSelf.bitWidth - rhs.magnitude.bitWidth
    var quotient: _BigInt = 0
    var tempRHS = rhs.magnitude << n
    var tempQuotient: _BigInt = 1 << n

    for _ in (0...n).reversed() {
      if tempRHS._compareMagnitude(to: tempSelf) != .greaterThan {
        tempSelf -= tempRHS
        quotient += tempQuotient
      }
      tempRHS >>= 1
      tempQuotient >>= 1
    }

    // `tempSelf` is the remainder - match sign of original `self`
    tempSelf.isNegative = self.isNegative
    tempSelf._standardize()

    quotient.isNegative = isNegative != rhs.isNegative
    self = quotient
    _standardize()

    return tempSelf
  }

  public static func /=(lhs: inout _BigInt, rhs: _BigInt) {
    lhs._internalDivide(by: rhs)
  }

  // FIXME: Remove once default implementations are provided:

  public static func +(_ lhs: _BigInt, _ rhs: _BigInt) -> _BigInt {
    var lhs = lhs
    lhs += rhs
    return lhs
  }

  public static func -(_ lhs: _BigInt, _ rhs: _BigInt) -> _BigInt {
    var lhs = lhs
    lhs -= rhs
    return lhs
  }

  public static func *(_ lhs: _BigInt, _ rhs: _BigInt) -> _BigInt {
    var lhs = lhs
    lhs *= rhs
    return lhs
  }

  public static func /(_ lhs: _BigInt, _ rhs: _BigInt) -> _BigInt {
    var lhs = lhs
    lhs /= rhs
    return lhs
  }

  public static func %(_ lhs: _BigInt, _ rhs: _BigInt) -> _BigInt {
    var lhs = lhs
    lhs %= rhs
    return lhs
  }

  //===--- BinaryInteger --------------------------------------------------===//

  /// Creates a new instance using the given data array in two's complement
  /// representation.
  init(_twosComplementData: [Word]) {
    guard _twosComplementData.count > 0 else {
      self = 0
      return
    }

    // Is the highest bit set?
    isNegative = _twosComplementData.last!.leadingZeroBitCount == 0
    if isNegative {
      _data = _twosComplementData.map(~)
      self._unsignedAdd(1 as Word)
    } else {
      _data = _twosComplementData
    }
    _standardize()
  }

  /// Returns an array of the value's data using two's complement representation.
  func _dataAsTwosComplement() -> [Word] {
    // Special cases:
    // * Nonnegative values are already in 2's complement
    if !isNegative {
      // Positive values need to have a leading zero bit
      if _data.last?.leadingZeroBitCount == 0 {
        return _data + [0]
      } else {
        return _data
      }
    }
    // * -1 will get zeroed out below, easier to handle here
    if _data.count == 1 && _data.first == 1 { return [~0] }

    var x = self
    x._unsignedSubtract(1 as Word)

    if x._data.last!.leadingZeroBitCount == 0 {
      // The highest bit is set to 1, which moves to 0 after negation.
      // We need to add another word at the high end so the highest bit is 1.
      return x._data.map(~) + [Word.max]
    } else {
      // The highest bit is set to 0, which moves to 1 after negation.
      return x._data.map(~)
    }
  }

  public var words: [UInt] {
    assert(UInt.bitWidth % Word.bitWidth == 0)
    let twosComplementData = _dataAsTwosComplement()
    var words: [UInt] = []
    words.reserveCapacity((twosComplementData.count * Word.bitWidth
      + UInt.bitWidth - 1) / UInt.bitWidth)
    var word: UInt = 0
    var shift = 0
    for w in twosComplementData {
      word |= UInt(truncatingIfNeeded: w) << shift
      shift += Word.bitWidth
      if shift == UInt.bitWidth {
        words.append(word)
        word = 0
        shift = 0
      }
    }
    if shift != 0 {
      if isNegative {
        word |= ~((1 << shift) - 1)
      }
      words.append(word)
    }
    return words
  }

  /// The number of bits used for storage of this value. Always a multiple of
  /// `Word.bitWidth`.
  public var bitWidth: Int {
    if isZero {
      return 0
    } else {
      let twosComplementData = _dataAsTwosComplement()

      // If negative, it's okay to have 1s padded on high end
      if isNegative {
        return twosComplementData.count * Word.bitWidth
      }

      // If positive, need to make space for at least one zero on high end
      return twosComplementData.count * Word.bitWidth
        - twosComplementData.last!.leadingZeroBitCount + 1
    }
  }

  /// The number of sequential zeros in the least-significant position of this
  /// value's binary representation.
  ///
  /// The numbers 1 and zero have zero trailing zeros.
  public var trailingZeroBitCount: Int {
    guard !isZero else {
      return 0
    }

    let i = _data.firstIndex(where: { $0 != 0 })!
    assert(_data[i] != 0)
    return i * Word.bitWidth + _data[i].trailingZeroBitCount
  }

  public static func %=(lhs: inout _BigInt, rhs: _BigInt) {
    defer { lhs._checkInvariants() }
    lhs = lhs._internalDivide(by: rhs)
  }

  public func quotientAndRemainder(dividingBy rhs: _BigInt) ->
    (_BigInt, _BigInt)
  {
    var x = self
    let r = x._internalDivide(by: rhs)
    return (x, r)
  }

  public static func &=(lhs: inout _BigInt, rhs: _BigInt) {
    var lhsTemp = lhs._dataAsTwosComplement()
    let rhsTemp = rhs._dataAsTwosComplement()

    // If `lhs` is longer than `rhs`, behavior depends on sign of `rhs`
    // * If `rhs < 0`, length is extended with 1s
    // * If `rhs >= 0`, length is extended with 0s, which crops `lhsTemp`
    if lhsTemp.count > rhsTemp.count && !rhs.isNegative {
      lhsTemp.removeLast(lhsTemp.count - rhsTemp.count)
    }

    // If `rhs` is longer than `lhs`, behavior depends on sign of `lhs`
    // * If `lhs < 0`, length is extended with 1s, so `lhs` should get extra
    //   bits from `rhs`
    // * If `lhs >= 0`, length is extended with 0s
    if lhsTemp.count < rhsTemp.count && lhs.isNegative {
      lhsTemp.append(contentsOf: rhsTemp[lhsTemp.count..<rhsTemp.count])
    }

    // Perform bitwise & on words that both `lhs` and `rhs` have.
    for i in 0..<Swift.min(lhsTemp.count, rhsTemp.count) {
      lhsTemp[i] &= rhsTemp[i]
    }

    lhs = _BigInt(_twosComplementData: lhsTemp)
  }

  public static func |=(lhs: inout _BigInt, rhs: _BigInt) {
    var lhsTemp = lhs._dataAsTwosComplement()
    let rhsTemp = rhs._dataAsTwosComplement()

    // If `lhs` is longer than `rhs`, behavior depends on sign of `rhs`
    // * If `rhs < 0`, length is extended with 1s, so those bits of `lhs`
    //   should all be 1
    // * If `rhs >= 0`, length is extended with 0s, which is a no-op
    if lhsTemp.count > rhsTemp.count && rhs.isNegative {
      lhsTemp.replaceSubrange(rhsTemp.count..<lhsTemp.count,
        with: repeatElement(Word.max, count: lhsTemp.count - rhsTemp.count))
    }

    // If `rhs` is longer than `lhs`, behavior depends on sign of `lhs`
    // * If `lhs < 0`, length is extended with 1s, so those bits of lhs
    //   should all be 1
    // * If `lhs >= 0`, length is extended with 0s, so those bits should be
    //   copied from rhs
    if lhsTemp.count < rhsTemp.count {
      if lhs.isNegative {
        lhsTemp.append(contentsOf:
          repeatElement(Word.max, count: rhsTemp.count - lhsTemp.count))
      } else {
        lhsTemp.append(contentsOf: rhsTemp[lhsTemp.count..<rhsTemp.count])
      }
    }

    // Perform bitwise | on words that both `lhs` and `rhs` have.
    for i in 0..<Swift.min(lhsTemp.count, rhsTemp.count) {
      lhsTemp[i] |= rhsTemp[i]
    }

    lhs = _BigInt(_twosComplementData: lhsTemp)
  }

  public static func ^=(lhs: inout _BigInt, rhs: _BigInt) {
    var lhsTemp = lhs._dataAsTwosComplement()
    let rhsTemp = rhs._dataAsTwosComplement()

    // If `lhs` is longer than `rhs`, behavior depends on sign of `rhs`
    // * If `rhs < 0`, length is extended with 1s, so those bits of `lhs`
    //   should all be flipped
    // * If `rhs >= 0`, length is extended with 0s, which is a no-op
    if lhsTemp.count > rhsTemp.count && rhs.isNegative {
      for i in rhsTemp.count..<lhsTemp.count {
        lhsTemp[i] = ~lhsTemp[i]
      }
    }

    // If `rhs` is longer than `lhs`, behavior depends on sign of `lhs`
    // * If `lhs < 0`, length is extended with 1s, so those bits of `lhs`
    //   should all be flipped copies of `rhs`
    // * If `lhs >= 0`, length is extended with 0s, so those bits should
    //   be copied from rhs
    if lhsTemp.count < rhsTemp.count {
      if lhs.isNegative {
        lhsTemp += rhsTemp.suffix(from: lhsTemp.count).map(~)
      } else {
        lhsTemp.append(contentsOf: rhsTemp[lhsTemp.count..<rhsTemp.count])
      }
    }

    // Perform bitwise ^ on words that both `lhs` and `rhs` have.
    for i in 0..<Swift.min(lhsTemp.count, rhsTemp.count) {
      lhsTemp[i] ^= rhsTemp[i]
    }

    lhs = _BigInt(_twosComplementData: lhsTemp)
  }

  public static prefix func ~(x: _BigInt) -> _BigInt {
    return -x - 1
  }

  //===--- SignedNumeric --------------------------------------------------===//

  public static prefix func -(x: inout _BigInt) {
    defer { x._checkInvariants() }
    guard x._data.count > 0 else { return }
    x.isNegative = !x.isNegative
  }

  //===--- Strideable -----------------------------------------------------===//

  public func distance(to other: _BigInt) -> _BigInt {
    return other - self
  }

  public func advanced(by n: _BigInt) -> _BigInt {
    return self + n
  }

  //===--- Other arithmetic -----------------------------------------------===//

  /// Returns the greatest common divisor for this value and `other`.
  public func greatestCommonDivisor(with other: _BigInt) -> _BigInt {
    // Quick return if either is zero
    if other.isZero {
      return magnitude
    }
    if isZero {
      return other.magnitude
    }

    var (x, y) = (self.magnitude, other.magnitude)
    let (xLSB, yLSB) = (x.trailingZeroBitCount, y.trailingZeroBitCount)

    // Remove any common factor of two
    let commonPower = Swift.min(xLSB, yLSB)
    x >>= commonPower
    y >>= commonPower

    // Remove any remaining factor of two
    if xLSB != commonPower {
      x >>= xLSB - commonPower
    }
    if yLSB != commonPower {
      y >>= yLSB - commonPower
    }

    while !x.isZero {
      // Swap values to ensure that `x >= y`.
      if x._compareMagnitude(to: y) == .lessThan {
        swap(&x, &y)
      }

      // Subtract smaller and remove any factors of two
      x._unsignedSubtract(y)
      x >>= x.trailingZeroBitCount
    }

    // Add original common factor of two back into result
    y <<= commonPower
    return y
  }

  /// Returns the lowest common multiple for this value and `other`.
  public func lowestCommonMultiple(with other: _BigInt) -> _BigInt {
    let gcd = greatestCommonDivisor(with: other)
    if _compareMagnitude(to: other) == .lessThan {
      return ((self / gcd) * other).magnitude
    } else {
      return ((other / gcd) * self).magnitude
    }
  }

  //===--- String methods ------------------------------------------------===//

  /// Creates a new instance from the given string.
  ///
  /// - Parameters:
  ///   - source: The string to parse for the new instance's value. If a
  ///     character in `source` is not in the range `0...9` or `a...z`, case
  ///     insensitive, or is not less than `radix`, the result is `nil`.
  ///   - radix: The radix to use when parsing `source`. `radix` must be in the
  ///     range `2...36`. The default is `10`.
  public init?(_ source: String, radix: Int = 10) {
    assert(2...36 ~= radix, "radix must be in range 2...36")
    let radix = Word(radix)

    func valueForCodeUnit(_ unit: Unicode.UTF16.CodeUnit) -> Word? {
      switch unit {
      // "0"..."9"
      case 48...57: return Word(unit - 48)
      // "a"..."z"
      case 97...122: return Word(unit - 87)
      // "A"..."Z"
      case 65...90: return Word(unit - 55)
      // invalid character
      default: return nil
      }
    }

    var source = source

    // Check for a single prefixing hyphen
    let negative = source.hasPrefix("-")
    if negative {
      source = String(source.dropFirst())
    }

    // Loop through characters, multiplying
    for v in source.utf16.map(valueForCodeUnit) {
      // Character must be valid and less than radix
      guard let v = v else { return nil }
      guard v < radix else { return nil }

      self.multiply(by: radix)
      self.add(v)
    }

    self.isNegative = negative
  }

  /// Returns a string representation of this instance.
  ///
  /// - Parameters:
  ///   - radix: The radix to use when converting this instance to a string.
  ///     The value passed as `radix` must be in the range `2...36`. The
  ///     default is `10`.
  ///   - lowercase: Whether to use lowercase letters to represent digits
  ///     greater than 10. The default is `true`.
  public func toString(radix: Int = 10, lowercase: Bool = true) -> String {
    assert(2...36 ~= radix, "radix must be in range 2...36")

    let digitsStart = ("0" as Unicode.Scalar).value
    let lettersStart = ((lowercase ? "a" : "A") as Unicode.Scalar).value - 10
    func toLetter(_ x: UInt32) -> Unicode.Scalar {
      return x < 10
        ? Unicode.Scalar(digitsStart + x)!
        : Unicode.Scalar(lettersStart + x)!
    }

    let radix = _BigInt(radix)
    var result: [Unicode.Scalar] = []

    var x = self.magnitude
    while !x.isZero {
      let remainder: _BigInt
      (x, remainder) = x.quotientAndRemainder(dividingBy: radix)
      result.append(toLetter(UInt32(remainder)))
    }

    let sign = isNegative ? "-" : ""
    let rest = result.count == 0
      ? "0"
      : String(String.UnicodeScalarView(result.reversed()))
    return sign + rest
  }

  public var description: String {
    return decimalString
  }

  public var debugDescription: String {
    return "_BigInt(\(hexString), words: \(_data.count))"
  }

  /// A string representation of this instance's value in base 2.
  public var binaryString: String {
    return toString(radix: 2)
  }

  /// A string representation of this instance's value in base 10.
  public var decimalString: String {
    return toString(radix: 10)
  }

  /// A string representation of this instance's value in base 16.
  public var hexString: String {
    return toString(radix: 16, lowercase: false)
  }

  /// A string representation of this instance's value in base 36.
  public var compactString: String {
    return toString(radix: 36, lowercase: false)
  }

  //===--- Comparable -----------------------------------------------------===//

  enum _ComparisonResult {
    case lessThan, equal, greaterThan
  }

  /// Returns whether this instance is less than, greather than, or equal to
  /// the given value.
  func _compare(to rhs: _BigInt) -> _ComparisonResult {
    // Negative values are less than positive values
    guard isNegative == rhs.isNegative else {
      return isNegative ? .lessThan : .greaterThan
    }

    switch _compareMagnitude(to: rhs) {
    case .equal:
      return .equal
    case .lessThan:
      return isNegative ? .greaterThan : .lessThan
    case .greaterThan:
      return isNegative ? .lessThan : .greaterThan
    }
  }

  /// Returns whether the magnitude of this instance is less than, greather
  /// than, or equal to the magnitude of the given value.
  func _compareMagnitude(to rhs: _BigInt) -> _ComparisonResult {
    guard _data.count == rhs._data.count else {
      return _data.count < rhs._data.count ? .lessThan : .greaterThan
    }

    // Equal number of words: compare from most significant word
    for i in (0..<_data.count).reversed() {
      if _data[i] < rhs._data[i] { return .lessThan }
      if _data[i] > rhs._data[i] { return .greaterThan }
    }
    return .equal
  }

  public static func ==(lhs: _BigInt, rhs: _BigInt) -> Bool {
    return lhs._compare(to: rhs) == .equal
  }

  public static func < (lhs: _BigInt, rhs: _BigInt) -> Bool {
    return lhs._compare(to: rhs) == .lessThan
  }

  //===--- Hashable -------------------------------------------------------===//

  public func hash(into hasher: inout Hasher) {
    hasher.combine(isNegative)
    hasher.combine(_data)
  }

  //===--- Bit shifting operators -----------------------------------------===//

  static func _shiftLeft(_ data: inout [Word], byWords words: Int) {
    guard words > 0 else { return }
    data.insert(contentsOf: repeatElement(0, count: words), at: 0)
  }

  static func _shiftRight(_ data: inout [Word], byWords words: Int) {
    guard words > 0 else { return }
    data.removeFirst(Swift.min(data.count, words))
  }

  public static func <<= <RHS : BinaryInteger>(lhs: inout _BigInt, rhs: RHS) {
    defer { lhs._checkInvariants() }
    guard rhs != 0 else { return }
    guard rhs > 0 else {
      lhs >>= 0 - rhs
      return
    }

    let wordWidth = RHS(Word.bitWidth)
    
    // We can add `rhs / bits` extra words full of zero at the low end.
    let extraWords = Int(rhs / wordWidth)
    lhs._data.reserveCapacity(lhs._data.count + extraWords + 1)
    _BigInt._shiftLeft(&lhs._data, byWords: extraWords)

    // Each existing word will need to be shifted left by `rhs % bits`.
    // For each pair of words, we'll use the high `offset` bits of the
    // lower word and the low `Word.bitWidth - offset` bits of the higher
    // word.
    let highOffset = Int(rhs % wordWidth)
    let lowOffset = Word.bitWidth - highOffset

    // If there's no offset, we're finished, as `rhs` was a multiple of
    // `Word.bitWidth`.
    guard highOffset != 0 else { return }

    // Add new word at the end, then shift everything left by `offset` bits.
    lhs._data.append(0)
    for i in ((extraWords + 1)..<lhs._data.count).reversed() {
      lhs._data[i] = lhs._data[i] << highOffset
        | lhs._data[i - 1] >> lowOffset
    }

    // Finally, shift the lowest word.
    lhs._data[extraWords] = lhs._data[extraWords] << highOffset
    lhs._standardize()
  }

  public static func >>= <RHS : BinaryInteger>(lhs: inout _BigInt, rhs: RHS) {
    defer { lhs._checkInvariants() }
    guard rhs != 0 else { return }
    guard rhs > 0 else {
      lhs <<= 0 - rhs
      return
    }

    var tempData = lhs._dataAsTwosComplement()

    let wordWidth = RHS(Word.bitWidth)
    // We can remove `rhs / bits` full words at the low end.
    // If that removes the entirety of `_data`, we're done.
    let wordsToRemove = Int(rhs / wordWidth)
    _BigInt._shiftRight(&tempData, byWords: wordsToRemove)
    guard tempData.count != 0 else {
      lhs = lhs.isNegative ? -1 : 0
      return
    }

    // Each existing word will need to be shifted right by `rhs % bits`.
    // For each pair of words, we'll use the low `offset` bits of the
    // higher word and the high `_BigInt.Word.bitWidth - offset` bits of
    // the lower word.
    let lowOffset = Int(rhs % wordWidth)
    let highOffset = Word.bitWidth - lowOffset

    // If there's no offset, we're finished, as `rhs` was a multiple of
    // `Word.bitWidth`.
    guard lowOffset != 0 else {
      lhs = _BigInt(_twosComplementData: tempData)
      return
    }

    // Shift everything right by `offset` bits.
    for i in 0..<(tempData.count - 1) {
      tempData[i] = tempData[i] >> lowOffset |
        tempData[i + 1] << highOffset
    }

    // Finally, shift the highest word and standardize the result.
    tempData[tempData.count - 1] >>= lowOffset
    lhs = _BigInt(_twosComplementData: tempData)
  }
}

//===--- Bit --------------------------------------------------------------===//
//===----------------------------------------------------------------------===//

/// A one-bit fixed width integer.
struct Bit : FixedWidthInteger, UnsignedInteger {
  typealias Magnitude = Bit

  var value: UInt8 = 0

  // Initializers

  init(integerLiteral value: Int) {
    self = Bit(value)
  }

  init(bigEndian value: Bit) {
    self = value
  }

  init(littleEndian value: Bit) {
    self = value
  }

  init?<T: BinaryFloatingPoint>(exactly source: T) {
    switch source {
    case T(0): value = 0
    case T(1): value = 1
    default:
      return nil
    }
  }

  init<T: BinaryFloatingPoint>(_ source: T) {
    self = Bit(exactly: source.rounded(.down))!
  }

  init<T: BinaryInteger>(_ source: T) {
    switch source {
    case 0: value = 0
    case 1: value = 1
    default:
      fatalError("Can't represent \(source) as a Bit")
    }
  }

  init<T: BinaryInteger>(truncatingIfNeeded source: T) {
    value = UInt8(source & 1)
  }

  init(_truncatingBits bits: UInt) {
    value = UInt8(bits & 1)
  }

  init<T: BinaryInteger>(clamping source: T)  {
    value = source >= 1 ? 1 : 0
  }

  // FixedWidthInteger, BinaryInteger

  static var bitWidth: Int {
    return 1
  }

  var bitWidth: Int {
    return 1
  }

  var trailingZeroBitCount: Int {
    return Int(~value & 1)
  }

  static var max: Bit {
    return 1
  }

  static var min: Bit {
    return 0
  }

  static var isSigned: Bool {
    return false
  }

  var nonzeroBitCount: Int {
    return value.nonzeroBitCount
  }

  var leadingZeroBitCount: Int {
    return Int(~value & 1)
  }

  var bigEndian: Bit {
    return self
  }

  var littleEndian: Bit {
    return self
  }

  var byteSwapped: Bit {
    return self
  }

  var words: UInt.Words {
    return UInt(value).words
  }

  // Hashable, CustomStringConvertible

  func hash(into hasher: inout Hasher) {
    hasher.combine(value)
  }

  var description: String {
    return "\(value)"
  }

  // Arithmetic Operations / Operators

  func _checkOverflow(_ v: UInt8) -> Bool {
    let mask: UInt8 = ~0 << 1
    return v & mask != 0
  }
  
  func addingReportingOverflow(_ rhs: Bit) ->
    (partialValue: Bit, overflow: Bool) {
      let result = value &+ rhs.value
      return (Bit(result & 1), _checkOverflow(result))
  }

  func subtractingReportingOverflow(_ rhs: Bit) ->
    (partialValue: Bit, overflow: Bool) {
      let result = value &- rhs.value
      return (Bit(result & 1), _checkOverflow(result))
  }

  func multipliedReportingOverflow(by rhs: Bit) ->
    (partialValue: Bit, overflow: Bool) {
      let result = value &* rhs.value
      return (Bit(result), false)
  }

  func dividedReportingOverflow(by rhs: Bit) ->
    (partialValue: Bit, overflow: Bool) {
      return (self, rhs != 0)
  }

  func remainderReportingOverflow(dividingBy rhs: Bit) ->
    (partialValue: Bit, overflow: Bool) {
      fatalError()
  }

  static func +=(lhs: inout Bit, rhs: Bit) {
    let result = lhs.addingReportingOverflow(rhs)
    assert(!result.overflow, "Addition overflow")
    lhs = result.partialValue
  }

  static func -=(lhs: inout Bit, rhs: Bit) {
    let result = lhs.subtractingReportingOverflow(rhs)
    assert(!result.overflow, "Subtraction overflow")
    lhs = result.partialValue
  }

  static func *=(lhs: inout Bit, rhs: Bit) {
    let result = lhs.multipliedReportingOverflow(by: rhs)
    assert(!result.overflow, "Multiplication overflow")
    lhs = result.partialValue
  }

  static func /=(lhs: inout Bit, rhs: Bit) {
    let result = lhs.dividedReportingOverflow(by: rhs)
    assert(!result.overflow, "Division overflow")
    lhs = result.partialValue
  }

  static func %=(lhs: inout Bit, rhs: Bit) {
    assert(rhs != 0, "Modulo sum overflow")
    lhs.value = 0 // No remainders with bit division!
  }

  func multipliedFullWidth(by other: Bit) -> (high: Bit, low: Bit) {
      return (0, self * other)
  }

  func dividingFullWidth(_ dividend: (high: Bit, low: Bit)) ->
    (quotient: Bit, remainder: Bit) {
      assert(self != 0, "Division overflow")
      assert(dividend.high == 0, "Quotient overflow")
      return (dividend.low, 0)
  }

  // FIXME: Remove once default implementations are provided:

  public static func +(_ lhs: Bit, _ rhs: Bit) -> Bit {
    var lhs = lhs
    lhs += rhs
    return lhs
  }

  public static func -(_ lhs: Bit, _ rhs: Bit) -> Bit {
    var lhs = lhs
    lhs -= rhs
    return lhs
  }

  public static func *(_ lhs: Bit, _ rhs: Bit) -> Bit {
    var lhs = lhs
    lhs *= rhs
    return lhs
  }

  public static func /(_ lhs: Bit, _ rhs: Bit) -> Bit {
    var lhs = lhs
    lhs /= rhs
    return lhs
  }

  public static func %(_ lhs: Bit, _ rhs: Bit) -> Bit {
    var lhs = lhs
    lhs %= rhs
    return lhs
  }

  // Bitwise operators

  static prefix func ~(x: Bit) -> Bit {
    return Bit(~x.value & 1)
  }

  // Why doesn't the type checker complain about these being missing?
  static func &=(lhs: inout Bit, rhs: Bit) {
    lhs.value &= rhs.value
  }

  static func |=(lhs: inout Bit, rhs: Bit) {
    lhs.value |= rhs.value
  }

  static func ^=(lhs: inout Bit, rhs: Bit) {
    lhs.value ^= rhs.value
  }

  static func ==(lhs: Bit, rhs: Bit) -> Bool {
    return lhs.value == rhs.value
  }

  static func <(lhs: Bit, rhs: Bit) -> Bool {
    return lhs.value < rhs.value
  }

  static func <<(lhs: Bit, rhs: Bit) -> Bit {
    return rhs == 0 ? lhs : 0
  }

  static func >>(lhs: Bit, rhs: Bit) -> Bit {
    return rhs == 0 ? lhs : 0
  }

  static func <<=(lhs: inout Bit, rhs: Bit) {
    if rhs != 0 {
      lhs = 0
    }
  }

  static func >>=(lhs: inout Bit, rhs: Bit) {
    if rhs != 0 {
      lhs = 0
    }
  }
}

//===--- Tests ------------------------------------------------------------===//
//===----------------------------------------------------------------------===//

typealias BigInt = _BigInt<UInt>
typealias BigInt8 = _BigInt<UInt8>

typealias BigIntBit = _BigInt<Bit>

func testBinaryInit<T: BinaryInteger>(_ x: T) -> BigInt {
  return BigInt(x)
}

func randomBitLength() -> Int {
  return Int.random(in: 2...1000)
}
