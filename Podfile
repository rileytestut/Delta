platform :ios, '12.0'

inhibit_all_warnings!

target 'Delta' do
    use_modular_headers!

    pod 'SQLite.swift', '~> 0.12.0'
    pod 'SDWebImage', '~> 3.8'
    pod 'Fabric', '~> 1.6.0'
    pod 'Crashlytics', '~> 3.8.0'
    pod 'SMCalloutView'

    pod 'DeltaCore', :path => 'Cores/DeltaCore'
    pod 'NESDeltaCore', :path => 'Cores/NESDeltaCore'
    pod 'SNESDeltaCore', :path => 'Cores/SNESDeltaCore'
    #pod 'N64DeltaCore', :path => 'Cores/N64DeltaCore'
    pod 'GBCDeltaCore', :path => 'Cores/GBCDeltaCore'
    pod 'GBADeltaCore', :path => 'Cores/GBADeltaCore'
    #pod 'DSDeltaCore', :path => 'Cores/DSDeltaCore'
    pod 'MelonDSDeltaCore', :path => 'Cores/MelonDSDeltaCore'
    pod 'Roxas', :path => 'External/Roxas'
    pod 'Harmony', :path => 'External/Harmony'
end

target 'DeltaMac' do
    use_frameworks!

    pod 'SQLite.swift', '~> 0.12.0'
end