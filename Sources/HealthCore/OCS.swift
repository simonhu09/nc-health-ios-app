// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
public struct OCSResponse<T:Decodable>:Decodable{public let ocs:OCSContainer<T>}
public struct OCSMetadataResponse:Decodable{public struct Container:Decodable{public let meta:OCSMeta};public let ocs:Container}
public struct OCSContainer<T:Decodable>:Decodable{public let meta:OCSMeta;public let data:T}
public struct OCSMeta:Codable,Sendable{public let status:String;public let statuscode:Int;public let message:String?;public init(status:String,statuscode:Int,message:String?=nil){self.status=status;self.statuscode=statuscode;self.message=message};public func validate()throws{guard status.lowercased()=="ok"||(100...199).contains(statuscode) else{throw HealthCoreError.ocs(statuscode,message ?? status)}}}
public extension JSONDecoder { static var health: JSONDecoder { let d = JSONDecoder(); d.keyDecodingStrategy = .useDefaultKeys; return d } }
public enum JSONValue:Codable,Hashable,Sendable{case string(String),number(Double),bool(Bool),object([String:JSONValue]),array([JSONValue]),null
 public init(from d:Decoder)throws{let c=try d.singleValueContainer();if c.decodeNil(){self = .null}else if let x=try? c.decode(Bool.self){self = .bool(x)}else if let x=try? c.decode(Double.self){self = .number(x)}else if let x=try? c.decode(String.self){self = .string(x)}else if let x=try? c.decode([String:JSONValue].self){self = .object(x)}else{self = .array(try c.decode([JSONValue].self))}}
 public func encode(to e:Encoder)throws{var c=e.singleValueContainer();switch self{case .string(let x):try c.encode(x);case .number(let x):try c.encode(x);case .bool(let x):try c.encode(x);case .object(let x):try c.encode(x);case .array(let x):try c.encode(x);case .null:try c.encodeNil()}}}
