ifdef SIMULATOR
TARGET = simulator:clang:11.2:9.0
ARCHS = x86_64
else
TARGET = iphone:clang:11.2:9.0
	ifeq ($(debug),0)
		ARCHS= arm64 arm64e
	else
		ARCHS= arm64 
	endif
endif
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = UnityFPSIndicator

UnityFPSIndicator_FILES = UnityFPSIndicatorRootListController.m BDInfoListController.m BDAppListController.m
UnityFPSIndicator_INSTALL_PATH = /Library/PreferenceBundles
UnityFPSIndicator_FRAMEWORKS = UIKit
UnityFPSIndicator_PRIVATE_FRAMEWORKS = Preferences
UnityFPSIndicator_CFLAGS = -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function
UnityFPSIndicator_LIBRARIES = applist

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/UnityFPSIndicator.plist$(ECHO_END)
