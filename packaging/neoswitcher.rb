# typed: strict
# frozen_string_literal: true

# Copy to lestex/homebrew-tap as Casks/neoswitcher.rb. The release workflow
# rewrites the `version` and `sha256` lines on every tag.
cask "neoswitcher" do
  version "0.1.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/lestex/neoswitcher/releases/download/v#{version}/NeoSwitcher-v#{version}.dmg"
  name "NeoSwitcher"
  desc "Fixes words typed in the wrong keyboard layout"
  homepage "https://github.com/lestex/neoswitcher"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "NeoSwitcher.app"

  zap trash: [
    "~/.config/neoswitcher",
    "~/Library/Preferences/com.lestex.neoswitcher.plist",
  ]
end
