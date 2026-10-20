#!/usr/bin/env python3
"""Generate a small native app project using the local Swift package for its tested core."""
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parent.parent
project=root/'NotchCraft.xcodeproj'
project.mkdir(exist_ok=True)
def uid(s): return hashlib.sha256(s.encode()).hexdigest()[:24].upper()
def ref(s): return uid(s)
objects=[]
def obj(name, body): objects.append(f'\t\t{ref(name)} = {{ {body} }};')
sources=sorted((root/'Sources/NotchCraft').rglob('*.swift'))
source_refs=[]; build_refs=[]
for path in sources:
 p=path.relative_to(root).as_posix(); key='source:'+p; build='build:'+p
 obj(key,f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{p}"; sourceTree = SOURCE_ROOT;')
 obj(build,f'isa = PBXBuildFile; fileRef = {ref(key)};')
 source_refs.append(ref(key)); build_refs.append(ref(build))
for lang in ['ko','en']:
 obj('strings:'+lang,f'isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = {lang}; path = "Sources/NotchCraft/Resources/{lang}.lproj/Localizable.strings"; sourceTree = SOURCE_ROOT;')
obj('localized',f'isa = PBXVariantGroup; children = ({ref("strings:ko")},{ref("strings:en")},); name = Localizable.strings; sourceTree = "<group>";')
obj('strings-build',f'isa = PBXBuildFile; fileRef = {ref("localized")};')
obj('icon','isa = PBXFileReference; lastKnownFileType = image.icns; path = Sources/NotchCraft/Resources/AppIcon.icns; sourceTree = SOURCE_ROOT;')
obj('icon-build',f'isa = PBXBuildFile; fileRef = {ref("icon")};')
obj('product','isa = PBXFileReference; explicitFileType = wrapper.application; path = NotchCraft.app; sourceTree = BUILT_PRODUCTS_DIR; includeInIndex = 0;')
obj('products',f'isa = PBXGroup; children = ({ref("product")},); name = Products; sourceTree = "<group>";')
obj('sources',f'isa = PBXGroup; children = ({",".join(source_refs)},); name = Sources; sourceTree = "<group>";')
obj('root',f'isa = PBXGroup; children = ({ref("sources")},{ref("localized")},{ref("icon")},{ref("products")},); sourceTree = "<group>";')
obj('source-phase',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(build_refs)},); runOnlyForDeploymentPostprocessing = 0;')
obj('resources-phase',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({ref("strings-build")},{ref("icon-build")},); runOnlyForDeploymentPostprocessing = 0;')
obj('package','isa = XCLocalSwiftPackageReference; relativePath = ".";')
obj('core-product',f'isa = XCSwiftPackageProductDependency; package = {ref("package")}; productName = NotchCraftCore;')
obj('core-build',f'isa = PBXBuildFile; productRef = {ref("core-product")};')
obj('frameworks',f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({ref("core-build")},); runOnlyForDeploymentPostprocessing = 0;')
for name in ['Debug','Release']:
 opts='SWIFT_OPTIMIZATION_LEVEL = "-Onone"; DEBUG_INFORMATION_FORMAT = dwarf; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;' if name=='Debug' else 'SWIFT_OPTIMIZATION_LEVEL = "-O"; DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";'
 obj('project-'+name,f'isa = XCBuildConfiguration; name = {name}; buildSettings = {{ MACOSX_DEPLOYMENT_TARGET = 14.0; SDKROOT = macosx; ARCHS = arm64; ONLY_ACTIVE_ARCH = YES; SWIFT_VERSION = 6.0; CLANG_ENABLE_MODULES = YES; {opts} }};')
 obj('app-'+name,f'isa = XCBuildConfiguration; name = {name}; buildSettings = {{ PRODUCT_NAME = NotchCraft; PRODUCT_BUNDLE_IDENTIFIER = app.notchcraft.workspace; INFOPLIST_FILE = Support/Info.plist; GENERATE_INFOPLIST_FILE = NO; CODE_SIGN_ENTITLEMENTS = Support/NotchCraft.entitlements; CODE_SIGN_IDENTITY = "-"; CODE_SIGN_STYLE = Manual; ENABLE_HARDENED_RUNTIME = YES; ENABLE_APP_SANDBOX = NO; SWIFT_VERSION = 6.0; MACOSX_DEPLOYMENT_TARGET = 14.0; LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks"; }};')
for key in ['project','app']:
 obj(key+'-configs',f'isa = XCConfigurationList; buildConfigurations = ({ref(key+"-Debug")},{ref(key+"-Release")},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('app',f'isa = PBXNativeTarget; buildConfigurationList = {ref("app-configs")}; buildPhases = ({ref("source-phase")},{ref("frameworks")},{ref("resources-phase")},); buildRules = (); dependencies = (); name = NotchCraft; packageProductDependencies = ({ref("core-product")},); productName = NotchCraft; productReference = {ref("product")}; productType = "com.apple.product-type.application";')
obj('project',f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastSwiftUpdateCheck = 1600; LastUpgradeCheck = 1600; }}; buildConfigurationList = {ref("project-configs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = ko; hasScannedForEncodings = 0; knownRegions = (ko,en,Base,); mainGroup = {ref("root")}; packageReferences = ({ref("package")},); productRefGroup = {ref("products")}; projectDirPath = ""; projectRoot = ""; targets = ({ref("app")},);')
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n'+'\n'.join(objects)+f'\n\t}};\n\trootObject = {ref("project")};\n}}\n')
schemes=project/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
(schemes/'NotchCraft.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref('app')}" BuildableName="NotchCraft.app" BlueprintName="NotchCraft" ReferencedContainer="container:NotchCraft.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ref('app')}" BuildableName="NotchCraft.app" BlueprintName="NotchCraft" ReferencedContainer="container:NotchCraft.xcodeproj"/></BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release"/><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print(project)
