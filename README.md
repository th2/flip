# flip

A minimal macOS clipboard stack manager.

| Hotkey | Action |
|---|---|
| `Cmd+Ctrl+C` | Copy the current selection and **push** it onto the stack |
| `Cmd+Ctrl+X` | Cut the current selection and **push** it onto the stack |
| `Cmd+Ctrl+V` | **Pop** the top entry from the stack and paste it |

Entries are stored as plain text in `~/.flip_stack.txt`, one per line (newlines inside a copied string are escaped). The file is deleted automatically when the last entry is popped.

## Requirements

- macOS 13+
- Xcode Command Line Tools (`xcode-select --install`)

## Build

```sh
make
```

This produces `flip.app`.

## Run

```sh
make run        # builds and opens flip.app
# or
open flip.app
```

On first launch macOS will ask to grant **Accessibility** permission to **flip** (not to your terminal). Approve it in System Settings → Privacy & Security → Accessibility, then reopen the app.

## Install system-wide

```sh
make install    # copies flip.app to /Applications
```

To launch automatically on login: System Settings → General → Login Items → add `flip`.

## How it works

flip is packaged as a background app bundle (`LSUIElement = true`) so macOS can uniquely identify it for the Accessibility permission grant — only `flip.app` receives the entitlement, not the terminal it was launched from.

At runtime it registers a `CGEventTap` at the session level to intercept global key events:

- **Cmd+Ctrl+C** — suppresses the hotkey, simulates a plain `Cmd+C` so the focused app copies its selection, waits 150 ms for the pasteboard to update, then appends the text to `~/.flip_stack.txt`.
- **Cmd+Ctrl+X** — same as above but simulates `Cmd+X`, so the selection is deleted from the source after being pushed.
- **Cmd+Ctrl+V** — suppresses the hotkey, reads and removes the first line of `~/.flip_stack.txt`, writes that text to the pasteboard, then simulates `Cmd+V`.

Because multi-line clipboard entries would break the line-per-entry format, embedded newlines are stored as `\n` and unescaped on read.
