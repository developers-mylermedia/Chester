//
//  Copyright © 2016 Jan Gorman. All rights reserved.
//

import Foundation

public enum QueryError: Error {
  case missingCollection
  case missingFields
  case missingArguments
  case invalidState(String)
}

public struct Argument {

  let key: String
  let value: Any
  
  func build() -> String {
    return "\(key): \(value)"
  }

}

final class QueryBuilder {

  fileprivate var queries: [Query]
  
  public init() {
    queries = []
  }

  /// The collection to query
  ///
  /// - Parameter collection: The collection name.
  /// - Parameter fields: The fields to query in this collection. Use as an alternative to passing in fields separately
  ///                     or when querying multiple top level collections.
  /// - Parameter arguments: The arguments to limit this collection.
  /// - Parameter subQueries: for this collection.
  open func fromCollection(_ collection: String, fields: [String]? = nil, arguments: [Argument]? = nil,
                             subQueries: [QueryBuilder]? = nil) -> Self {
    var query = Query(collection: collection)
    if let fields = fields {
      query.withFields(fields)
    }
    if let arguments = arguments {
      query.withArguments(arguments)
    }
    if let subQueries = subQueries {
      query.withSubQueries(subQueries.flatMap{ $0.queries })
    }
    self.queries.append(query)
    return self
  }
  
  /// Query arguments
  ///
  /// - Parameter arguments: The query args struct(s)
  /// - Throws: `MissingCollection` if no collection is defined before passing in arguments
  open func withArguments(_ arguments: Argument...) throws -> Self {
    guard let _ = queries.first else { throw QueryError.missingCollection }
    self.queries[0].withArguments(arguments)
    return self
  }
  
  /// The fields to retrieve
  ///
  /// - Parameter fields: The field names
  /// - Throws: `MissingCollection` if no collection is defined before passing in fields
  open func withFields(_ fields: String...) throws -> Self {
    guard let _ = queries.first else { throw QueryError.missingCollection }
    self.queries[0].withFields(fields)
    return self
  }
  
  /// Insert a subquery. Add as many top level or nested queries as desired.
  ///
  /// - Parameter query: The subquery
  /// - Throws: `MissingCollection` if no collection is defined before passing in a subquery
  open func withSubQuery(_ query: QueryBuilder) throws -> Self {
    guard !queries.isEmpty else { throw QueryError.missingCollection }
    queries[0].withSubQueries(query.queries)
    return self
  }
  
  /// Build the query.
  ///
  /// - Returns: The constructed query as String
  /// - Throws: Throws `QueryError` if the builder is in an invalid state before calling `build()` 
  open func build() throws -> String {
    try validateQuery()
    return try QueryStringBuilder(self).build()
  }

  fileprivate func validateQuery() throws {
    if queries.isEmpty {
      throw QueryError.missingCollection
    }
    try queries.forEach { try $0.validate() }
  }

}

private class QueryStringBuilder {
  
  fileprivate let queryBuilder: QueryBuilder
  
  init(_ queryBuilder: QueryBuilder) {
    self.queryBuilder = queryBuilder
  }
  
  fileprivate func build() throws -> String {
    var queryString = "{\n"
    for (i, query) in queryBuilder.queries.enumerated() {
      queryString += try query.build()
      queryString += joinCollections(i)
    }
    queryString += "\n}"
    return queryString
  }
  
  fileprivate func joinCollections(_ current: Int) -> String {
    return current == queryBuilder.queries.count - 1 ? "" : ",\n"
  }

}

extension String {
  
  func times(_ times: Int) -> String {
    var result = ""
    for _ in 0..<times {
      result += self
    }
    return result
  }
  
}
