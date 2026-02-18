BINARY  = .build/flip
SOURCE  = Sources/flip/main.swift
APP     = flip.app
SWIFTC  = swiftc -Xcc -Wno-module-import-in-extern-c -O

# -Xcc -Wno-module-import-in-extern-c works around a duplicate SwiftBridging
# module definition present in some Command Line Tools configurations.

.PHONY: all app run install clean

all: app

$(BINARY): $(SOURCE)
	@mkdir -p .build
	$(SWIFTC) -o $(BINARY) $(SOURCE) -framework Cocoa

app: $(BINARY)
	@mkdir -p $(APP)/Contents/MacOS
	cp $(BINARY)           $(APP)/Contents/MacOS/flip
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	@echo "Built $(APP) — run with: open $(APP)"

run: app
	open $(APP)

install: app
	cp -r $(APP) /Applications/flip.app
	@echo "Installed to /Applications/flip.app"
	@echo "Add it to Login Items in System Settings to launch on login."

clean:
	rm -rf .build $(APP)
