#
# Be sure to run `pod lib lint SectionDataSource.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SectionDataSource'
  s.version          = '0.12.1'
  s.summary          = 'Data source for working with items which should be split into sections'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  Data source implementation which helps working with splitting items to sections.
  Supports filtering, searching and limiting. Supports NSFetchedResultsController.
                       DESC

  s.homepage         = 'https://bitbucket.org/mmulyar/sectiondatasource'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'mikhailmulyar' => 'mulyarm@gmail.com' }
  s.source           = { :git => 'https://bitbucket.org/mmulyar/sectiondatasource.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'
  s.swift_version = '5.0'

  s.source_files = 'SectionDataSource/Classes/**/*'
  
  # s.resource_bundles = {
  #   'SectionDataSource' => ['SectionDataSource/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  
  s.dependency 'DifferenceKit/UIKitExtension'
end
