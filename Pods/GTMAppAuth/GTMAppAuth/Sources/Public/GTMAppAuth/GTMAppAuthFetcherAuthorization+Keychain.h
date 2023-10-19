/*! @file GTMAppAuthFetcherAuthorization+Keychain.h
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

#import "GTMAppAuthFetcherAuthorization.h"

NS_ASSUME_NONNULL_BEGIN

/*! @brief Category to support serialization and deserialization of
        @c GTMAppAuthFetcherAuthorization in the format used by GTMAppAuth.
 */
@interface GTMAppAuthFetcherAuthorization (Keychain)

/*! @brief Attempts to create a @c GTMAppAuthFetcherAuthorization from data stored in the keychain
        in GTMAppAuth format.
    @param keychainItemName The keychain name.
    @return A @c GTMAppAuthFetcherAuthorization object, or nil.
 */
+ (nullable GTMAppAuthFetcherAuthorization *)
    authorizationFromKeychainForName:(NSString *)keychainItemName;

/*! @brief Attempts to create a @c GTMAppAuthFetcherAuthorization from data stored in the keychain
        in GTMAppAuth format.  Note that if you choose to start using the data protection keychain on
        macOS, any items previously created will not be accessible without migration.
    @param keychainItemName The keychain name.
    @param useDataProtectionKeychain A Boolean value that indicates whether to use the data
        protection keychain on macOS 10.15+.
    @return A @c GTMAppAuthFetcherAuthorization object, or nil.
 */
+ (nullable GTMAppAuthFetcherAuthorization *)
    authorizationFromKeychainForName:(NSString *)keychainItemName
           useDataProtectionKeychain:(BOOL)useDataProtectionKeychain API_AVAILABLE(macosx(10.15));

/*! @brief Removes a stored authorization state.
    @param keychainItemName The keychain name.
    @return YES if the tokens were removed successfully (or didn't exist).
 */
+ (BOOL)removeAuthorizationFromKeychainForName:(NSString *)keychainItemName;

/*! @brief Removes a stored authorization state.  Note that if you choose to start using the data
        protection keychain on macOS, any items previously created will not be accessible without
        migration.
    @param keychainItemName The keychain name.
    @param useDataProtectionKeychain A Boolean value that indicates whether to use the data
        protection keychain on macOS 10.15+.
    @return YES if the tokens were removed successfully (or didn't exist).
 */
+ (BOOL)removeAuthorizationFromKeychainForName:(NSString *)keychainItemName
                     useDataProtectionKeychain:(BOOL)useDataProtectionKeychain
    API_AVAILABLE(macosx(10.15));

/*! @brief Saves the authorization state to the keychain, in GTMAppAuth format.
    @param auth The authorization to save.
    @param keychainItemName The keychain name.
    @return YES when the state was saved successfully.
 */
+ (BOOL)saveAuthorization:(GTMAppAuthFetcherAuthorization *)auth
        toKeychainForName:(NSString *)keychainItemName;

/*! @brief Saves the authorization state to the keychain, in GTMAppAuth format.  Note that if you
        choose to start using the data protection keychain on macOS, any items previously created
        will not be accessible without migration.
    @param auth The authorization to save.
    @param keychainItemName The keychain name.
    @param useDataProtectionKeychain A Boolean value that indicates whether to use the data
        protection keychain on macOS 10.15+.
    @return YES when the state was saved successfully.
 */
+ (BOOL)saveAuthorization:(GTMAppAuthFetcherAuthorization *)auth
             toKeychainForName:(NSString *)keychainItemName
     useDataProtectionKeychain:(BOOL)useDataProtectionKeychain API_AVAILABLE(macosx(10.15));

@end

NS_ASSUME_NONNULL_END
