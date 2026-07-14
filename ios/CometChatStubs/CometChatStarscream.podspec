Pod::Spec.new do |s|
  s.name         = 'CometChatStarscream'
  s.version      = '1.0.2'
  s.summary      = 'CometChat\'s Starscream WebSocket framework (transitive runtime dependency).'
  s.description  = <<-DESC
    CometChatSDK 4.x links against a separate CometChatStarscream framework at
    runtime (its WebSocket transport) but the CometChatUIKitSwift / CometChatSDK
    podspecs do NOT declare it as a dependency. Without it the app builds clean
    yet crashes at launch — first with "Library not loaded: @rpath/
    CometChatStarscream.framework" and then, once a bare stub is present, with
    "Symbol not found: CometChatStarscream.WebSocketEvent.disconnected"
    referenced from CometChatSDK (gotcha I7 — its "statically linked" premise
    does not hold for this SDK version). This declares the real framework as an
    explicit pod, fetched from CometChat's official CDN (same mechanism the other
    CometChat pods use), so the symbols exist at runtime.
  DESC
  s.homepage     = 'https://www.cometchat.com'
  s.license      = { :type => 'Commercial', :text => 'CometChat SDK component.' }
  s.author       = 'CometChat'
  s.platform     = :ios, '13.0'
  s.source       = { :http => 'https://library.cometchat.io/ios/v4.0/xcode15/CometChatStarscream_1_0_2.xcframework.zip' }
  s.vendored_frameworks = 'CometChatStarscream.xcframework'
end
