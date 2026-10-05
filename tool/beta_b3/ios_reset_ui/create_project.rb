# Generates an isolated UI-only project; never changes Runner or dependency setup.
require 'xcodeproj'
require 'fileutils'
path, source = ARGV
abort 'New output project required' if File.exist?(path)
p = Xcodeproj::Project.new(path)
t = p.new_target(:ui_test_bundle, 'RecoveryUI', :ios, '16.4')
f = p.main_group.new_file(File.expand_path(source))
t.source_build_phase.add_file_reference(f)
t.build_configurations.each do |c|
 c.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'ai.emiso.emie.local-recovery-uitests'
 c.build_settings['SWIFT_VERSION'] = '5.0'
 c.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
 c.build_settings['CODE_SIGN_IDENTITY'] = '-'
 c.build_settings['CODE_SIGNING_ALLOWED'] = 'YES'
 c.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
end
p.save
s = Xcodeproj::XCScheme.new
s.add_build_target(t)
s.add_test_target(t)
s.test_action.build_configuration = 'Debug'
s.save_as(path, 'RecoveryUI', true)
