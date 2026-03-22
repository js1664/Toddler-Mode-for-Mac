#!/usr/bin/env python3
"""Generate ToddlerLock.xcodeproj/project.pbxproj"""

import os
import hashlib
import uuid

def make_id(name):
    """Generate a deterministic 24-char hex ID from a name."""
    return hashlib.md5(name.encode()).hexdigest()[:24].upper()

# All source files relative to ToddlerLock/
sources = [
    ("App/main.swift", "main.swift"),
    ("App/AppDelegate.swift", "AppDelegate.swift"),
    ("InputBlocking/EventTapManager.swift", "EventTapManager.swift"),
    ("InputBlocking/ExitShortcutDetector.swift", "ExitShortcutDetector.swift"),
    ("InputBlocking/InputEvent.swift", "InputEvent.swift"),
    ("InputBlocking/InputEventBus.swift", "InputEventBus.swift"),
    ("InputBlocking/PresentationManager.swift", "PresentationManager.swift"),
    ("Lifecycle/LifecycleManager.swift", "LifecycleManager.swift"),
    ("LockScreen/CursorManager.swift", "CursorManager.swift"),
    ("LockScreen/LockViewController.swift", "LockViewController.swift"),
    ("LockScreen/LockWindowController.swift", "LockWindowController.swift"),
    ("LockScreen/PasswordOverlayView.swift", "PasswordOverlayView.swift"),
    ("Effects/SoundManager.swift", "SoundManager.swift"),
    ("Modes/FreePlayMode.swift", "FreePlayMode.swift"),
    ("Modes/GameMode.swift", "GameMode.swift"),
    ("Modes/CharacterMode.swift", "CharacterMode.swift"),
    ("Modes/ModeProtocol.swift", "ModeProtocol.swift"),
    ("Permissions/PermissionChecker.swift", "PermissionChecker.swift"),
    ("Settings/KeychainManager.swift", "KeychainManager.swift"),
    ("Settings/ShortcutRecorderView.swift", "ShortcutRecorderView.swift"),
    ("Settings/SettingsStore.swift", "SettingsStore.swift"),
    ("Settings/SettingsView.swift", "SettingsView.swift"),
]

# Groups
groups = {
    "App": ["App/main.swift", "App/AppDelegate.swift"],
    "InputBlocking": [
        "InputBlocking/EventTapManager.swift",
        "InputBlocking/ExitShortcutDetector.swift",
        "InputBlocking/InputEvent.swift",
        "InputBlocking/InputEventBus.swift",
        "InputBlocking/PresentationManager.swift",
    ],
    "Effects": ["Effects/SoundManager.swift"],
    "Lifecycle": ["Lifecycle/LifecycleManager.swift"],
    "LockScreen": [
        "LockScreen/CursorManager.swift",
        "LockScreen/LockViewController.swift",
        "LockScreen/LockWindowController.swift",
        "LockScreen/PasswordOverlayView.swift",
    ],
    "Modes": ["Modes/FreePlayMode.swift", "Modes/GameMode.swift", "Modes/CharacterMode.swift", "Modes/ModeProtocol.swift"],
    "Permissions": ["Permissions/PermissionChecker.swift"],
    "Settings": ["Settings/KeychainManager.swift", "Settings/ShortcutRecorderView.swift", "Settings/SettingsStore.swift", "Settings/SettingsView.swift"],
}

# IDs
PROJECT_ID = make_id("project")
MAIN_GROUP_ID = make_id("mainGroup")
SOURCE_GROUP_ID = make_id("sourceGroup")
PRODUCTS_GROUP_ID = make_id("productsGroup")
FRAMEWORKS_GROUP_ID = make_id("frameworksGroup")
TARGET_ID = make_id("target")
BUILD_CONFIG_LIST_PROJECT = make_id("buildConfigListProject")
BUILD_CONFIG_LIST_TARGET = make_id("buildConfigListTarget")
DEBUG_CONFIG_PROJECT = make_id("debugConfigProject")
RELEASE_CONFIG_PROJECT = make_id("releaseConfigProject")
DEBUG_CONFIG_TARGET = make_id("debugConfigTarget")
RELEASE_CONFIG_TARGET = make_id("releaseConfigTarget")
SOURCES_PHASE_ID = make_id("sourcesPhase")
FRAMEWORKS_PHASE_ID = make_id("frameworksPhase")
PRODUCT_REF_ID = make_id("productRef")
INFO_PLIST_FILE_REF = make_id("infoPlist")
ENTITLEMENTS_FILE_REF = make_id("entitlements")

