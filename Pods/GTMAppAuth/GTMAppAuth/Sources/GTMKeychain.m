/*! @file GTMKeychain_iOS.m
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

#import "GTMAppAuth/Sources/Public/GTMAppAuth/GTMKeychain.h"

#import <Security/Security.h>

/*! @brief Keychain helper class.
 */
@interface GTMAppAuthGTMOAuth2Keychain : NSObject

// When set to YES, all Keychain queries will have
// kSecUseDataProtectionKeychain set to true on macOS 10.15+.  Defaults to NO.
@property(nonatomic) BOOL useDataProtectionKeychain;

+ (GTMAppAuthGTMOAuth2Keychain *)defaultKeychain;

// OK to pass nil for the error parameter.
- (NSString *)passwordForService:(NSString *)service
                         account:(NSString *)account
                           error:(NSError **)error;

- (NSData *)passwordDataForService:(NSString *)service
                           account:(NSString *)account
                             error:(NSError **)error;

// OK to pass nil for the error parameter.
- (BOOL)removePasswordForService:(NSString *)service
                         account:(NSString *)account
                           error:(NSError **)error;

// OK to pass nil for the error parameter.
//
// accessibility should be one of the constants for kSecAttrAccessible
// such as kSecAttrAccessibleWhenUnlocked
- (BOOL)setPassword:(NSString *)password
         forService:(NSString *)service
      accessibility:(CFTypeRef)accessibility
            account:(NSString *)account
              error:(NSError **)error;

- (BOOL)setPasswordData:(NSData *)passwordData
             forService:(NSString *)service
          accessibility:(CFTypeRef)accessibility
                account:(NSString *)account
                  error:(NSError **)error;

// For unit tests: allow setting a mock object
+ (void)setDefaultKeychain:(GTMAppAuthGTMOAuth2Keychain *)keychain;

@end

static NSString *const kGTMAppAuthFetcherAuthorizationGTMOAuth2AccountName = @"OAuth";

@implementation GTMKeychain

+ (BOOL)removePasswordFromKeychainForName:(NSString *)keychainItemName {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
  return [GTMKeychain removePasswordFromKeychainForName:keychainItemName
                              useDataProtectionKeychain:NO];
#pragma clang diagnostic pop
}

+ (BOOL)removePasswordFromKeychainForName:(NSString *)keychainItemName
                useDataProtectionKeychain:(BOOL)useDataProtectionKeychain {
  GTMAppAuthGTMOAuth2Keychain *keychain = [GTMAppAuthGTMOAuth2Keychain defaultKeychain];
  keychain.useDataProtectionKeychain = useDataProtectionKeychain;
  return [keychain removePasswordForService:keychainItemName
                                    account:kGTMAppAuthFetcherAuthorizationGTMOAuth2AccountName
                                      error:nil];
}

+ (NSString *)passwordFromKeychainForName:(NSString *)keychainItemName {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
  return [GTMKeychain passwordFromKeychainForName:keychainItemName useDataProtectionKeychain:NO];
#pragma clang diagnostic pop
}

+ (NSString *)passwordFromKeychainForName:(NSString *)keychainItemName
                useDataProtectionKeychain:(BOOL)useDataProtectionKeychain {
  GTMAppAuthGTMOAuth2Keychain *keychain = [GTMAppAuthGTMOAuth2Keychain defaultKeychain];
  keychain.useDataProtectionKeychain = useDataProtectionKeychain;
  NSError *error;
  NSString *password =
      [keychain passwordForService:keychainItemName
                           account:kGTMAppAuthFetcherAuthorizationGTMOAuth2AccountName
                             error:&error];
  return password;
}

+ (BOOL)savePasswordToKeychainForName:(NSString *)keychainItemName
                             password:(NSString *)password {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
  return [GTMKeychain savePasswordToKeychainForName:keychainItemName
                                           password:password
                          useDataProtectionKeychain:NO];
#pragma clang diagnostic pop
}

