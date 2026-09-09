// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CryptoKit
import HealthCore

@MainActor final class EncryptedOutbox:ObservableObject {
 @Published private(set) var operations:[OutboxOperation]=[]
 @Published private(set) var loadError:String?
 private let keychain:KeychainStore
 private let url:URL

 init(keychain:KeychainStore=KeychainStore()) {
  self.keychain=keychain
  url=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("quick-entry.outbox")
  do { try load() } catch { loadError=error.localizedDescription }
 }

 func enqueue(endpoint:String,method:HTTPMethod,body:Data)throws {
  try requireWritable()
  var proposed=operations
  proposed.append(.init(endpoint:endpoint,method:method,body:body))
  try persist(proposed)
  operations=proposed
 }

 func remove(_ id:UUID)throws {
  try requireWritable()
  var proposed=operations
  proposed.removeAll{$0.operationId==id}
  try persist(proposed)
  operations=proposed
 }

 func mark(_ id:UUID,state:OutboxOperation.State,error:String?=nil)throws {
  try requireWritable()
  guard let i=operations.firstIndex(where:{$0.operationId==id})else{return}
  var proposed=operations
  proposed[i].state=state
  proposed[i].lastError=error
  if state == .failed{proposed[i].attempts += 1}
  try persist(proposed)
  operations=proposed
 }

 private func requireWritable()throws {
  if let loadError {throw HealthCoreError.invalidValue("Encrypted queue is locked: \(loadError). Erase it explicitly to reset it.")}
 }

 private func encryptionKey()throws->SymmetricKey {
  if let data=try keychain.load(Data.self,key:"outbox-key"){return SymmetricKey(data:data)}
  let key=SymmetricKey(size:.bits256)
  let data=key.withUnsafeBytes{Data($0)}
  try keychain.save(data,key:"outbox-key")
  return key
 }

 private func persist(_ proposed:[OutboxOperation])throws {
  let clear=try JSONEncoder().encode(proposed)
  let sealed=try AES.GCM.seal(clear,using:encryptionKey()).combined!
  try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
  try sealed.write(to:url,options:.atomic)
  try FileManager.default.setAttributes([.protectionKey:FileProtectionType.complete],ofItemAtPath:url.path) // NSFileProtectionComplete
 }

 private func load()throws {
  guard FileManager.default.fileExists(atPath:url.path)else{return}
  let sealed=try AES.GCM.SealedBox(combined:Data(contentsOf:url))
  operations=try JSONDecoder().decode([OutboxOperation].self,from:AES.GCM.open(sealed,using:encryptionKey()))
 }

 func erase()throws {
  if FileManager.default.fileExists(atPath:url.path){try FileManager.default.removeItem(at:url)}
  try keychain.delete(key:"outbox-key")
  operations=[]
  loadError=nil
 }
}
