# NeoSwitcher

A macOS menu bar utility (Punto Switcher style) that fixes words typed in the wrong keyboard
layout. Type `ghbdtn` in the US layout and it becomes `привет` (and the input source switches to
Russian); type `руддщ` in Russian and it becomes `hello`.

Requires macOS 14+, Apple Silicon, Swift 5.9+. No third-party dependencies.

## How it works
A listen-only event tap records physical key codes (not characters) for the current word. On
space, the word is interpreted in the current layout and in every other enabled layout of a
different language (via `UCKeyTranslate`). If the current reading is not in that language's
dictionary but exactly one other reading is, NeoSwitcher erases the word, switches the input
source and types the corrected text as a Unicode string. Pressing Backspace immediately afterwards
undoes the correction. Detection sits behind the `LayoutScorer` protocol so a character n-gram
model can replace the dictionary lookup later.

Keystrokes live only in memory. Logs contain layout ids and lengths, never typed text, unless you
pass `--debug-content`.

## Setup
1. Enable the layouts you use (System Settings > Keyboard > Input Sources), e.g. U.S. and Russian.
2. Download word lists (one `word` or `word count` per line):
   ```sh
   mkdir -p ~/.config/neoswitcher
   curl -L https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/ru/ru_50k.txt -o ~/.config/neoswitcher/ru.txt
   curl -L https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/en/en_50k.txt -o ~/.config/neoswitcher/en.txt
   ```
   English falls back to `/usr/share/dict/words`; there is no Russian fallback. The file name is
   the layout's language code (`ru.txt`, `en.txt`, ...).
3. Build and sign (below), move `NeoSwitcher.app` to `/Applications`, launch it.

## Permissions
macOS needs two grants (System Settings > Privacy & Security):
- **Input Monitoring**: to see keystrokes (event tap).
- **Accessibility**: to post the correction events.

NeoSwitcher prompts for both and retries the tap every 3 s until granted.

**Security note:** if you run the raw binary from a terminal, macOS attributes the grants to the
*terminal app*, so every process started from that terminal gains keylogging ability. Use the
signed `.app` bundle.

## Build
```sh
CODESIGN_IDENTITY="NeoSwitcher Dev" ./build.sh   # produces NeoSwitcher.app
```
macOS keys TCC grants to the code signature. Ad-hoc signatures (`ALLOW_ADHOC=1 ./build.sh`) change
on every build, so you would have to re-grant permissions each time. Create a stable identity once:
Keychain Access > Certificate Assistant > Create a Certificate… > Name `NeoSwitcher Dev`, Identity
Type *Self Signed Root*, Certificate Type *Code Signing*. Check with
`security find-identity -v -p codesigning`.

"Launch at Login" in the menu uses `SMAppService.mainApp` and only works from the `.app`.

Flags: `--verbose` (decision logging to stderr), `--debug-content` (also logs typed text; off by default).

## Configuration
`~/.config/neoswitcher/config.json` (all keys optional):
```json
{
  "excludedBundleIDs": ["com.apple.Terminal", "com.googlecode.iterm2"],
  "pauseHotkey": { "keyCode": 35, "modifiers": ["ctrl", "opt", "cmd"] },
  "eventDelayMicros": 1500
}
```
`excludedBundleIDs` replaces the defaults (Terminal, iTerm2, Ghostty, 1Password, Bitwarden). Default
pause hotkey: ctrl+opt+cmd+P (the tap is listen-only, so the app in front also receives the combo).
Secure Event Input (password fields) always disables NeoSwitcher.

## Tests
```sh
swift test
```
If it fails with "plugin for module 'TestingMacros' not found" (Command Line Tools only, no Xcode):
```sh
swift test -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```
Translation tests use your real layouts and are skipped if a layout isn't enabled.

## Known limitations
- Typing during a correction interleaves with the synthetic keystrokes; corrections are fast but not atomic.
- Apps with autocomplete/autocorrect may change text before the backspaces land.
- Some apps ignore Unicode-string key events.
- `TISSelectInputSource` can lag in updating the focused app; that's why text is typed as Unicode instead of replaying key codes.
- Words valid in both languages' lists (short ones) never switch.
- Dictionary lookup misses inflected forms absent from the word list (v2: n-gram scorer).
