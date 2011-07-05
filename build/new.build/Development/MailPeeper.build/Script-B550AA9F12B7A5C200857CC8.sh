#!/bin/sh
#mkdir -p "$TARGET_BUILD_DIR/$PRODUCT_NAME.app/Contents/Frameworks"
#cp -R openssl.framework "$TARGET_BUILD_DIR/$PRODUCT_NAME.app/Contents/Frameworks"
#install_name_tool -change ./FILENAME.dylib @executable_path/FILENAME.dylib "$TARGET_BUILD_DIR/$PRODUCT_NAME.app/Contents/MacOS/$PRODUCT_NAME" 
#install_name_tool -change libssl.1.0.0.dylib @executable_path/libssl.1.0.0.dylib "$TARGET_BUILD_DIR/$PRODUCT_NAME.app/Contents/MacOS/$PRODUCT_NAME"
#install_name_tool -change libcrypto.1.0.0.dylib @executable_path/libcrypto.1.0.0.dylib "$TARGET_BUILD_DIR/$PRODUCT_NAME.app/Contents/MacOS/$PRODUCT_NAME"

cp -f *.dylib "$TARGET_BUILD_DIR/$PRODUCT_NAME.app/Contents/MacOS"

