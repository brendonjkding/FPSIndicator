BUNDLE_NAME = FPSIndicator

FPSIndicator_FILES = FPSIndicatorRootListController.m BDInfoListController.m
FPSIndicator_INSTALL_PATH = /Library/PreferenceBundles
FPSIndicator_FRAMEWORKS = UIKit
FPSIndicator_PRIVATE_FRAMEWORKS = Preferences
FPSIndicator_CFLAGS = -fobjc-arc -Wno-error=unused-variable -Wno-error=unused-function -include Prefix.pch
FPSIndicator_EXTRA_FRAMEWORKS += AltList

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/FPSIndicator.plist$(ECHO_END)
