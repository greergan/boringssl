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
		echo "# --- pkg-config .pc generation ---" >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'set(BORINGSSL_PC_PREFIX "/usr")' >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'set(BORINGSSL_PC_LIBDIR "$${BORINGSSL_PC_PREFIX}/lib/x86_64-linux-gnu")' >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'set(BORINGSSL_PC_INCDIR "$${BORINGSSL_PC_PREFIX}/include")' >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'file(WRITE "$${CMAKE_BINARY_DIR}/boringssl.pc"' >> $(SRC_DIR)/CMakeLists.txt; \
		echo '    "prefix=$${BORINGSSL_PC_PREFIX}\n"' >> $(SRC_DIR)/CMakeLists.txt; \
		echo '    "libdir=$${BORINGSSL_PC_LIBDIR}\n"' >> $(SRC_DIR)/CMakeLists.txt; \
		echo '    "includedir=$${BORINGSSL_PC_INCDIR}\n"' >> $(SRC_DIR)/CMakeLists.txt; \
		echo '    "\n"' >> $(SRC_DIR)/CMakeLists.txt; \
		echo '    "Name: BoringSSL\n"' >> $(SRC_DIR)/CMakeLists.txt; \
		echo '    "Description: BoringSSL crypto and SSL libraries\n"' >> $(SRC_DIR)/CMakeLists.txt; \
		echo '    "Version: $${CPACK_PACKAGE_VERSION}\n"' >> $(SRC_DIR)/CMakeLists.txt; \
		echo '    "Libs: -L\$${libdir} -lssl -lcrypto\n"' >> $(SRC_DIR)/CMakeLists.txt; \
		echo '    "Cflags: -I\$${includedir}\n"' >> $(SRC_DIR)/CMakeLists.txt; \
		echo ')' >> $(SRC_DIR)/CMakeLists.txt; \
		echo 'install(FILES "$${CMAKE_BINARY_DIR}/boringssl.pc"' >> $(SRC_DIR)/CMakeLists.txt; \
		echo '    DESTINATION lib/x86_64-linux-gnu/pkgconfig)' >> $(SRC_DIR)/CMakeLists.txt; \
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
	@rm -f $(DIST_DIR)/*.deb $(DIST_DIR)/*.rpm
	@find $(BUILD_DIR) -maxdepth 1 \( -name "*.deb" -o -name "*.rpm" \) -exec cp {} $(DIST_DIR)/ \;
upload-deb:
	@echo "==> Uploading .deb to Generic Registry..."
	@PKG_VER=$$(cd $(SRC_DIR) && git log -1 --format=%cd --date=format:%Y%m%d); \
	HTTP_CODE=$$(curl -s -o /dev/null -w "%{http_code}" \
		--user "$(SLIM_PUBLISHER_USER):$(SLIM_PUBLISHER_TOKEN)" \
		--upload-file $(DIST_DIR)/$(PACKAGE_NAME)-$$PKG_VER-$(ARCH).deb \
		"$(GENERIC_URL)/$$PKG_VER/$(PACKAGE_NAME)-$$PKG_VER-$(ARCH).deb"); \
	if [ "$$HTTP_CODE" = "409" ]; then \
		echo "==> Package already exists in the registry. Bump the version or run 'make clean' first."; \
		exit 1; \
	elif [ "$$HTTP_CODE" != "201" ]; then \
		echo "==> ERROR: .deb upload failed (HTTP $$HTTP_CODE)"; \
		exit 1; \
	fi
upload-rpm:
	@echo "==> Uploading .rpm to Generic Registry..."
	@PKG_VER=$$(cd $(SRC_DIR) && git log -1 --format=%cd --date=format:%Y%m%d); \
	HTTP_CODE=$$(curl -s -o /dev/null -w "%{http_code}" \
		--user "$(SLIM_PUBLISHER_USER):$(SLIM_PUBLISHER_TOKEN)" \
		--upload-file $(DIST_DIR)/$(PACKAGE_NAME)-$$PKG_VER-$(ARCH).rpm \
		"$(GENERIC_URL)/$$PKG_VER/$(PACKAGE_NAME)-$$PKG_VER-$(ARCH).rpm"); \
	if [ "$$HTTP_CODE" = "409" ]; then \
		echo "==> Package already exists in the registry. Bump the version or run 'make clean' first."; \
		exit 1; \
	elif [ "$$HTTP_CODE" != "201" ]; then \
		echo "==> ERROR: .rpm upload failed (HTTP $$HTTP_CODE)"; \
		exit 1; \
	fi
upload: package upload-deb upload-rpm
	@echo "==> Upload complete."
clean:
	@echo "==> Cleaning up build environment..."
	rm -rf $(SRC_DIR)
