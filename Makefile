ifdef SIMULATOR
TARGET = simulator:clang:11.2:8.0
ARCHS = x86_64
else
TARGET = iphone:clang:11.2:7.0
	ifeq ($(debug),0)
		ARCHS= armv7 arm64 arm64e
	else
		ARCHS= arm64 
	endif
endif

TWEAK_NAME = FPSIndicator

FPSIndicator_FILES = Tweak.x
FPSIndicator_CFLAGS = -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function -include Prefix.pch
FPSIndicator_LIBRARIES = colorpicker


SUBPROJECTS += fpsindicatorpref
include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 fatego" ||true
	install.exec "killall -9 Preferences" ||true

ifdef SIMULATOR
include $(THEOS)/makefiles/locatesim.mk
BUNDLE_NAME = FPSIndicator
PREF_FOLDER_NAME = fpsindicatorpref
endif

setup:: all
	@rm -f /opt/simject/$(TWEAK_NAME).dylib
	@cp -v $(THEOS_OBJ_DIR)/$(TWEAK_NAME).dylib /opt/simject/$(TWEAK_NAME).dylib
	@codesign -f -s - /opt/simject/$(TWEAK_NAME).dylib
	@cp -v $(PWD)/$(TWEAK_NAME).plist /opt/simject
	@sudo cp -v $(PWD)/$(PREF_FOLDER_NAME)/entry.plist $(PL_SIMULATOR_PLISTS_PATH)/$(BUNDLE_NAME).plist
	@sudo cp -vR $(THEOS_OBJ_DIR)/$(BUNDLE_NAME).bundle $(PL_SIMULATOR_BUNDLES_PATH)/
	@sudo codesign -f -s - $(PL_SIMULATOR_BUNDLES_PATH)/$(BUNDLE_NAME).bundle/$(BUNDLE_NAME)
	@resim

remove::
	@rm -f /opt/simject/$(TWEAK_NAME).dylib /opt/simject/$(TWEAK_NAME).plist
	@sudo rm -r $(PL_SIMULATOR_BUNDLES_PATH)/$(BUNDLE_NAME).bundle
	@sudo rm $(PL_SIMULATOR_PLISTS_PATH)/$(BUNDLE_NAME).plist
	@resim

