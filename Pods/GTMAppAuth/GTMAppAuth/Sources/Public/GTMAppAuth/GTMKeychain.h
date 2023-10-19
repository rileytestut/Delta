/*! @file GTMKeychain.h
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*! @brief Utility for saving and loading data to the keychain.
 */
@interface GTMKeychain : NSObject

/*! @brief Saves the password string to the keychain with the given identifier.
    @param keychainItemName Keychain name of the item.
    @param password Password string to save.
    @return YES if the password string was saved successfully.
 */
+ (BOOL)savePasswordToKeychainForName:(NSString *)keychainItemName
                             password:(NSString *)password;

/*! @brief Saves the password string to the keychain with the given identifier.  Note that if you
        choose to start using the data protection keychain on macOS, any items previously created
        will not be accessible without migration.
    @param keychainItemName Keychain name of the item.
    @param password Password string to save.
    @param useDataProtectionKeychain A Boolean value that indicates whether to use the data
        protection keychain on macOS 10.15+.
    @return YES if the password string was saved successfully.
 */
+ (BOOL)savePasswordToKeychainForName:(NSString *)keychainItemName
                             password:(NSString *)password
            useDataProtectionKeychain:(BOOL)useDataProtectionKeychain API_AVAILABLE(macosx(10.15));

/*! @brief Loads the password string from the keychain with the given identifier.
    @param keychainItemName Keychain name of the item.
    @return The password string at the given identifier, or nil.
 */
+ (nullable NSString *)passwordFromKeychainForName:(NSString *)keychainItemName;

/*! @brief Loads the password string from the keychain with the given identifier.  Note that if you
        choose to start using the data protection keychain on macOS, any items previously created
        will not be accessible without migration.
    @param keychainItemName Keychain name of the item.
    @param useDataProtectionKeychain A Boolean value that indicates whether to use the data
        protection keychain on macOS 10.15+.
    @return The password string at the given identifier, or nil.
 */
+ (nullable NSString *)passwordFromKeychainForName:(NSString *)keychainItemName
                         useDataProtectionKeychain:(BOOL)useDataProtectionKeychain
    API_AVAILABLE(macosx(10.15));

/*! @brief Saves the password data to the keychain with the given identifier.
    @param keychainItemName Keychain name of the item.
    @param passwordData Password data to save.
    @return YES if the password data was saved successfully.
 */
+ (BOOL)savePasswordDataToKeychainForName:(NSString *)keychainItemName
                             passwordData:(NSData *)passwordData;

/*! @brief Saves the password data to the keychain with the given identifier.  Note that if you
        choose to start using the data protection keychain on macOS, any items previously created
        will not be accessible without migration.
    @param keychainItemName Keychain name of the item.
    @param passwordData Password data to save.
    @param useDataProtectionKeychain A Boolean value that indicates whether to use the data
        protection keychain on macOS 10.15+.
    @return YES if the password data was saved successfully.
 */
+ (BOOL)savePasswordDataToKeychainForName:(NSString *)keychainItemName
                             passwordData:(NSData *)passwordData
                useDataProtectionKeychain:(BOOL)useDataProtectionKeychain
    API_AVAILABLE(macosx(10.15));

/*! @brief Loads the password data from the keychain with the given identifier.
    @param keychainItemName Keychain name of the item.
    @return The password data at the given identifier, or nil.
 */
+ (nullable NSData *)passwordDataFromKeychainForName:(NSString *)keychainItemName;

/*! @brief Loads the password data from the keychain with the given identifier.  Note that if you
        choose to start using the data protection keychain on macOS, any items previously created
        will not be accessible without migration.
    @param keychainItemName Keychain name of the item.
    @param useDataProtectionKeychain A Boolean value that indicates whether to use the data
        protection keychain on macOS 10.15+.
    @return The password data at the given identifier, or nil.
 */
+ (nullable NSData *)passwordDataFromKeychainForName:(NSString *)keychainItemName
                           useDataProtectionKeychain:(BOOL)useDataProtectionKeychain
    API_AVAILABLE(macosx(10.15));

/*! @brief Removes stored password string, such as when the user signs out.
    @param keychainItemName Keychain name of the item.
    @return YES if the password string was removed successfully (or didn't exist).
 */
+ (BOOL)removePasswordFromKeychainForName:(NSString *)keychainItemName;

/*! @brief Removes stored password string, such as when the user signs out.  Note that if you
        choose to start using the data protection keychain on macOS, any items previously created
        will not be accessible without migration.
    @param keychainItemName Keychain name of the item.
    @param useDataProtectionKeychain A Boolean value that indicates whether to use the data
        protection keychain on macOS 10.15+.
    @return YES if the password string was removed successfully (or didn't exist).
 */
+ (BOOL)removePasswordFromKeychainForName:(NSString *)keychainItemName
                useDataProtectionKeychain:(BOOL)useDataProtectionKeychain
    API_AVAILABLE(macosx(10.15));

@end

NS_ASSUME_NONNULL_END
