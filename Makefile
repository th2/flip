BINARY  = .build/flip
SOURCE  = Sources/flip/main.swift
APP     = flip.app
ICNS    = Resources/AppIcon.icns
SWIFTC  = swiftc -Xcc -Wno-module-import-in-extern-c -O

# -Xcc -Wno-module-import-in-extern-c works around a duplicate SwiftBridging
# module definition present in some Command Line Tools configurations.

.PHONY: all app run install clean

all: app

$(BINARY): $(SOURCE)
	@mkdir -p .build
	$(SWIFTC) -o $(BINARY) $(SOURCE) -framework Cocoa

$(ICNS): Sources/flip/icon.svg scripts/make_icons.swift
	@echo "Generating app icon..."
	@mkdir -p .build/AppIcon.iconset .build/iconscript
	$(SWIFTC) -o .build/iconscript/make_icons scripts/make_icons.swift -framework Cocoa
	.build/iconscript/make_icons Sources/flip/icon.svg .build/AppIcon.iconset
	iconutil -c icns .build/AppIcon.iconset -o $(ICNS)
	@rm -rf .build/AppIcon.iconset .build/iconscript
	@echo "Done → $(ICNS)"

app: $(BINARY) $(ICNS)
	@mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp $(BINARY)             $(APP)/Contents/MacOS/flip
	cp Resources/Info.plist  $(APP)/Contents/Info.plist
	cp $(ICNS)               $(APP)/Contents/Resources/AppIcon.icns
	@echo "Built $(APP) — run with: open $(APP)"

run: app
	open $(APP)

install: app
	cp -r $(APP) /Applications/flip.app
	@echo "Installed to /Applications/flip.app"
	@echo "Add it to Login Items in System Settings to launch on login."

clean:
	rm -rf .build $(APP) $(ICNS)
