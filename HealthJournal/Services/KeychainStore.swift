// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Security
struct StoredAccount:Codable {let server:String;let login:String;let appPassword:String}
final class KeychainStore {
 private let service="com.check27.healthjournal"
 func save<T:Encodable>(_ value:T,key:String)throws{let data=try JSONEncoder().encode(value);SecItemDelete([kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:key] as CFDictionary);let status=SecItemAdd([kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:key,kSecValueData:data,kSecAttrAccessible:kSecAttrAccessibleWhenUnlockedThisDeviceOnly] as CFDictionary,nil);guard status==errSecSuccess else{throw NSError(domain:NSOSStatusErrorDomain,code:Int(status))}}
 func load<T:Decodable>(_ type:T.Type,key:String)throws->T?{var result:CFTypeRef?;let status=SecItemCopyMatching([kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:key,kSecReturnData:true,kSecMatchLimit:kSecMatchLimitOne] as CFDictionary,&result);if status==errSecItemNotFound{return nil};guard status==errSecSuccess,let data=result as? Data else{throw NSError(domain:NSOSStatusErrorDomain,code:Int(status))};return try JSONDecoder().decode(type,from:data)}
 func delete(key:String)throws{let s=SecItemDelete([kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:key] as CFDictionary);guard s==errSecSuccess||s==errSecItemNotFound else{throw NSError(domain:NSOSStatusErrorDomain,code:Int(s))}}
}
