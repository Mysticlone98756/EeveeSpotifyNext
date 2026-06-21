TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Spotify
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = EeveeSpotify

EeveeSpotify_FILES = $(shell find Sources/EeveeSpotify -name '*.swift') $(shell find Sources/EeveeSpotifyC -name '*.m' -o -name '*.c' -o -name '*.mm' -o -name '*.cpp')
EeveeSpotify_SWIFTFLAGS = -ISources/EeveeSpotifyC/include -Osize
EeveeSpotify_EXTRA_FRAMEWORKS = SwiftProtobuf
EeveeSpotify_CFLAGS = -fobjc-arc -ISources/EeveeSpotifyC/include -Os

include $(THEOS_MAKE_PATH)/tweak.mk

internal-stage::
	# Bundle SwiftProtobuf.framework directly into the package
	# This allows the DEB to work without external SwiftProtobuf installation
	mkdir -p $(THEOS_STAGING_DIR)/Library/Frameworks
	cp -r $(THEOS)/lib/iphone/rootless/SwiftProtobuf.framework $(THEOS_STAGING_DIR)/Library/Frameworks/

# Legacy build step (no longer needed, kept for reference)
copy-swiftprotobuf:
	mkdir -p swiftprotobuf && cd swiftprotobuf ;\
	curl -OL https://github.com/whoeevee/EeveeSpotify/releases/download/swift2.0/org.swift.protobuf.swiftprotobuf_1.26.0_iphoneos-arm.deb ;\
	ar -x org.swift.protobuf.swiftprotobuf_1.26.0_iphoneos-arm.deb ;\
	tar -xvf data.tar.lzma ;\
	cp -r Library/Frameworks/SwiftProtobuf.framework "${THEOS}/lib" ;\

# After each `make package`, also drop the tweak's raw .dylib (extracted from the
# just-built .deb) next to it in packages/, named after the .deb.
after-package::
	@deb=$$(ls -t packages/*.deb 2>/dev/null | head -1) ;\
	if [ -n "$$deb" ] && [ -f "$$deb" ]; then \
		out="$${deb%.deb}.dylib" ;\
		tmp=$$(mktemp -d) ;\
		( cd "$$tmp" && ar -x "$(CURDIR)/$$deb" && { tar --lzma -xf data.tar.* 2>/dev/null || tar -xf data.tar.* ; } ) ;\
		dy=$$(find "$$tmp" -name 'EeveeSpotify.dylib' -path '*DynamicLibraries*' | head -1) ;\
		if [ -n "$$dy" ]; then cp "$$dy" "$$out" ; echo "==> Extracted dylib -> $$out" ;\
		else echo "warning: EeveeSpotify.dylib not found inside $$deb" ; fi ;\
		rm -rf "$$tmp" ;\
	fi