+ (BOOL)savePasswordToKeychainForName:(NSString *)keychainItemName
                             password:(NSString *)password
            useDataProtectionKeychain:(BOOL)useDataProtectionKeychain {
  CFTypeRef accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
  GTMAppAuthGTMOAuth2Keychain *keychain = [GTMAppAuthGTMOAuth2Keychain defaultKeychain];
  keychain.useDataProtectionKeychain = useDataProtectionKeychain;
  return [keychain setPassword:password
                    forService:keychainItemName
                 accessibility:accessibility
                       account:kGTMAppAuthFetcherAuthorizationGTMOAuth2AccountName
                         error:NULL];
}

+ (BOOL)savePasswordDataToKeychainForName:(NSString *)keychainItemName
                             passwordData:(NSData *)password {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
  return [GTMKeychain savePasswordDataToKeychainForName:keychainItemName
                                           passwordData:password
                              useDataProtectionKeychain:NO];
#pragma clang diagnostic pop
}

+ (BOOL)savePasswordDataToKeychainForName:(NSString *)keychainItemName
                             passwordData:(NSData *)password
                useDataProtectionKeychain:(BOOL)useDataProtectionKeychain {
  CFTypeRef accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
  GTMAppAuthGTMOAuth2Keychain *keychain = [GTMAppAuthGTMOAuth2Keychain defaultKeychain];
  keychain.useDataProtectionKeychain = useDataProtectionKeychain;
  return [keychain setPasswordData:password
                        forService:keychainItemName
                     accessibility:accessibility
                           account:kGTMAppAuthFetcherAuthorizationGTMOAuth2AccountName
                             error:NULL];
}

+ (NSData *)passwordDataFromKeychainForName:(NSString *)keychainItemName {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
  return [GTMKeychain passwordDataFromKeychainForName:keychainItemName
                            useDataProtectionKeychain:NO];
#pragma clang diagnostic pop
}

+ (NSData *)passwordDataFromKeychainForName:(NSString *)keychainItemName
                  useDataProtectionKeychain:(BOOL)useDataProtectionKeychain {
  GTMAppAuthGTMOAuth2Keychain *keychain = [GTMAppAuthGTMOAuth2Keychain defaultKeychain];
  keychain.useDataProtectionKeychain = useDataProtectionKeychain;
  NSError *error;
  NSData *password =
      [keychain passwordDataForService:keychainItemName
                               account:kGTMAppAuthFetcherAuthorizationGTMOAuth2AccountName
                                 error:&error];
  return password;
}

@end


typedef NS_ENUM(NSInteger, GTMAppAuthFetcherAuthorizationGTMAppAuthGTMOAuth2KeychainError) {
  GTMAppAuthGTMOAuth2KeychainErrorBadArguments = -1301,
  GTMAppAuthGTMOAuth2KeychainErrorNoPassword = -1302
};

NSString *const kGTMAppAuthFetcherAuthorizationGTMOAuth2KeychainErrorDomain =
    @"com.google.GTMOAuthKeychain";

static GTMAppAuthGTMOAuth2Keychain* gGTMAppAuthFetcherAuthorizationGTMOAuth2DefaultKeychain = nil;

@implementation GTMAppAuthGTMOAuth2Keychain

- (instancetype)init {
  self = [super init];
  if (self) {
    _useDataProtectionKeychain = NO;
  }
  return self;
}

+ (GTMAppAuthGTMOAuth2Keychain *)defaultKeychain {
  static dispatch_once_t onceToken;
  dispatch_once (&onceToken, ^{
    gGTMAppAuthFetcherAuthorizationGTMOAuth2DefaultKeychain = [[self alloc] init];
  });
  return gGTMAppAuthFetcherAuthorizationGTMOAuth2DefaultKeychain;
}

// For unit tests: allow setting a mock object
+ (void)setDefaultKeychain:(GTMAppAuthGTMOAuth2Keychain *)keychain {
  if (gGTMAppAuthFetcherAuthorizationGTMOAuth2DefaultKeychain != keychain) {
    gGTMAppAuthFetcherAuthorizationGTMOAuth2DefaultKeychain = keychain;
  }
}

