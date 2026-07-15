<a href="https://codeberg.org/greergan/SlimTS">
  <img src="https://raw.githubusercontent.com/greergan/SlimTS/master/assets/slimts_logo.png" width="75" alt="SlimTS Logo">
</a>

# boringssl

Builds boringssl from source for use by [SlimTS](https://codeberg.org/greergan/SlimTS)  

# BoringSSL Package Builder

Clones, builds, packages, and uploads BoringSSL static libraries to a Forgejo generic registry.

## Requirements

- `git`, `cmake`, `make`, `cpack`, `curl`
- `rpmbuild` (for RPM generation)

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
| `FORGEJO_URL` | Forgejo instance URL |
| `FORGEJO_USER` | Forgejo username for upload |
| `FORGEJO_TOKEN` | Forgejo API token |
| `FORGEJO_OWNER` | Forgejo repository owner |
| `MAINTAINER` | Package maintainer name and email |

## Output

Packages are versioned by the BoringSSL commit date (`YYYYMMDD`) and written to `dist/`:

```
dist/boringssl-YYYYMMDD-amd64.deb
dist/boringssl-YYYYMMDD-amd64.rpm
```

Libraries are installed to `lib/x86_64-linux-gnu`.
