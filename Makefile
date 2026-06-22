# --- Configuration Variables ---
PACKAGE_NAME := boringssl
SRC_DIR := boringssl
BUILD_DIR := $(SRC_DIR)/build
DIST_DIR := dist
PROCS := 4
ARCH := amd64

# --- Forgejo Upload Variables ---
FORGEJO_URL := http://forgejo
FORGEJO_USER := highway-publisher
FORGEJO_TOKEN := eaaabfa4bb2726880f462ec70b0d00e284773363
FORGEJO_OWNER := greergan
MAINTAINER := Jeff Greer <geergan@gmail.com>

GENERIC_URL := $(FORGEJO_URL)/api/packages/$(FORGEJO_OWNER)/generic/$(PACKAGE_NAME)

.PHONY: all clean clone patch configure build package upload upload-deb upload-rpm

# Default target runs everything up to packaging
all: package

clone:
	@echo "==> Cloning BoringSSL (shallow)..."
	@if [ ! -d "$(SRC_DIR)" ]; then \
		git clone --depth 1 https://github.com/google/boringssl.git $(SRC_DIR); \
	else \
		echo "Directory $(SRC_DIR) already exists, skipping clone."; \
	fi

patch: clone
	@echo "==> Injecting Install and CPack configurations..."
	@if ! grep -q "CPACK_GENERATOR" $(SRC_DIR)/CMakeLists.txt; then \
		PKG_VER=$$(cd $(SRC_DIR) && git log -1 --format=%cd --date=format:%Y%m%d); \
		echo "Discovered Date Version: $$PKG_VER"; \
		echo "" >> $(SRC_DIR)/CMakeLists.txt; \
		echo "# --- Custom Install & CPack Rules ---" >> $(SRC_DIR)/CMakeLists.txt; \
		echo "install(TARGETS crypto ssl bssl RUNTIME DESTINATION bin LIBRARY DESTINATION lib ARCHIVE DESTINATION lib)" >> $(SRC_DIR)/CMakeLists.txt; \
		echo "install(DIRECTORY include/ DESTINATION include)" >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'set(CPACK_GENERATOR "DEB;RPM")' >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'set(CPACK_PACKAGE_NAME "$(PACKAGE_NAME)")' >> $(SRC_DIR)/CMakeLists.txt; \
		echo "set(CPACK_PACKAGE_VERSION \"$$PKG_VER\")" >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'set(CPACK_PACKAGE_FILE_NAME "$${CPACK_PACKAGE_NAME}-$${CPACK_PACKAGE_VERSION}-$(ARCH)")' >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'set(CPACK_DEB_COMPONENT_INSTALL OFF)' >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'set(CPACK_RPM_COMPONENT_INSTALL OFF)' >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'set(CPACK_DEBIAN_PACKAGE_MAINTAINER "$(MAINTAINER)")' >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'set(CPACK_RPM_PACKAGE_LICENSE "OpenSSL/ISC")' >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'include(CPack)' >> $(SRC_DIR)/CMakeLists.txt; \
		echo "Install and CPack config injected."; \
	else \
		echo "CPack config already exists, skipping patch."; \
	fi

configure: patch
	@echo "==> Configuring CMake..."
	@mkdir -p $(BUILD_DIR)
	@cd $(BUILD_DIR) && cmake .. \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_SHARED_LIBS=ON \
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
		-DBUILD_TESTING=OFF

build: configure
	@echo "==> Compiling using $(PROCS) processors..."
	@cd $(BUILD_DIR) && $(MAKE) -j$(PROCS)

package: build
	@echo "==> Generating .deb and .rpm packages..."
	@cd $(BUILD_DIR) && cpack
	@mkdir -p $(DIST_DIR)
	@find $(BUILD_DIR) -maxdepth 1 \( -name "*.deb" -o -name "*.rpm" \) -exec cp {} $(DIST_DIR)/ \;

upload-deb:
	@echo "==> Uploading .deb to Generic Registry..."
	@PKG_VER=$$(cd $(SRC_DIR) && git log -1 --format=%cd --date=format:%Y%m%d); \
	curl --user "$(FORGEJO_USER):$(FORGEJO_TOKEN)" \
		--upload-file $(DIST_DIR)/$(PACKAGE_NAME)-$$PKG_VER-$(ARCH).deb \
		"$(GENERIC_URL)/$$PKG_VER/$(PACKAGE_NAME)-$$PKG_VER-$(ARCH).deb"

upload-rpm:
	@echo "==> Uploading .rpm to Generic Registry..."
	@PKG_VER=$$(cd $(SRC_DIR) && git log -1 --format=%cd --date=format:%Y%m%d); \
	curl --user "$(FORGEJO_USER):$(FORGEJO_TOKEN)" \
		--upload-file $(DIST_DIR)/$(PACKAGE_NAME)-$$PKG_VER-$(ARCH).rpm \
		"$(GENERIC_URL)/$$PKG_VER/$(PACKAGE_NAME)-$$PKG_VER-$(ARCH).rpm"

upload: package upload-deb upload-rpm
	@echo "==> Upload complete."

clean:
	@echo "==> Cleaning up build environment..."
	rm -rf $(SRC_DIR) $(DIST_DIR)