<a href="https://codeberg.org/greergan/SlimTS">
  <img src="https://raw.githubusercontent.com/greergan/SlimTS/master/assets/slimts_logo.png" width="75" alt="SlimTS Logo">
</a>

# BoringSSL Package Builder
Builds BoringSSL from source for use by [SlimTS](https://codeberg.org/greergan/SlimTS)  
Clones, builds, packages, and uploads BoringSSL static libraries to a Forgejo generic registry.

## Requirements
- `git`, `cmake`, `make`, `cpack`, `curl`
- `rpmbuild` (for RPM generation)

## Environment Variables
The following must be set before running `make`:

| Variable | Description |
|---|---|
| `SLIM_GIT_URL` | Forgejo instance URL |
| `SLIM_GIT_REPO_OWNER` | Forgejo repository owner |
| `SLIM_PUBLISHER_USER` | Forgejo username for upload |
| `SLIM_PUBLISHER_TOKEN` | Forgejo API token |

Shell:
```
export SLIM_GIT_URL=<forgejo instance url>
export SLIM_GIT_REPO_OWNER=<repository owner>
export SLIM_PUBLISHER_USER=<publisher username>
export SLIM_PUBLISHER_TOKEN=<publisher api token>
```

Dockerfile:
```
ENV SLIM_GIT_URL=<forgejo instance url>
ENV SLIM_GIT_REPO_OWNER=<repository owner>
ENV SLIM_PUBLISHER_USER=<publisher username>
ENV SLIM_PUBLISHER_TOKEN=<publisher api token>
```

## Usage
Run everything — clone, build, package, and upload:
```
make
```

Or run steps individually:

| Target | Description |
|---|---|
| `make clone` | Shallow clone BoringSSL, or fetch latest if already cloned |
| `make patch` | Inject install and CPack rules into CMakeLists.txt |
| `make configure` | Run CMake configuration |
| `make build` | Compile using 4 parallel jobs |
| `make package` | Generate `.deb` and `.rpm` packages into `dist/` |
| `make upload-deb` | Upload `.deb` to Forgejo |
| `make upload-rpm` | Upload `.rpm` to Forgejo |
| `make upload` | Package and upload both |
| `make clean` | Remove source and dist directories |

## Configuration
Edit the variables at the top of the Makefile:

| Variable | Description |
|---|---|
| `PROCS` | Parallel compile jobs (default: 4) |
| `ARCH` | Target architecture (default: amd64) |

## Output
Packages are versioned by the BoringSSL commit date (`YYYYMMDD`) and written to `dist/`:
```
dist/boringssl-YYYYMMDD-amd64.deb
dist/boringssl-YYYYMMDD-amd64.rpm
```
Libraries are installed to `lib/x86_64-linux-gnu`.
