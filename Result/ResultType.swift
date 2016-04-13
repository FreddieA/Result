//  Copyright (c) 2015 Rob Rix. All rights reserved.

#if swift(>=3.0)
	public typealias ResultErrorType = ErrorProtocol
#else
	public typealias ResultErrorType = ErrorType
#endif

/// A type that can represent either failure with an error or success with a result value.
public protocol ResultType {
	associatedtype Value
	associatedtype Error: ResultErrorType
	
	/// Constructs a successful result wrapping a `value`.
	init(value: Value)

	/// Constructs a failed result wrapping an `error`.
	init(error: Error)
	
	/// Case analysis for ResultType.
	///
	/// Returns the value produced by appliying `ifFailure` to the error if self represents a failure, or `ifSuccess` to the result value if self represents a success.
#if swift(>=3)
	func analysis<U>(@noescape ifSuccess: Value -> U, @noescape ifFailure: Error -> U) -> U
#else
	func analysis<U>(@noescape ifSuccess ifSuccess: Value -> U, @noescape ifFailure: Error -> U) -> U
#endif

	/// Returns the value if self represents a success, `nil` otherwise.
	///
	/// A default implementation is provided by a protocol extension. Conforming types may specialize it.
	var value: Value? { get }

	/// Returns the error if self represents a failure, `nil` otherwise.
	///
	/// A default implementation is provided by a protocol extension. Conforming types may specialize it.
	var error: Error? { get }
}

public extension ResultType {
	
	/// Returns the value if self represents a success, `nil` otherwise.
	public var value: Value? {
		return analysis(ifSuccess: { $0 }, ifFailure: { _ in nil })
	}
	
	/// Returns the error if self represents a failure, `nil` otherwise.
	public var error: Error? {
		return analysis(ifSuccess: { _ in nil }, ifFailure: { $0 })
	}

	/// Returns a new Result by mapping `Success`es’ values using `transform`, or re-wrapping `Failure`s’ errors.
#if swift(>=3)
	public func map<U>(@noescape _ transform: Value -> U) -> Result<U, Error> {
		return flatMap { .Success(transform($0)) }
	}
#else
	public func map<U>(@noescape transform: Value -> U) -> Result<U, Error> {
		return flatMap { .Success(transform($0)) }
	}
#endif

	/// Returns the result of applying `transform` to `Success`es’ values, or re-wrapping `Failure`’s errors.
#if swift(>=3)
	public func flatMap<U>(@noescape _ transform: Value -> Result<U, Error>) -> Result<U, Error> {
		return analysis(
			ifSuccess: transform,
			ifFailure: Result<U, Error>.Failure)
	}
#else
	public func flatMap<U>(@noescape transform: Value -> Result<U, Error>) -> Result<U, Error> {
		return analysis(
			ifSuccess: transform,
			ifFailure: Result<U, Error>.Failure)
	}
#endif
	
	/// Returns a new Result by mapping `Failure`'s values using `transform`, or re-wrapping `Success`es’ values.
#if swift(>=3)
	public func mapError<Error2>(@noescape _ transform: Error -> Error2) -> Result<Value, Error2> {
		return flatMapError { .Failure(transform($0)) }
	}
#else
	public func mapError<Error2>(@noescape transform: Error -> Error2) -> Result<Value, Error2> {
		return flatMapError { .Failure(transform($0)) }
	}
#endif

	/// Returns the result of applying `transform` to `Failure`’s errors, or re-wrapping `Success`es’ values.
#if swift(>=3)
	public func flatMapError<Error2>(@noescape _ transform: Error -> Result<Value, Error2>) -> Result<Value, Error2> {
		return analysis(
			ifSuccess: Result<Value, Error2>.Success,
			ifFailure: transform)
	}
#else
	public func flatMapError<Error2>(@noescape transform: Error -> Result<Value, Error2>) -> Result<Value, Error2> {
		return analysis(
			ifSuccess: Result<Value, Error2>.Success,
			ifFailure: transform)
	}
#endif
}

/// Protocol used to constrain `tryMap` to `Result`s with compatible `Error`s.
public protocol ErrorTypeConvertible: ResultErrorType {
#if swift(>=3)
	static func errorFromErrorType(_ error: ResultErrorType) -> Self
#else
	static func errorFromErrorType(error: ResultErrorType) -> Self
#endif
}

public extension ResultType where Error: ErrorTypeConvertible {

	/// Returns the result of applying `transform` to `Success`es’ values, or wrapping thrown errors.
#if swift(>=3)
	public func tryMap<U>(@noescape _ transform: Value throws -> U) -> Result<U, Error> {
		return flatMap { value in
			do {
				return .Success(try transform(value))
			}
			catch {
				let convertedError = Error.errorFromErrorType(error)
				// Revisit this in a future version of Swift. https://twitter.com/jckarter/status/672931114944696321
				return .Failure(convertedError)
			}
		}
	}
#else
	public func tryMap<U>(@noescape transform: Value throws -> U) -> Result<U, Error> {
		return flatMap { value in
			do {
				return .Success(try transform(value))
			}
			catch {
				let convertedError = Error.errorFromErrorType(error)
				// Revisit this in a future version of Swift. https://twitter.com/jckarter/status/672931114944696321
				return .Failure(convertedError)
			}
		}
	}
#endif
}

// MARK: - Operators

infix operator &&& {
	/// Same associativity as &&.
	associativity left

	/// Same precedence as &&.
	precedence 120
}

/// Returns a Result with a tuple of `left` and `right` values if both are `Success`es, or re-wrapping the error of the earlier `Failure`.
public func &&& <L: ResultType, R: ResultType where L.Error == R.Error> (left: L, @autoclosure right: () -> R) -> Result<(L.Value, R.Value), L.Error> {
	return left.flatMap { left in right().map { right in (left, right) } }
}
