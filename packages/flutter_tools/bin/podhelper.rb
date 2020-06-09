# Copyright 2014 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Add iOS build settings to pod targets.
#
# @example
# post_install do |installer|
#   installer.pods_project.targets.each do |target|
#     target.build_configurations.each do |config|
#       flutter_additional_ios_build_settings(config)
#     end
#   end
# end
# @param [XCBuildConfiguration] build_configuration Build configuration for Pod target.
def flutter_additional_ios_build_settings(build_configuration)
  build_configuration.build_settings['ENABLE_BITCODE'] = 'NO'
end

# Install pods needed to embed Flutter iOS engine and plugins.
#
# @example
#   target 'Runner' do
#     flutter_install_all_ios_pods
#   end
# @param [String] ios_application_path Path of the iOS directory of the Flutter app.
#                                      Optional, defaults to the Podfile directory.
def flutter_install_all_ios_pods(ios_application_path = nil)
  flutter_install_ios_engine_pod(ios_application_path)
  flutter_install_ios_plugin_pods(ios_application_path)
end

# Install iOS Flutter engine pod.
#
# @example
#   target 'Runner' do
#     flutter_install_ios_engine_pod
#   end
# @param [String] ios_application_path Path of the iOS directory of the Flutter app.
#                                      Optional, defaults to the Podfile directory.
def flutter_install_ios_engine_pod(ios_application_path = nil)
  # defined_in_file is set by CocoaPods and is a Pathname to the Podfile.
  ios_application_path ||= File.dirname(defined_in_file.realpath) if self.respond_to?(:defined_in_file)
  raise 'Could not find iOS application path.' unless ios_application_path

  copied_flutter_dir = File.join(ios_application_path, 'Flutter')
  copied_framework_path = File.join(copied_flutter_dir, 'Flutter.framework')
  copied_podspec_path = File.join(copied_flutter_dir, 'Flutter.podspec')

  unless File.exist?(copied_framework_path) && File.exist?(copied_podspec_path)
    # Copy Flutter.framework and Flutter.podspec to Flutter/ to have something to link against if the xcode backend script has not run yet.
    # That script will copy the correct debug/profile/release version of the framework based on the currently selected Xcode configuration,
    # which can handle a local engine.
    # CocoaPods will not embed the framework on pod install (before any build phases can generate) if the dylib does not exist.

    # This podhelper script is at $FLUTTER_ROOT/packages/flutter_tools/bin.
    # Copy frameworks from $FLUTTER_ROOT/bin/cache/artifacts/engine/ios (Debug).
    debug_framework_dir = File.expand_path(File.join('..', '..', '..', '..', 'bin', 'cache', 'artifacts', 'engine', 'ios'), __FILE__)

    unless File.exist?(copied_framework_path)
      # Avoid the complication of dependencies like FileUtils.
      system('cp', '-r', File.expand_path('Flutter.framework', debug_framework_dir), copied_flutter_dir)
    end
    unless File.exist?(copied_podspec_path)
      system('cp', File.expand_path('Flutter.podspec', debug_framework_dir), copied_flutter_dir)
    end
  end

  # Keep pod path relative so it can be checked into Podfile.lock.
  pod 'Flutter', :path => 'Flutter'
end

# Install iOS Flutter plugin pods.
#
# @example
#   target 'Runner' do
#     flutter_install_ios_plugin_pods
#   end
# @param [String] ios_application_path Path of the iOS directory of the Flutter app.
#                                      Optional, defaults to the Podfile directory.
def flutter_install_ios_plugin_pods(ios_application_path = nil)
  # defined_in_file is set by CocoaPods and is a Pathname to the Podfile.
  ios_application_path ||= File.dirname(defined_in_file.realpath) if self.respond_to?(:defined_in_file)
  raise 'Could not find iOS application path.' unless ios_application_path

  # Prepare symlinks folder. We use symlinks to avoid having Podfile.lock
  # referring to absolute paths on developers' machines.

  symlink_dir = File.expand_path('.symlinks', ios_application_path)
  system('rm', '-rf', symlink_dir) # Avoid the complication of dependencies like FileUtils.

  symlink_plugins_dir = File.expand_path('plugins', symlink_dir)
  system('mkdir', '-p', symlink_plugins_dir)

  plugins_file = File.join(ios_application_path, '..', '.flutter-plugins')
  plugin_pods = flutter_parse_plugins_file(plugins_file)
  plugin_pods.each do |name, path|
    symlink = File.join(symlink_plugins_dir, name)
    File.symlink(path, symlink)

    # Keep pod path relative so it can be checked into Podfile.lock.
    pod name, :path => File.join('.symlinks', 'plugins', name, 'ios')
  end
end

def flutter_parse_plugins_file(file)
  file_path = File.expand_path(file)
  unless File.exists? file_path
    return [];
  end
  generated_key_values = {}
  skip_line_start_symbols = ["#", "/"]
  File.foreach(file_path) do |line|
    next if skip_line_start_symbols.any? { |symbol| line =~ /^\s*#{symbol}/ }
    plugin = line.split('=')
    if plugin.length == 2
      podname = plugin[0].strip
      path = plugin[1].strip
      podpath = File.expand_path(path, file_path)
      generated_key_values[podname] = File.expand_path(path, file_path)
    else
      puts "Invalid plugin specification: #{line}"
    end
  end
  generated_key_values
end
