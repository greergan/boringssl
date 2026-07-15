PACKAGE_NAME := boringssl
SRC_DIR := boringssl
BUILD_DIR := $(SRC_DIR)/build
DIST_DIR := dist
PROCS := 4
ARCH := amd64
GENERIC_URL := $(SLIM_GIT_URL)/api/packages/$(SLIM_GIT_REPO_OWNER)/generic/$(PACKAGE_NAME)
.PHONY: all clean clone patch configure build package upload upload-deb upload-rpm check-env
all: check-env upload
check-env:
	@missing=0; \
	for var in SLIM_GIT_URL SLIM_GIT_REPO_OWNER SLIM_PUBLISHER_USER SLIM_PUBLISHER_TOKEN; do \
		eval val=\$$$$var; \
		if [ -z "$$val" ]; then missing=1; fi; \
	done; \
	if [ $$missing -eq 1 ]; then \
		echo ""; \
		echo "Error: required environment variables must be set before running make:"; \
		echo ""; \
		echo "  Shell:"; \
		echo "    export SLIM_GIT_URL=<forgejo instance url>"; \
		echo "    export SLIM_GIT_REPO_OWNER=<repository owner>"; \
		echo "    export SLIM_PUBLISHER_USER=<publisher username>"; \
		echo "    export SLIM_PUBLISHER_TOKEN=<publisher api token>"; \
		echo ""; \
		echo "  Dockerfile:"; \
		echo "    ENV SLIM_GIT_URL=<forgejo instance url>"; \
		echo "    ENV SLIM_GIT_REPO_OWNER=<repository owner>"; \
		echo "    ENV SLIM_PUBLISHER_USER=<publisher username>"; \
		echo "    ENV SLIM_PUBLISHER_TOKEN=<publisher api token>"; \
		echo ""; \
		exit 1; \
	fi
clone:
	@echo "==> Cloning BoringSSL (shallow)..."
	@if [ ! -d "$(SRC_DIR)" ]; then \
		git clone --depth 1 https://github.com/google/boringssl.git $(SRC_DIR); \
	else \
		git -C $(SRC_DIR) fetch --depth 1 origin; \
	fi
patch: clone
	@echo "==> Injecting Install and CPack configurations..."
	@if ! grep -q "CPACK_GENERATOR" $(SRC_DIR)/CMakeLists.txt; then \
		PKG_VER=$$(cd $(SRC_DIR) && git log -1 --format=%cd --date=format:%Y%m%d); \
		echo "Discovered Date Version: $$PKG_VER"; \
		echo "" >> $(SRC_DIR)/CMakeLists.txt; \
		echo "# --- Custom Install & CPack Rules ---" >> $(SRC_DIR)/CMakeLists.txt; \
		echo "install(TARGETS crypto ssl bssl RUNTIME DESTINATION bin LIBRARY DESTINATION lib/x86_64-linux-gnu ARCHIVE DESTINATION lib/x86_64-linux-gnu)" >> $(SRC_DIR)/CMakeLists.txt; \
		echo "install(DIRECTORY include/ DESTINATION include)" >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'set(CPACK_GENERATOR "DEB;RPM")' >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'set(CPACK_PACKAGE_NAME "$(PACKAGE_NAME)")' >> $(SRC_DIR)/CMakeLists.txt; \
		echo "set(CPACK_PACKAGE_VERSION \"$$PKG_VER\")" >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'set(CPACK_PACKAGE_FILE_NAME "$${CPACK_PACKAGE_NAME}-$${CPACK_PACKAGE_VERSION}-$(ARCH)")' >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'set(CPACK_DEB_COMPONENT_INSTALL OFF)' >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'set(CPACK_RPM_COMPONENT_INSTALL OFF)' >> $(SRC_DIR)/CMakeLists.txt; \
		echo "set(CPACK_DEBIAN_PACKAGE_MAINTAINER \"$$(git config user.name) <$$(git config user.email)>\")" >> $(SRC_DIR)/CMakeLists.txt; \
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
		-DBUILD_SHARED_LIBS=OFF \
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
		-DCMAKE_INSTALL_LIBDIR=lib/x86_64-linux-gnu \
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
	curl --user "$(SLIM_PUBLISHER_USER):$(SLIM_PUBLISHER_TOKEN)" \
		--upload-file $(DIST_DIR)/$(PACKAGE_NAME)-$$PKG_VER-$(ARCH).deb \
		"$(GENERIC_URL)/$$PKG_VER/$(PACKAGE_NAME)-$$PKG_VER-$(ARCH).deb"
upload-rpm:
	@echo "==> Uploading .rpm to Generic Registry..."
	@PKG_VER=$$(cd $(SRC_DIR) && git log -1 --format=%cd --date=format:%Y%m%d); \
	curl --user "$(SLIM_PUBLISHER_USER):$(SLIM_PUBLISHER_TOKEN)" \
		--upload-file $(DIST_DIR)/$(PACKAGE_NAME)-$$PKG_VER-$(ARCH).rpm \
		"$(GENERIC_URL)/$$PKG_VER/$(PACKAGE_NAME)-$$PKG_VER-$(ARCH).rpm"
upload: package upload-deb upload-rpm
	@echo "==> Upload complete."
clean:
	@echo "==> Cleaning up build environment..."
	rm -rf $(SRC_DIR) $(DIST_DIR)
