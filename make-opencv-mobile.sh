#!/bin/bash

OPENCV_VERSION="4.8.1"

OPTIONS=$(xargs < ./options.txt)


if [ ! -d "opencv-mobile" ]; then
    git submodule update --init
fi

if [ ! -d "opencv-${OPENCV_VERSION}" ]; then
    echo "Download opencv-${OPENCV_VERSION} ..."
    wget -q https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip -O opencv-${OPENCV_VERSION}.zip
    unzip -q opencv-${OPENCV_VERSION}.zip
    rm -f opencv-${OPENCV_VERSION}.zip
fi

if [ !  -d "opencv-mobile-${OPENCV_VERSION}" ]; then
    echo "Download opencv-mobile-${OPENCV_VERSION} ..."
    wget -q https://github.com/nihui/opencv-mobile/releases/latest/download/opencv-mobile-${OPENCV_VERSION}.zip
    unzip -q opencv-mobile-${OPENCV_VERSION}.zip
    rm -f opencv-mobile-${OPENCV_VERSION}.zip

    ln -s ../opencv-${OPENCV_VERSION}/3rdparty opencv-mobile-${OPENCV_VERSION}/3rdparty
fi

# build ios

cmake -S opencv-mobile-${OPENCV_VERSION} -B opencv-mobile-${OPENCV_VERSION}/build-ios -DCMAKE_TOOLCHAIN_FILE=../../opencv-mobile/toolchains/ios.toolchain.cmake \
-DIOS_PLATFORM=OS -DENABLE_BITCODE=0 -DENABLE_ARC=0 -DENABLE_VISIBILITY=0 -DIOS_ARCH="armv7;arm64;arm64e" \
-DCMAKE_INSTALL_PREFIX=opencv-mobile-${OPENCV_VERSION}/build-ios/install -DCMAKE_BUILD_TYPE=Release $OPTIONS -DBUILD_opencv_world=ON -DOPENCV_DISABLE_FILESYSTEM_SUPPORT=ON
cmake --build opencv-mobile-${OPENCV_VERSION}/build-ios -j 3
cmake --build opencv-mobile-${OPENCV_VERSION}/build-ios --target install

# build simulator 

cmake opencv-mobile-${OPENCV_VERSION} -B opencv-mobile-${OPENCV_VERSION}/build-simulator/i386_x86_64 -DCMAKE_TOOLCHAIN_FILE=../../../opencv-mobile/toolchains/ios.toolchain.cmake \
-DIOS_PLATFORM=SIMULATOR -DENABLE_BITCODE=0 -DENABLE_ARC=0 -DENABLE_VISIBILITY=0 -DIOS_ARCH="i386;x86_64" \
-DCMAKE_INSTALL_PREFIX=opencv-mobile-${OPENCV_VERSION}/build-simulator/i386_x86_64/install -DCMAKE_BUILD_TYPE=Release $OPTIONS -DBUILD_opencv_world=ON -DOPENCV_DISABLE_FILESYSTEM_SUPPORT=ON
cmake --build opencv-mobile-${OPENCV_VERSION}/build-simulator/i386_x86_64 -j 3
cmake --build opencv-mobile-${OPENCV_VERSION}/build-simulator/i386_x86_64 --target install

cmake opencv-mobile-${OPENCV_VERSION} -B opencv-mobile-${OPENCV_VERSION}/build-simulator/arm64 -DCMAKE_TOOLCHAIN_FILE=../../../opencv-mobile/toolchains/ios.toolchain.cmake \
-DIOS_PLATFORM=SIMULATOR -DENABLE_BITCODE=0 -DENABLE_ARC=0 -DENABLE_VISIBILITY=0 -DIOS_ARCH="arm64" \
-DCMAKE_INSTALL_PREFIX=opencv-mobile-${OPENCV_VERSION}/build-simulator/arm64/install -DCMAKE_BUILD_TYPE=Release $OPTIONS -DBUILD_opencv_world=ON -DOPENCV_DISABLE_FILESYSTEM_SUPPORT=ON
cmake --build opencv-mobile-${OPENCV_VERSION}/build-simulator/arm64 -j 3
cmake --build opencv-mobile-${OPENCV_VERSION}/build-simulator/arm64 --target install

# create the package

rm -rf ios/opencv2.framework
mkdir -p ios/opencv2.framework/Versions/A/Headers
mkdir -p ios/opencv2.framework/Versions/A/Resources
ln -s A ios/opencv2.framework/Versions/Current
ln -s Versions/Current/Headers ios/opencv2.framework/Headers
ln -s Versions/Current/Resources ios/opencv2.framework/Resources
ln -s Versions/Current/opencv2 ios/opencv2.framework/opencv2
lipo -create \
         opencv-mobile-${OPENCV_VERSION}/build-ios/install/lib/libopencv_world.a \
         -o ios/opencv2.framework/Versions/A/opencv2
cp -r opencv-mobile-${OPENCV_VERSION}/build-ios/install/include/opencv4/opencv2/* ios/opencv2.framework/Versions/A/Headers/
cp opencv-mobile-${OPENCV_VERSION}/Info.plist ios/opencv2.framework/Versions/A/Resources/

rm -rf ios-simulator/opencv2.framework
mkdir -p ios-simulator/opencv2.framework/Versions/A/Headers
mkdir -p ios-simulator/opencv2.framework/Versions/A/Resources
ln -s A ios-simulator/opencv2.framework/Versions/Current
ln -s Versions/Current/Headers ios-simulator/opencv2.framework/Headers
ln -s Versions/Current/Resources ios-simulator/opencv2.framework/Resources
ln -s Versions/Current/opencv2 ios-simulator/opencv2.framework/opencv2
lipo -create \
    opencv-mobile-${OPENCV_VERSION}/build-simulator/i386_x86_64/install/lib/libopencv_world.a \
    opencv-mobile-${OPENCV_VERSION}/build-simulator/arm64/install/lib/libopencv_world.a \
    -o ios-simulator/opencv2.framework/Versions/A/opencv2
cp -r opencv-mobile-${OPENCV_VERSION}/build-simulator/i386_x86_64/install/include/opencv4/opencv2/* ios-simulator/opencv2.framework/Versions/A/Headers/
cp opencv-mobile-${OPENCV_VERSION}/Info.plist ios-simulator/opencv2.framework/Versions/A/Resources/

rm -rf swiftpackage
xcodebuild -create-xcframework \
            -framework ios/opencv2.framework \
            -framework ios-simulator/opencv2.framework \
            -output swiftpackage/opencv2.xcframework

cat << EOF > "swiftpackage/Package.swift"
// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "opencv2",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(
            name: "opencv2",
            targets: ["opencv2"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "opencv2",
            path: "./opencv2.xcframework"
        ),
    ]
)
EOF

