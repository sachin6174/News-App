#!/usr/bin/env ruby
# Wires the NewslyWidget app-extension target into the Xcode project.
#
# The widget source under NewslyWidget/ has existed since the topics release but
# belonged to no target, so it never shipped. This adds the target, embeds it in
# the app, and leaves App Group entitlements alone -- those need the identifier
# registered on the Apple Developer portal first, and attaching them before that
# would break signing for the main app's archive.
#
# Safe to re-run: it exits early if the target already exists.

require "xcodeproj"

PROJECT_PATH = "/Users/sachinkumar/Desktop/News-App/News App.xcodeproj"
TARGET_NAME = "NewslyWidget"
BUNDLE_ID = "in.sachinserver.News-App.NewslyWidget"
SOURCES = %w[
  NewslyWidget.swift
  NewslyWidgetEntry.swift
  NewslyWidgetEntryView.swift
  NewslyWidgetProvider.swift
].freeze

project = Xcodeproj::Project.open(PROJECT_PATH)

if project.targets.any? { |t| t.name == TARGET_NAME }
  puts "SKIP: target #{TARGET_NAME} already exists"
  exit 0
end

app = project.targets.find { |t| t.name == "News App" }
raise "main app target not found" unless app

widget = project.new_target(:app_extension, TARGET_NAME, :ios, "17.0")

# Explicit file references rather than a synchronized folder group: the four
# sources are a fixed set, and an explicit list is what the xcodeproj gem models
# most predictably.
group = project.main_group.new_group(TARGET_NAME, TARGET_NAME)
SOURCES.each do |filename|
  reference = group.new_reference(filename)
  widget.source_build_phase.add_file_reference(reference)
end

# Mirror the app target so the two do not drift apart on version or team.
widget.build_configurations.each do |config|
  config.build_settings.merge!(
    "PRODUCT_BUNDLE_IDENTIFIER" => BUNDLE_ID,
    "PRODUCT_NAME" => "$(TARGET_NAME)",
    "INFOPLIST_FILE" => "#{TARGET_NAME}/Info.plist",
    "GENERATE_INFOPLIST_FILE" => "NO",
    "IPHONEOS_DEPLOYMENT_TARGET" => "17.0",
    "TARGETED_DEVICE_FAMILY" => "1,2",
    "SWIFT_VERSION" => "5.0",
    "SWIFT_EMIT_LOC_STRINGS" => "YES",
    "MARKETING_VERSION" => "1.0",
    "CURRENT_PROJECT_VERSION" => "1",
    "CODE_SIGN_STYLE" => "Automatic",
    "DEVELOPMENT_TEAM" => "M5Q7N9D29M",
    "SKIP_INSTALL" => "YES"
  )
end

# The extension has to be built before the app that carries it, and then copied
# into the app bundle's PlugIns directory -- otherwise it compiles but ships
# nowhere, which is the state this whole change exists to fix.
app.add_dependency(widget)

embed_phase = app.build_phases.find do |phase|
  phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase) &&
    phase.symbol_dst_subfolder_spec == :plug_ins
end

unless embed_phase
  embed_phase = app.new_copy_files_build_phase("Embed Foundation Extensions")
  embed_phase.symbol_dst_subfolder_spec = :plug_ins
  embed_phase.dst_path = ""
end

build_file = embed_phase.add_file_reference(widget.product_reference)
build_file.settings = { "ATTRIBUTES" => ["RemoveHeadersOnCopy"] }

project.save

puts "OK: added #{TARGET_NAME}"
puts "targets now: #{project.targets.map(&:name).join(', ')}"