# Framework references
frameworks = {
    "AppKit.framework": make_id("fw_appkit"),
    "SpriteKit.framework": make_id("fw_spritekit"),
    "CoreGraphics.framework": make_id("fw_coregraphics"),
    "AVFoundation.framework": make_id("fw_avfoundation"),
    "Security.framework": make_id("fw_security"),
}
fw_build_refs = {name: make_id("fwbuild_" + name) for name in frameworks}

def gen():
    lines = []
    a = lines.append

    a('// !$*UTF8*$!')
    a('{')
    a('\tarchiveVersion = 1;')
    a('\tclasses = {')
    a('\t};')
    a('\tobjectVersion = 56;')
    a('\tobjects = {')
    a('')

    # PBXBuildFile section
    a('/* Begin PBXBuildFile section */')
    for path, name in sources:
        fid = make_id("build_" + path)
        ref = make_id("ref_" + path)
        a(f'\t\t{fid} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};')
    for fw_name, fw_id in frameworks.items():
        build_id = fw_build_refs[fw_name]
        a(f'\t\t{build_id} /* {fw_name} in Frameworks */ = {{isa = PBXBuildFile; fileRef = {fw_id} /* {fw_name} */; }};')
    a('/* End PBXBuildFile section */')
    a('')

    # PBXFileReference section
    a('/* Begin PBXFileReference section */')
    for path, name in sources:
        ref = make_id("ref_" + path)
        a(f'\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = "<group>"; }};')
    a(f'\t\t{INFO_PLIST_FILE_REF} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "App/Info.plist"; sourceTree = "<group>"; }};')
    a(f'\t\t{ENTITLEMENTS_FILE_REF} /* ToddlerLock.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = "App/ToddlerLock.entitlements"; sourceTree = "<group>"; }};')
    a(f'\t\t{PRODUCT_REF_ID} /* ToddlerLock.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ToddlerLock.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
    for fw_name, fw_id in frameworks.items():
        a(f'\t\t{fw_id} /* {fw_name} */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = {fw_name}; path = System/Library/Frameworks/{fw_name}; sourceTree = SDKROOT; }};')
    a('/* End PBXFileReference section */')
    a('')

    # PBXGroup section
    a('/* Begin PBXGroup section */')

    # Main group
    a(f'\t\t{MAIN_GROUP_ID} = {{')
    a('\t\t\tisa = PBXGroup;')
    a('\t\t\tchildren = (')
    a(f'\t\t\t\t{SOURCE_GROUP_ID} /* ToddlerLock */,')
    a(f'\t\t\t\t{FRAMEWORKS_GROUP_ID} /* Frameworks */,')
    a(f'\t\t\t\t{PRODUCTS_GROUP_ID} /* Products */,')
    a('\t\t\t);')
    a('\t\t\tsourceTree = "<group>";')
    a('\t\t};')

    # Products group
    a(f'\t\t{PRODUCTS_GROUP_ID} /* Products */ = {{')
    a('\t\t\tisa = PBXGroup;')
    a('\t\t\tchildren = (')
    a(f'\t\t\t\t{PRODUCT_REF_ID} /* ToddlerLock.app */,')
    a('\t\t\t);')
    a('\t\t\tname = Products;')
    a('\t\t\tsourceTree = "<group>";')
    a('\t\t};')

    # Frameworks group
    a(f'\t\t{FRAMEWORKS_GROUP_ID} /* Frameworks */ = {{')
    a('\t\t\tisa = PBXGroup;')
    a('\t\t\tchildren = (')
    for fw_name, fw_id in frameworks.items():
        a(f'\t\t\t\t{fw_id} /* {fw_name} */,')
    a('\t\t\t);')
    a('\t\t\tname = Frameworks;')
    a('\t\t\tsourceTree = "<group>";')
    a('\t\t};')

    # Source group (ToddlerLock/)
    group_ids = {g: make_id("group_" + g) for g in groups}
    a(f'\t\t{SOURCE_GROUP_ID} /* ToddlerLock */ = {{')
    a('\t\t\tisa = PBXGroup;')
    a('\t\t\tchildren = (')
    for g in groups:
        a(f'\t\t\t\t{group_ids[g]} /* {g} */,')
    a(f'\t\t\t\t{INFO_PLIST_FILE_REF} /* Info.plist */,')
    a(f'\t\t\t\t{ENTITLEMENTS_FILE_REF} /* ToddlerLock.entitlements */,')
    a('\t\t\t);')
    a('\t\t\tpath = ToddlerLock;')
    a('\t\t\tsourceTree = "<group>";')
    a('\t\t};')

    # Sub-groups
    for g, files in groups.items():
        gid = group_ids[g]
        a(f'\t\t{gid} /* {g} */ = {{')
        a('\t\t\tisa = PBXGroup;')
        a('\t\t\tchildren = (')
        for f in files:
            ref = make_id("ref_" + f)
            name = f.split("/")[-1]
            a(f'\t\t\t\t{ref} /* {name} */,')
        a('\t\t\t);')
        a(f'\t\t\tname = {g};')
        a('\t\t\tsourceTree = "<group>";')
        a('\t\t};')

    a('/* End PBXGroup section */')
    a('')

    # PBXNativeTarget
    a('/* Begin PBXNativeTarget section */')
    a(f'\t\t{TARGET_ID} /* ToddlerLock */ = {{')
    a('\t\t\tisa = PBXNativeTarget;')
    a(f'\t\t\tbuildConfigurationList = {BUILD_CONFIG_LIST_TARGET};')
    a('\t\t\tbuildPhases = (')
    a(f'\t\t\t\t{SOURCES_PHASE_ID} /* Sources */,')
    a(f'\t\t\t\t{FRAMEWORKS_PHASE_ID} /* Frameworks */,')
    a('\t\t\t);')
    a('\t\t\tbuildRules = (')
    a('\t\t\t);')
    a('\t\t\tdependencies = (')
    a('\t\t\t);')
    a('\t\t\tname = ToddlerLock;')
    a(f'\t\t\tproductName = ToddlerLock;')
    a(f'\t\t\tproductReference = {PRODUCT_REF_ID} /* ToddlerLock.app */;')
    a('\t\t\tproductType = "com.apple.product-type.application";')
    a('\t\t};')
    a('/* End PBXNativeTarget section */')
    a('')

    # PBXProject
    a('/* Begin PBXProject section */')
    a(f'\t\t{PROJECT_ID} /* Project object */ = {{')
    a('\t\t\tisa = PBXProject;')
    a(f'\t\t\tbuildConfigurationList = {BUILD_CONFIG_LIST_PROJECT};')
    a('\t\t\tcompatibilityVersion = "Xcode 14.0";')
    a('\t\t\tdevelopmentRegion = en;')
    a('\t\t\thasScannedForEncodings = 0;')
    a('\t\t\tknownRegions = (')
    a('\t\t\t\ten,')
    a('\t\t\t\tBase,')
    a('\t\t\t);')
    a(f'\t\t\tmainGroup = {MAIN_GROUP_ID};')
    a(f'\t\t\tproductRefGroup = {PRODUCTS_GROUP_ID} /* Products */;')
    a('\t\t\tprojectDirPath = "";')
    a('\t\t\tprojectRoot = "";')
    a('\t\t\ttargets = (')
    a(f'\t\t\t\t{TARGET_ID} /* ToddlerLock */,')
    a('\t\t\t);')
    a('\t\t};')
    a('/* End PBXProject section */')
    a('')

    # PBXSourcesBuildPhase
    a('/* Begin PBXSourcesBuildPhase section */')
    a(f'\t\t{SOURCES_PHASE_ID} /* Sources */ = {{')
    a('\t\t\tisa = PBXSourcesBuildPhase;')
    a('\t\t\tbuildActionMask = 2147483647;')
    a('\t\t\tfiles = (')
    for path, name in sources:
        fid = make_id("build_" + path)
        a(f'\t\t\t\t{fid} /* {name} in Sources */,')
    a('\t\t\t);')
    a('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
    a('\t\t};')
    a('/* End PBXSourcesBuildPhase section */')
    a('')

    # PBXFrameworksBuildPhase
    a('/* Begin PBXFrameworksBuildPhase section */')
    a(f'\t\t{FRAMEWORKS_PHASE_ID} /* Frameworks */ = {{')
    a('\t\t\tisa = PBXFrameworksBuildPhase;')
    a('\t\t\tbuildActionMask = 2147483647;')
    a('\t\t\tfiles = (')
    for fw_name in frameworks:
        build_id = fw_build_refs[fw_name]
        a(f'\t\t\t\t{build_id} /* {fw_name} in Frameworks */,')
    a('\t\t\t);')
    a('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
    a('\t\t};')
    a('/* End PBXFrameworksBuildPhase section */')
    a('')

    # XCBuildConfiguration section
    a('/* Begin XCBuildConfiguration section */')

    # Project-level Debug
    a(f'\t\t{DEBUG_CONFIG_PROJECT} /* Debug */ = {{')
    a('\t\t\tisa = XCBuildConfiguration;')
    a('\t\t\tbuildSettings = {')
    a('\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;')
    a('\t\t\t\tCLANG_ANALYZER_NONNULL = YES;')
    a('\t\t\t\tCLANG_ENABLE_MODULES = YES;')
    a('\t\t\t\tCOPY_PHASE_STRIP = NO;')
    a('\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;')
    a('\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;')
    a('\t\t\t\tENABLE_TESTABILITY = YES;')
    a('\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;')
    a('\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;')
    a('\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (')
    a('\t\t\t\t\t"DEBUG=1",')
    a('\t\t\t\t\t"$(inherited)",')
    a('\t\t\t\t);')
    a('\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.0;')
    a('\t\t\t\tONLY_ACTIVE_ARCH = YES;')
    a('\t\t\t\tSDKROOT = macosx;')
    a('\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;')
    a('\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";')
    a('\t\t\t};')
    a('\t\t\tname = Debug;')
    a('\t\t};')

    # Project-level Release
    a(f'\t\t{RELEASE_CONFIG_PROJECT} /* Release */ = {{')
    a('\t\t\tisa = XCBuildConfiguration;')
    a('\t\t\tbuildSettings = {')
    a('\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;')
    a('\t\t\t\tCLANG_ANALYZER_NONNULL = YES;')
    a('\t\t\t\tCLANG_ENABLE_MODULES = YES;')
    a('\t\t\t\tCOPY_PHASE_STRIP = NO;')
    a('\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";')
    a('\t\t\t\tENABLE_NS_ASSERTIONS = NO;')
    a('\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;')
    a('\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.0;')
    a('\t\t\t\tSDKROOT = macosx;')
    a('\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;')
    a('\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";')
    a('\t\t\t};')
    a('\t\t\tname = Release;')
    a('\t\t};')

    # Target-level Debug
    a(f'\t\t{DEBUG_CONFIG_TARGET} /* Debug */ = {{')
    a('\t\t\tisa = XCBuildConfiguration;')
    a('\t\t\tbuildSettings = {')
    # a('\t\t\t\tCODE_SIGN_ENTITLEMENTS = ToddlerLock/App/ToddlerLock.entitlements;')
    a('\t\t\t\tCODE_SIGN_STYLE = Automatic;')
    a('\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;')
    a('\t\t\t\tDEVELOPMENT_TEAM = 44CHGH7YRS;')
    a('\t\t\t\tENABLE_HARDENED_RUNTIME = YES;')
    a('\t\t\t\tINFOPLIST_FILE = ToddlerLock/App/Info.plist;')
    a('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (')
    a('\t\t\t\t\t"$(inherited)",')
    a('\t\t\t\t\t"@executable_path/../Frameworks",')
    a('\t\t\t\t);')
    a('\t\t\t\tMARKETING_VERSION = 1.0;')
    a('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.toddlerlock.app;')
    a('\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
    a('\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;')
    a('\t\t\t\tSWIFT_VERSION = 5.0;')
    a('\t\t\t};')
    a('\t\t\tname = Debug;')
    a('\t\t};')

    # Target-level Release
    a(f'\t\t{RELEASE_CONFIG_TARGET} /* Release */ = {{')
    a('\t\t\tisa = XCBuildConfiguration;')
    a('\t\t\tbuildSettings = {')
    # a('\t\t\t\tCODE_SIGN_ENTITLEMENTS = ToddlerLock/App/ToddlerLock.entitlements;')
    a('\t\t\t\tCODE_SIGN_STYLE = Automatic;')
    a('\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;')
    a('\t\t\t\tDEVELOPMENT_TEAM = 44CHGH7YRS;')
    a('\t\t\t\tENABLE_HARDENED_RUNTIME = YES;')
    a('\t\t\t\tINFOPLIST_FILE = ToddlerLock/App/Info.plist;')
    a('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (')
    a('\t\t\t\t\t"$(inherited)",')
    a('\t\t\t\t\t"@executable_path/../Frameworks",')
    a('\t\t\t\t);')
    a('\t\t\t\tMARKETING_VERSION = 1.0;')
    a('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.toddlerlock.app;')
    a('\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
    a('\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;')
    a('\t\t\t\tSWIFT_VERSION = 5.0;')
    a('\t\t\t};')
    a('\t\t\tname = Release;')
    a('\t\t};')

    a('/* End XCBuildConfiguration section */')
    a('')

    # XCConfigurationList
    a('/* Begin XCConfigurationList section */')
    a(f'\t\t{BUILD_CONFIG_LIST_PROJECT} /* Build configuration list for PBXProject "ToddlerLock" */ = {{')
    a('\t\t\tisa = XCConfigurationList;')
    a('\t\t\tbuildConfigurations = (')
    a(f'\t\t\t\t{DEBUG_CONFIG_PROJECT} /* Debug */,')
    a(f'\t\t\t\t{RELEASE_CONFIG_PROJECT} /* Release */,')
    a('\t\t\t);')
    a('\t\t\tdefaultConfigurationIsVisible = 0;')
    a('\t\t\tdefaultConfigurationName = Release;')
    a('\t\t};')
    a(f'\t\t{BUILD_CONFIG_LIST_TARGET} /* Build configuration list for PBXNativeTarget "ToddlerLock" */ = {{')
    a('\t\t\tisa = XCConfigurationList;')
    a('\t\t\tbuildConfigurations = (')
    a(f'\t\t\t\t{DEBUG_CONFIG_TARGET} /* Debug */,')
    a(f'\t\t\t\t{RELEASE_CONFIG_TARGET} /* Release */,')
    a('\t\t\t);')
    a('\t\t\tdefaultConfigurationIsVisible = 0;')
    a('\t\t\tdefaultConfigurationName = Release;')
    a('\t\t};')
    a('/* End XCConfigurationList section */')
    a('')

    a('\t};')
    a(f'\trootObject = {PROJECT_ID} /* Project object */;')
    a('}')

    return '\n'.join(lines)


if __name__ == '__main__':
    proj_dir = os.path.join(os.path.dirname(__file__), 'ToddlerLock.xcodeproj')
    os.makedirs(proj_dir, exist_ok=True)
    pbxproj_path = os.path.join(proj_dir, 'project.pbxproj')
    content = gen()
    with open(pbxproj_path, 'w') as f:
        f.write(content)
    print(f'Generated {pbxproj_path}')
