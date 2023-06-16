/*! @file GTMAppAuthFetcherAuthorization+Keychain.m
    @brief GTMAppAuth SDK
    @copyright
        Copyright 2016 Google Inc.
    @copydetails
        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the License.
        You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.
 */

#import "GTMAppAuth/Sources/Public/GTMAppAuth/GTMAppAuthFetcherAuthorization+Keychain.h"

#import "GTMAppAuth/Sources/Public/GTMAppAuth/GTMKeychain.h"

@implementation GTMAppAuthFetcherAuthorization (Keychain)

+ (GTMAppAuthFetcherAuthorization *)authorizationFromKeychainForName:(NSString *)keychainItemName {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
  return [GTMAppAuthFetcherAuthorization authorizationFromKeychainForName:keychainItemName
                                                useDataProtectionKeychain:NO];
#pragma clang diagnostic pop
}

+ (GTMAppAuthFetcherAuthorization *)authorizationFromKeychainForName:(NSString *)keychainItemName
                                           useDataProtectionKeychain:(BOOL)useDataProtectionKeychain {
  NSData *passwordData = [GTMKeychain passwordDataFromKeychainForName:keychainItemName
                                            useDataProtectionKeychain:useDataProtectionKeychain];
  if (!passwordData) {
    return nil;
  }
  GTMAppAuthFetcherAuthorization *authorization;
  if (@available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *)) {
    authorization = (GTMAppAuthFetcherAuthorization *)
        [NSKeyedUnarchiver unarchivedObjectOfClass:[GTMAppAuthFetcherAuthorization class]
                                          fromData:passwordData
                                             error:nil];
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    authorization = (GTMAppAuthFetcherAuthorization *)
        [NSKeyedUnarchiver unarchiveObjectWithData:passwordData];
#pragma clang diagnostic pop
  }
  return authorization;
}

+ (BOOL)removeAuthorizationFromKeychainForName:(NSString *)keychainItemName {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
  return [GTMAppAuthFetcherAuthorization removeAuthorizationFromKeychainForName:keychainItemName
                                                      useDataProtectionKeychain:NO];
#pragma clang diagnostic pop
}

+ (BOOL)removeAuthorizationFromKeychainForName:(NSString *)keychainItemName
                     useDataProtectionKeychain:(BOOL)useDataProtectionKeychain {
  return [GTMKeychain removePasswordFromKeychainForName:keychainItemName
                              useDataProtectionKeychain:useDataProtectionKeychain];
}

+ (BOOL)saveAuthorization:(GTMAppAuthFetcherAuthorization *)auth
        toKeychainForName:(NSString *)keychainItemName {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
  return [GTMAppAuthFetcherAuthorization saveAuthorization:auth
                                         toKeychainForName:keychainItemName
                                 useDataProtectionKeychain:NO];
#pragma clang diagnostic pop
}

+ (BOOL)saveAuthorization:(GTMAppAuthFetcherAuthorization *)auth
             toKeychainForName:(NSString *)keychainItemName
     useDataProtectionKeychain:(BOOL)useDataProtectionKeychain {
  NSData *authorizationData;
  if (@available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *)) {
    authorizationData = [NSKeyedArchiver archivedDataWithRootObject:auth
                                              requiringSecureCoding:YES
                                                              error:nil];
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    authorizationData = [NSKeyedArchiver archivedDataWithRootObject:auth];
#pragma clang diagnostic pop
  }
  return [GTMKeychain savePasswordDataToKeychainForName:keychainItemName
                                           passwordData:authorizationData
                              useDataProtectionKeychain:useDataProtectionKeychain];
}

@end
