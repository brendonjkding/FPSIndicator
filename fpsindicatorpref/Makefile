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
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = FPSIndicator

FPSIndicator_FILES = FPSIndicatorRootListController.m BDInfoListController.m BDAppListController.m
FPSIndicator_INSTALL_PATH = /Library/PreferenceBundles
FPSIndicator_FRAMEWORKS = UIKit
FPSIndicator_PRIVATE_FRAMEWORKS = Preferences
FPSIndicator_CFLAGS = -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function -include Prefix.pch
FPSIndicator_LIBRARIES = applist

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/FPSIndicator.plist$(ECHO_END)
