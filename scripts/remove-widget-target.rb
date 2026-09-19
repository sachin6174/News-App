#!/usr/bin/env ruby
# Removes the NewslyWidget extension target from the Xcode project.
#
# The widget cannot do anything useful in this release: its App Group is not
# registered on the Apple Developer portal, so it would always render its
# placeholder. Its bundle ID also has no App ID on the portal, which blocks
# automatic signing during a headless archive.
#
# This is deliberately a separate, revertible commit on a release branch --
# scripts/add-widget-target.rb puts it back once the portal side exists.

require "xcodeproj"

PROJECT_PATH = "/Users/sachinkumar/Desktop/News-App/News App.xcodeproj"
TARGET_NAME = "NewslyWidget"

project = Xcodeproj::Project.open(PROJECT_PATH)
widget = project.targets.find { |t| t.name == TARGET_NAME }

unless widget
  puts "SKIP: #{TARGET_NAME} is not in the project"
  exit 0
end

app = project.targets.find { |t| t.name == "News App" }
raise "main app target not found" unless app

# Drop the embed-extension build file first, otherwise the copy phase keeps a
# dangling reference to a product that no longer exists.
app.build_phases.each do |phase|
  next unless phase.is_a?(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  phase.files.dup.each do |build_file|
    next unless build_file.file_ref == widget.product_reference
    puts "removing embed entry from '#{phase.name}'"
    build_file.remove_from_project
  end
end

app.dependencies.dup.each do |dependency|
  next unless dependency.target == widget
  puts "removing target dependency"
  dependency.remove_from_project
end

group = project.main_group.children.find { |c| c.display_name == TARGET_NAME }
group&.remove_from_project

widget.remove_from_project
project.save

puts "OK: removed #{TARGET_NAME}"
puts "targets now: #{project.targets.map(&:name).join(', ')}"
