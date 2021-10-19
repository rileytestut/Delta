platform :ios, '12.0'

inhibit_all_warnings!

target 'Delta' do
    use_modular_headers!

    pod 'SQLite.swift', '~> 0.12.0'
    pod 'SDWebImage', '~> 3.8'
    pod 'Fabric', '~> 1.6.0'
    pod 'Crashlytics', '~> 3.8.0'
    pod 'SMCalloutView', '~> 2.1.0'

    pod 'DeltaCore', :path => 'Cores/DeltaCore'
    pod 'NESDeltaCore', :path => 'Cores/NESDeltaCore'
    pod 'SNESDeltaCore', :path => 'Cores/SNESDeltaCore'
    pod 'N64DeltaCore', :path => 'Cores/N64DeltaCore'
    pod 'GBCDeltaCore', :path => 'Cores/GBCDeltaCore'
    pod 'GBADeltaCore', :path => 'Cores/GBADeltaCore'
    pod 'DSDeltaCore', :path => 'Cores/DSDeltaCore'
    pod 'MelonDSDeltaCore', :path => 'Cores/MelonDSDeltaCore'
    pod 'Roxas', :path => 'External/Roxas'
    pod 'Harmony', :path => 'External/Harmony'
    pod 'SteamController'
end

# Unlink DeltaCore to prevent conflicts with Systems.framework
post_install do |installer|
    installer.pods_project.targets.each do |target|
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
