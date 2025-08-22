platform :ios, '14.0'

inhibit_all_warnings!

target 'Delta' do
    use_modular_headers!

    pod 'SQLite.swift', '~> 0.12.0'
    pod 'SDWebImage', '~> 3.8'
    pod 'SMCalloutView', '~> 2.1.0'

    pod 'DeltaCore', :path => 'Cores/DeltaCore'
    pod 'NESDeltaCore', :path => 'Cores/NESDeltaCore'
    pod 'SNESDeltaCore', :path => 'Cores/SNESDeltaCore'
    # pod 'N64DeltaCore', :path => 'Cores/N64DeltaCore'  # Temporarily disabled for NFC MVP
    pod 'GBCDeltaCore', :path => 'Cores/GBCDeltaCore'
    pod 'GBADeltaCore', :path => 'Cores/GBADeltaCore'
    pod 'MelonDSDeltaCore', :path => 'Cores/MelonDSDeltaCore'
    pod 'Roxas', :path => 'External/Roxas'
    pod 'Harmony', :path => 'External/Harmony'
end

target 'DeltaPreviews' do
    use_modular_headers!

    pod 'DeltaCore', :path => 'Cores/DeltaCore'
    pod 'Roxas', :path => 'External/Roxas'
end

# Unlink DeltaCore to prevent conflicts with Systems.framework
# Fix deployment target warnings for all pods
post_install do |installer|
    installer.pods_project.targets.each do |target|
        # Fix deployment targets for all pods (resolves iOS 12.0+ simulator requirement)
        target.build_configurations.each do |config|
            if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 14.0
                config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
                puts "Updated #{target.name} deployment target to iOS 14.0"
            end
        end
        
        # Remove DeltaCore linking conflicts
        if target.name == "Pods-Delta"
            puts "Updating #{target.name} OTHER_LDFLAGS"
            target.build_configurations.each do |config|
                xcconfig_path = config.base_configuration_reference.real_path
                xcconfig = File.read(xcconfig_path)
                new_xcconfig = xcconfig.sub('-l"DeltaCore"', '')
                File.open(xcconfig_path, "w") { |file| file << new_xcconfig }
            end
        end
    end
end