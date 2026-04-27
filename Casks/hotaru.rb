# frozen_string_literal: true

cask "hotaru" do
  version "1.0.0"
  sha256 "ed9db27e4479d0ebbe6d53b09b56516424d1a8884216ca0b249d5f96bf49c877"

  url "https://github.com/mei28/Hotaru/releases/download/v#{version}/Hotaru-#{version}.zip"
  name "Hotaru"
  desc "Menu bar app that draws a colored border around the active window"
  homepage "https://github.com/mei28/Hotaru"

  # macOS 26 Tahoe or later, Apple Silicon only.
  depends_on macos: ">= :tahoe"
  depends_on arch: :arm64

  app "Hotaru.app"

  # Hotaru is unsigned; Homebrew strips the quarantine attribute automatically.
  # On first launch, grant Accessibility permission in System Settings.

  zap trash: [
    "~/Library/Caches/com.waddlier.Hotaru",
    "~/Library/Preferences/com.waddlier.Hotaru.plist",
    "~/Library/Saved Application State/com.waddlier.Hotaru.savedState",
  ]
end