- (NSMutableDictionary *)keychainQueryForService:(NSString *)service account:(NSString *)account {
  NSMutableDictionary *query =
      [NSMutableDictionary dictionaryWithObjectsAndKeys:(id)kSecClassGenericPassword, (id)kSecClass,
                                                        account, (id)kSecAttrAccount,
                                                        service, (id)kSecAttrService,
                                                        nil];
  // kSecUseDataProtectionKeychain is a no-op on platforms other than macOS 10.15+.  For clarity, we
  // set it here only when supported by the Apple SDK and when relevant at runtime.
#if TARGET_OS_OSX && __MAC_OS_X_VERSION_MAX_ALLOWED >= 101500
  if (@available(macOS 10.15, *)) {
    if (self.useDataProtectionKeychain) {
      [query setObject:(id)kCFBooleanTrue forKey:(id)kSecUseDataProtectionKeychain];
    }
  }
#endif
  return query;
}

- (NSString *)passwordForService:(NSString *)service
                         account:(NSString *)account
                           error:(NSError **)error {
  NSData *passwordData = [self passwordDataForService:service account:account error:error];
  if (!passwordData) {
    return nil;
  }
  NSString *result = [[NSString alloc] initWithData:passwordData
                                           encoding:NSUTF8StringEncoding];
  return result;
}

- (NSData *)passwordDataForService:(NSString *)service
                           account:(NSString *)account
                             error:(NSError **)error {
  OSStatus status = GTMAppAuthGTMOAuth2KeychainErrorBadArguments;
  NSData *result = nil;
  if (service.length > 0 && account.length > 0) {
    CFDataRef passwordData = NULL;
    NSMutableDictionary *keychainQuery = [self keychainQueryForService:service account:account];
    [keychainQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
    [keychainQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];

    status = SecItemCopyMatching((CFDictionaryRef)keychainQuery,
                                       (CFTypeRef *)&passwordData);
    if (status == noErr && 0 < [(__bridge NSData *)passwordData length]) {
      result = [(__bridge NSData *)passwordData copy];
    }
    if (passwordData != NULL) {
      CFRelease(passwordData);
    }
  }
  if (status != noErr && error != NULL) {
    *error = [NSError errorWithDomain:kGTMAppAuthFetcherAuthorizationGTMOAuth2KeychainErrorDomain
                                 code:status
                             userInfo:nil];
  }
  return result;
}

- (BOOL)removePasswordForService:(NSString *)service
                         account:(NSString *)account
                           error:(NSError **)error {
  OSStatus status = GTMAppAuthGTMOAuth2KeychainErrorBadArguments;
  if (0 < [service length] && 0 < [account length]) {
    NSMutableDictionary *keychainQuery = [self keychainQueryForService:service account:account];
    status = SecItemDelete((CFDictionaryRef)keychainQuery);
  }
  if (status != noErr && error != NULL) {
    *error = [NSError errorWithDomain:kGTMAppAuthFetcherAuthorizationGTMOAuth2KeychainErrorDomain
                                 code:status
                             userInfo:nil];
  }
  return status == noErr;
}

- (BOOL)setPassword:(NSString *)password
         forService:(NSString *)service
      accessibility:(CFTypeRef)accessibility
            account:(NSString *)account
              error:(NSError **)error {
  NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
  return [self setPasswordData:passwordData
                    forService:service
                 accessibility:accessibility
                       account:account
                         error:error];
}

- (BOOL)setPasswordData:(NSData *)passwordData
             forService:(NSString *)service
          accessibility:(CFTypeRef)accessibility
                account:(NSString *)account
                  error:(NSError **)error {
  OSStatus status = GTMAppAuthGTMOAuth2KeychainErrorBadArguments;
  if (0 < [service length] && 0 < [account length]) {
    [self removePasswordForService:service account:account error:nil];
    if (0 < [passwordData length]) {
      NSMutableDictionary *keychainQuery = [self keychainQueryForService:service account:account];
      [keychainQuery setObject:passwordData forKey:(id)kSecValueData];

      if (accessibility != NULL) {
        [keychainQuery setObject:(__bridge id)accessibility
                          forKey:(id)kSecAttrAccessible];
      }
      status = SecItemAdd((CFDictionaryRef)keychainQuery, NULL);
    }
  }
  if (status != noErr && error != NULL) {
    *error = [NSError errorWithDomain:kGTMAppAuthFetcherAuthorizationGTMOAuth2KeychainErrorDomain
                                 code:status
                             userInfo:nil];
  }
  return status == noErr;
}

@end
