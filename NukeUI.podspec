Pod::Spec.new do |s|
    s.name             = 'NukeUI'
    s.version          = '0.6.7'
    s.summary          = 'A powerful image loading and caching system'
    s.description  = <<-EOS
    A powerful image loading and caching system which makes simple tasks like loading images into views extremely simple, while also supporting more advanced features for more demanding apps.
    EOS

    s.homepage         = 'https://github.com/kean/NukeUI'
    s.license          = 'MIT'
    s.author           = 'Alexander Grebenyuk'
    s.social_media_url = 'https://twitter.com/a_grebenyuk'
    s.source           = { :git => 'https://github.com/kean/NukeUI.git', :tag => s.version.to_s }

    s.swift_versions = ['5.1', '5.2', '5.3', '5.4']

    s.ios.deployment_target = '12.0'
    s.macos.deployment_target = '10.14'
    s.tvos.deployment_target = '12.0'
    s.watchos.deployment_target = '5.0'

    s.source_files  = 'Sources/**/*'

    s.dependency 'Nuke', '~> 10.3'
    s.ios.dependency 'Gifu', '~> 3.0'
    s.tvos.dependency 'Gifu', '~> 3.0'
end
